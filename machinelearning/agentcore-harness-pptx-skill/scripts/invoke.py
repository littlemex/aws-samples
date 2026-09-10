#!/usr/bin/env python3
"""Ask the harness for a deck, then pull the file out of the session.

    export AWS_REGION=... HARNESS_ARN=... ARTIFACT_BUCKET=...
    python3 invoke.py "Build a five slide deck on our Q3 cost review"

The agent runs in a microVM with a shell and a filesystem, so this script does
three things in one session: install what the skill needs, let the agent work,
then copy the produced file out. The session id is reused across all three so
they share the same machine.
"""
from __future__ import annotations

import argparse
import os
import sys
import uuid

import boto3
from botocore.config import Config

WORKSPACE = "/workspace"

#: A harness turn runs a whole agent loop - reading skills, writing a
#: specification, building, checking - before the stream produces its next
#: event. The SDK default read timeout of 60s expires mid-think and tears down
#: a session that is working, so it is raised here rather than left implicit.
#: Retries are disabled because replaying a partially consumed stream would ask
#: the agent to redo work it has already done.
CLIENT_CONFIG = Config(read_timeout=900, connect_timeout=15,
                       retries={"max_attempts": 1})


def run_command(client, harness_arn: str, session_id: str, command: str) -> int:
    """Run a shell command on the session microVM and stream its output."""
    response = client.invoke_agent_runtime_command(
        agentRuntimeArn=harness_arn,
        runtimeSessionId=session_id,
        body={"command": command},
    )
    exit_code = 0
    for event in response["stream"]:
        chunk = event.get("chunk", {})
        delta = chunk.get("contentDelta", {})
        if "stdout" in delta:
            sys.stdout.write(delta["stdout"])
            sys.stdout.flush()
        if "stderr" in delta:
            sys.stderr.write(delta["stderr"])
            sys.stderr.flush()
        if "contentStop" in chunk:
            exit_code = chunk["contentStop"].get("exitCode", 0)
    return exit_code


def ask(client, harness_arn: str, session_id: str, prompt: str) -> str:
    """Send one user turn and stream the reply back."""
    response = client.invoke_harness(
        harnessArn=harness_arn,
        runtimeSessionId=session_id,
        messages=[{"role": "user", "content": [{"text": prompt}]}],
    )
    parts = []
    for event in response["stream"]:
        if "contentBlockDelta" in event:
            delta = event["contentBlockDelta"].get("delta", {})
            if "text" in delta:
                parts.append(delta["text"])
                sys.stdout.write(delta["text"])
                sys.stdout.flush()
        elif "runtimeClientError" in event:
            raise RuntimeError(event["runtimeClientError"]["message"])
        elif "messageStop" in event:
            reason = event["messageStop"].get("stopReason")
            # tool_use / tool_result are ordinary turns inside the harness's
            # own agent loop, which runs the whole shell/build/check cycle
            # before returning control here. Only the reasons below mean the
            # harness gave up before finishing.
            if reason in ("max_tokens", "max_iterations_exceeded",
                          "timeout_exceeded", "max_output_tokens_exceeded"):
                print(f"\n[WARNING] the agent stopped early: {reason}",
                      file=sys.stderr)
    return "".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prompt", help="what the deck should cover")
    parser.add_argument("--session-id", default=None,
                        help="reuse a session to continue an earlier deck")
    args = parser.parse_args()

    region = os.environ.get("AWS_REGION")
    harness_arn = os.environ.get("HARNESS_ARN")
    bucket = os.environ.get("ARTIFACT_BUCKET")
    missing = [name for name, value in
               (("AWS_REGION", region), ("HARNESS_ARN", harness_arn),
                ("ARTIFACT_BUCKET", bucket)) if not value]
    if missing:
        print(f"[FAIL] set {', '.join(missing)} first", file=sys.stderr)
        return 1

    # The API requires at least 33 characters, which a bare uuid4 satisfies.
    session_id = args.session_id or f"deck-{uuid.uuid4()}"
    client = boto3.client("bedrock-agentcore", region_name=region,
                          config=CLIENT_CONFIG)
    print(f"[INFO] session {session_id}")

    print("[1/3] preparing the environment")
    setup = ("set -e; mkdir -p %s; python3 -m pip install --quiet python-pptx"
             % WORKSPACE)
    if run_command(client, harness_arn, session_id, setup) != 0:
        print("[FAIL] could not prepare the environment", file=sys.stderr)
        return 1

    print("\n[2/3] asking for the deck")
    instruction = (
        f"{args.prompt}\n\n"
        f"Work in {WORKSPACE}. Use the corporate-deck skill. Write the "
        f"specification to {WORKSPACE}/deck.json, build "
        f"{WORKSPACE}/deck.pptx, and run check_deck.py against it. Report the "
        f"path only once both commands have exited zero."
    )
    ask(client, harness_arn, session_id, instruction)

    print("\n\n[3/3] copying the deck out")
    key = f"decks/{session_id}.pptx"
    # Checked separately from the copy so a missing file and a failed upload do
    # not report the same cause. Conflating them once sent us looking for a
    # deck the agent had in fact produced.
    if run_command(client, harness_arn, session_id,
                   f"test -f {WORKSPACE}/deck.pptx") != 0:
        print(f"[FAIL] the agent did not leave a deck at {WORKSPACE}/deck.pptx",
              file=sys.stderr)
        return 1
    copy = f"aws s3 cp {WORKSPACE}/deck.pptx s3://{bucket}/{key}"
    if run_command(client, harness_arn, session_id, copy) != 0:
        print(f"[FAIL] the deck was built but could not be uploaded to "
              f"s3://{bucket}/{key}. Check that the bucket exists and that the "
              f"execution role has s3:PutObject on it. The file is still in "
              f"the session, so rerun with --session-id {session_id} once the "
              f"bucket is fixed.", file=sys.stderr)
        return 1

    print(f"\n[OK] s3://{bucket}/{key}")
    print(f"[INFO] reuse this session to revise it: --session-id {session_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
