# Verified end to end

`sample-output.pptx` was produced on 2026-09-10 by an actual `InvokeHarness`
call against a `CorporateDeckHarness` deployed with `scripts/setup.sh` in `us-west-2`, in an
account used only for this verification. It is committed as evidence, not as an
example to copy; use `skills/corporate-deck/examples/architecture.deck.json`
for that.

What was verified, in order:

1. `./scripts/setup.sh` created the execution role, the skill bucket, and the
   harness, and the harness reached `READY`.
2. `scripts/invoke.py` opened a session, and `InvokeAgentRuntimeCommand`
   confirmed the microVM has `git`, `aws`, `pip3` and `python3`, and that
   `python-pptx` installs into it.
3. `InvokeHarness` was sent a prompt naming no file format or layout details
   beyond "a four slide deck" — the agent chose to read `SKILL.md`, write its
   own `deck.json`, run `build_deck.py`, and run `check_deck.py`, entirely on
   its own initiative from the two attached skills.
4. Both commands exited zero inside the session, and the agent reported the
   path.
5. The file was copied to the artifact bucket configured for that run,
   downloaded, and opened with `python-pptx` outside the harness: 4 slides,
   matching eyebrows, valid OOXML.
6. The same session was reused with a revision request. The agent edited its
   own `deck.json`, rebuilt, re-ran the checks, and reported a diff; the
   redownloaded file matched the reported change exactly.

Two defects in `iam/execution-role-policy.json` were found and fixed only by
running this: the model-invoke resource ARN needs a wildcard region segment
(`arn:aws:bedrock:*::foundation-model/*`), because Bedrock's own routing calls
it with an empty region; and the harness's own conversation memory needs a
`bedrock-agentcore:*Event*` grant that reading the API reference alone does
not surface, because it is the harness's internal state, not something this
skill's code calls directly. `scripts/invoke.py` also warned on every normal
mid-loop turn until this run showed the warning firing constantly on
successful sessions; it now only fires on the stop reasons that mean the
harness gave up.
