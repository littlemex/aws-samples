#!/usr/bin/env python3
"""Create or update the harness, then wait for it to become usable.

    python3 harness.py --execution-role-arn ROLE --skill-uri s3://BUCKET/PREFIX/

Driven through boto3 rather than the AWS CLI on purpose: the harness API is
recent enough that a CLI installed even a few months ago does not have
`bedrock-agentcore-control create-harness`, while `pip install -U boto3` is
something this sample already asks for.

Prints `export HARNESS_ARN=...` on success so the caller can eval or copy it.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time

import boto3

READY_STATES = {"READY", "ACTIVE", "AVAILABLE"}
FAILED_STATES = {"CREATE_FAILED", "UPDATE_FAILED", "FAILED", "DELETING"}

SYSTEM_PROMPT = (
    "You produce presentation decks. Use the corporate-deck skill for layout "
    "and the published pptx skill for anything it does not cover. Build with "
    "build_deck.py and never hand over a deck that has not passed "
    "check_deck.py. Report the path to the file you produced."
)


def desired_skills(published_url: str, published_path: str, skill_uri: str) -> list:
    return [
        {"git": {"url": published_url, "path": published_path}},
        {"s3": {"uri": skill_uri}},
    ]


def find(client, name: str):
    paginator = None
    try:
        paginator = client.get_paginator("list_harnesses")
    except Exception:
        pass
    pages = paginator.paginate() if paginator else [client.list_harnesses()]
    for page in pages:
        for item in page.get("harnesses", []):
            if item.get("harnessName") == name:
                return item
    return None


def read_status(response: dict) -> tuple:
    """The response nests differently across releases; accept either shape."""
    body = response.get("harness", response)
    status = body.get("status") or body.get("harnessStatus")
    arn = body.get("harnessArn") or body.get("arn")
    harness_id = body.get("harnessId") or body.get("id")
    return status, arn, harness_id


def wait_ready(client, harness_id: str, timeout: int = 900) -> tuple:
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        status, arn, _ = read_status(client.get_harness(harnessId=harness_id))
        if status != last:
            print(f"[INFO] status {status}", file=sys.stderr)
            last = status
        if status in READY_STATES:
            return status, arn
        if status in FAILED_STATES:
            raise RuntimeError(f"harness entered {status}")
        time.sleep(5)
    raise TimeoutError(f"harness was still {last} after {timeout}s")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", default=os.environ.get("HARNESS_NAME",
                                                         "CorporateDeckHarness"))
    parser.add_argument("--execution-role-arn", required=True)
    parser.add_argument("--skill-uri", required=True,
                        help="s3:// prefix holding the corporate-deck skill")
    parser.add_argument("--published-url",
                        default="https://github.com/anthropics/skills")
    parser.add_argument("--published-path", default="skills/pptx")
    parser.add_argument("--model-id", default=None,
                        help="omit to accept the service default model")
    parser.add_argument("--region", default=os.environ.get("AWS_REGION"))
    args = parser.parse_args()

    if not args.region:
        print("[FAIL] set AWS_REGION or pass --region", file=sys.stderr)
        return 1

    client = boto3.client("bedrock-agentcore-control", region_name=args.region)
    skills = desired_skills(args.published_url, args.published_path,
                            args.skill_uri)
    payload = {
        "skills": skills,
        "systemPrompt": [{"text": SYSTEM_PROMPT}],
        "tools": [{"type": "agentcore_code_interpreter",
                   "name": "code_interpreter",
                   "config": {"agentCoreCodeInterpreter": {}}}],
    }
    if args.model_id:
        payload["model"] = {"bedrockModelConfig": {"modelId": args.model_id}}

    existing = find(client, args.name)
    if existing:
        harness_id = existing.get("harnessId") or existing.get("id")
        print(f"[INFO] updating {args.name} ({harness_id})", file=sys.stderr)
        client.update_harness(harnessId=harness_id, **payload)
    else:
        print(f"[INFO] creating {args.name}", file=sys.stderr)
        response = client.create_harness(
            harnessName=args.name,
            executionRoleArn=args.execution_role_arn,
            **payload)
        _, _, harness_id = read_status(response)
        if not harness_id:
            found = find(client, args.name)
            harness_id = found and (found.get("harnessId") or found.get("id"))
        if not harness_id:
            print(f"[FAIL] could not determine the harness id from "
                  f"{json.dumps(response, default=str)}", file=sys.stderr)
            return 1

    status, arn = wait_ready(client, harness_id)
    print(f"[INFO] {args.name} is {status}", file=sys.stderr)
    print(f"export HARNESS_ID={harness_id}")
    print(f"export HARNESS_ARN={arn}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
