# Design

Why this sample is shaped the way it is, and which decisions are load bearing.

## The layer that is missing, and the one that is not

A skill that produces a file is three layers.

| Layer | Portable | Supplied by |
| --- | --- | --- |
| `SKILL.md`, instructions in markdown | Yes | The skill author |
| `scripts/`, `assets/`, the code that writes the file | Yes | The skill author |
| A filesystem, a shell, and a path for the file to leave by | No | Whatever hosts the agent |

Reading a symptom report through this table settles the diagnosis quickly. When
summarisation and analysis work but document generation does not, the first two
layers are present and the third is absent. Nothing about the model changes the
answer, which is why swapping models or raising a token budget never helps.

AgentCore Harness supplies the third layer directly: an isolated microVM per
session with a filesystem and a shell, plus a built-in Code Interpreter. The
first two layers are then attached from wherever they already live.

## Two skills rather than one

The obvious shortcut is to fork the published `pptx` skill and edit the
corporate template into it. This sample deliberately does not.

A fork stops receiving upstream improvements, and every future change has to be
merged by hand against a moving target. Worse, the fork mixes two things with
different owners and different rates of change: the file format, which the
skill's authors maintain, and the house style, which the organisation maintains.

So the split is by owner:

- `pptx`, attached from Git at `anthropics/skills`, is never edited. It stays a
  URL and a subdirectory path.
- `corporate-deck`, attached from S3, holds every decision that belongs to the
  organisation: colours, fonts, block types, the checks a deck must pass.

The cost of the split is that the two skills must agree on which one leads. The
system prompt on the harness resolves that in one sentence: `corporate-deck` for
layout, `pptx` for anything it does not cover.

## The specification is data, the layout is code

`build_deck.py` accepts a JSON specification and owns every coordinate, colour
and font. The agent chooses what to say; the script chooses where it goes.

This boundary exists because of a failure that repeats otherwise. Given freedom
over coordinates, a model picks plausible numbers, and plausible numbers put
text slightly outside its box or slightly over the footer. The result looks
almost right, which is the worst outcome, because nobody catches it before the
meeting.

Two consequences follow, and both are enforced rather than documented:

**Heights are measured, never estimated.** Every block computes its own height
from the wrapped line count. When a block would cross the bottom of the content
area, the build fails and names the slide and the block. There is no flag to
disable this, because a deck with hidden text is not a faster deck, it is a
wrong one.

**Colours come from the template.** The colour scheme, font scheme and slide
size are read out of the template file. A hex value in a specification is a
defect, because the deck stops following the template the moment the template
changes.

## Monospace is checked differently

Proportional text wraps harmlessly. Code does not: a wrapped line changes what
the code appears to say, and a reader who copies it gets something that does not
run. So `code` blocks are measured against the width and the build fails when a
line is too long, rather than letting PowerPoint wrap it.

The advance widths in `build_deck.py` are deliberately generous. A viewer
without the exact font substitutes a wider one, and a measurement tuned to the
intended font produces a deck that is correct only on the machine that built it.

## What the checks cover, and what they cannot

`check_deck.py` verifies four things that have each produced a visibly broken
deck: a shape outside the slide, text below the readable floor, a slide with no
speaker notes, and a slide holding nothing but its heading.

It cannot tell whether the argument is any good, whether the heading states a
claim, or whether three cards say the same thing three ways. That is why both
`SKILL.md` and the README end the same way: render the images and look at them.
The checks exist to make the mechanical failures impossible, so that review
attention goes to the content.

## Trade-offs taken knowingly

**The file leaves through a shell command, not a mount.** Mounting an S3 Files
access point is the better answer for an application that serves decks to users,
but it requires VPC network mode, subnets and security groups, which triples the
setup a reader has to follow before seeing anything work. This sample copies the
file out with `InvokeAgentRuntimeCommand` and says so in the README, alongside
the mount option and when to prefer it.

**No template is committed.** Corporate templates are usually not
redistributable, and shipping one would invite decks that follow somebody else's
brand. `build_deck.py` falls back to a neutral template so the sample runs
unchanged, and the fallback is obviously not anybody's house style.

**The base environment is used as it is.** `python-pptx` is installed at session
start rather than baked into an image, which costs a few seconds per session and
keeps the sample to two scripts. A deployment whose template depends on specific
fonts should move to a custom `linux/arm64` container image; that is a change to
one harness field, not to this code.
