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

## Second run: a Japanese deck on a real corporate template

The same path was exercised again with the corporate template present at
`skills/corporate-deck/assets/template.pptx` and a brief written in Japanese.
The agent produced an eleven slide deck, in Japanese, on the corporate theme,
with speaker notes on every slide — including a nine step `sequence` slide
naming each API in call order. Both `build_deck.py` and `check_deck.py` exited
zero, and the agent recovered on its own from two of its own overflow failures
by shortening the offending blocks, which is the overflow guard doing its job.

Three more defects surfaced only by running it:

- `scripts/invoke.py` used the SDK default 60 second read timeout. A harness
  turn runs an entire agent loop before the stream yields its next event, so a
  session that was working was torn down mid-think. The client now sets a 900
  second read timeout and disables retries, because replaying a partly consumed
  stream would ask the agent to redo work it had finished.
- `scripts/setup.sh` created the skill bucket but never the artifact bucket, so
  the very last step of an otherwise successful run failed with `NoSuchBucket`.
  It now creates both when they differ.
- The upload failure was reported as "the agent did not leave a deck", sending
  us to look for a file that had in fact been produced. The file check and the
  upload are now separate steps with separate messages, and the failure message
  names the session so the built file can be retrieved rather than rebuilt.

The corporate template itself is deliberately not committed; see
`skills/corporate-deck/assets/README.md`.
