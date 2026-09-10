# Deck generation on AgentCore Harness

Generate PowerPoint decks with Claude on Amazon Bedrock, using the published
document skills unmodified plus a second skill that carries the corporate
template.

## Why this exists

A document skill is three layers: `SKILL.md`, the scripts and assets it calls,
and a sandbox with a filesystem where those scripts run and produce a file. The
first two are just files and travel anywhere. The third is a place rather than a
payload, and an inference API does not provide one.

That is why the same model that summarises and analyses without trouble cannot
produce a `.pptx` when it is reached through inference alone: the model can say
which python-pptx calls to make, but nothing executes them and nothing carries
the result back.

[AgentCore Harness](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/harness.html)
supplies the third layer. Each session runs in an isolated microVM with its own
filesystem and shell, and skills are fetched
[from Git, Amazon S3, a filesystem path, or the AWS catalogue](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/harness-skills.html).
So the published skill is attached by URL, not reimplemented.

## What this sample builds

```
business application
        |  InvokeHarness
        v
AgentCore Harness  --- Amazon Bedrock (the model)
  microVM: shell, filesystem, Code Interpreter
        ^                    |
        |  skills            v  the produced .pptx
   Git + Amazon S3      Amazon S3
```

Two skills are attached to one harness:

| Skill | Source | Owns |
| --- | --- | --- |
| `pptx` | Git, [`anthropics/skills`](https://github.com/anthropics/skills) | The file format, and everything the corporate skill does not cover |
| `corporate-deck` | Amazon S3, from `skills/corporate-deck/` in this directory | Layout, colour, typography, and the checks a deck must pass |

The division matters: the published skill is upstream and receives updates, so
nothing in it is edited. Everything specific to one organisation lives in the
second skill.

## Layout

```
.
|- README.md
|- docs/DESIGN.md                        why it is split this way
|- iam/trust-policy.json                 who may assume the execution role
|- iam/execution-role-policy.json        what the harness may do
|- scripts/setup.sh                      role, bucket, skill upload, harness
|- scripts/invoke.py                     ask for a deck, pull the file out
`- skills/corporate-deck/
   |- SKILL.md                           what the agent reads
   |- scripts/build_deck.py              specification -> .pptx, template driven
   |- scripts/check_deck.py              refuses a deck a reader cannot read
   |- examples/architecture.deck.json    the specification for this README
   `- assets/README.md                   where the corporate template goes
```

## Prerequisites

- An AWS account in a
  [region where AgentCore harness is available](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/agentcore-regions.html)
- Credentials with permission to create an IAM role, an S3 bucket and a harness
- Python 3.10 or later with `boto3` and `python-pptx`
- Model access enabled in Amazon Bedrock for the model the harness uses

## Try the deck builder on its own

The corporate skill is a normal Python program, so it runs locally without any
AWS resources. This is the fastest way to see what the agent will produce.

```bash
cd skills/corporate-deck
python3 scripts/build_deck.py \
  --spec examples/architecture.deck.json \
  --out /tmp/deck.pptx
python3 scripts/check_deck.py /tmp/deck.pptx --png-dir /tmp/deck-review
```

`build_deck.py` measures every block and exits non-zero when one would cross the
bottom of the content area, naming the slide and the block. `check_deck.py`
then verifies that nothing sits outside the slide, that no text is below the
readable floor, that every slide carries speaker notes, and that no slide is
just a heading. Both must pass before a deck is handed over.

With no `--template` a neutral template is used. Point `--template` at the
corporate one and the colours, fonts and slide size follow it; see
`skills/corporate-deck/assets/README.md`.

## Deploy it

```bash
export AWS_REGION=us-west-2
export SKILL_BUCKET=my-agent-skills-bucket
export ARTIFACT_BUCKET=my-deck-output-bucket
./scripts/setup.sh
```

`setup.sh` creates the execution role from the policies in `iam/`, creates the
skill bucket, uploads `skills/corporate-deck/`, and creates or updates the
harness with both skills attached. It prints the command to poll for readiness.

`setup.sh` ends by printing an `export HARNESS_ID=` line. Run it, wait for the
status to reach `READY`, then resolve the ARN and ask for a deck:

```bash
export HARNESS_ARN=$(aws bedrock-agentcore-control get-harness \
  --harness-id "$HARNESS_ID" --query 'harnessArn || arn' --output text)
python3 scripts/invoke.py "Build a five slide deck on our Q3 cost review"
```

`invoke.py` prepares the environment, sends the request, and copies the produced
file to `s3://$ARTIFACT_BUCKET/decks/<session>.pptx`. It prints the session id;
pass it back with `--session-id` to revise the same deck on the same machine.

## Design notes worth knowing before you extend this

**Skill fetches are not silently skipped.** Every failure fails the invocation
with a message naming the cause, so a deck is never built by an agent that
quietly lost its instructions. A Git fetch must finish within 60 seconds and
needs egress; an S3 skill must be 1 GB or less and works through an S3 VPC
endpoint.

**Skills are fetched once per session** and stay on disk for its lifetime. When
the microVM is replaced the next session fetches again, so a change to the S3
skill takes effect on the next session rather than immediately.

**Prefer a container image when the template needs fonts.** The base
environment has Python and bash. Anything else is installed at session start or
baked into a `linux/arm64` image referenced on the harness. Fonts are the usual
reason to reach for the image, because a missing font changes every measurement
the layout depends on.

**Decide the exit path for the file before building.** Session storage needs no
VPC and is enough while iterating. Serving the deck from an application wants an
S3 Files access point mounted under `/mnt`, which does need VPC network mode.
This sample copies the file out with a shell command, which keeps the setup
small at the cost of one extra round trip.

## Clean up

```bash
aws bedrock-agentcore-control delete-harness --harness-id "$HARNESS_ID"
aws iam delete-role-policy --role-name CorporateDeckHarnessRole \
  --policy-name CorporateDeckHarnessInline
aws iam delete-role --role-name CorporateDeckHarnessRole
aws s3 rm "s3://$SKILL_BUCKET/skills/corporate-deck/" --recursive
```

## License

This sample is licensed under the terms in the repository root.
