---
name: corporate-deck
description: Build a PowerPoint deck that follows the corporate template. Use whenever the request is to produce slides, a deck, a presentation, or a .pptx. Owns layout, colour and typography; pairs with the published pptx skill for anything this skill does not cover.
---

# Corporate deck

Produce a deck as native PowerPoint shapes, laid out by `scripts/build_deck.py`,
so the recipient can move boxes, retype text and search the content. Never
assemble slides by hand and never paste images of text.

## How to work

1. Decide the content before writing any file. One claim per slide, stated in
   the heading. Put the conclusion on the first slide, not the last.
2. Write a deck specification to `deck.json`. The schema is below.
3. Build it. Pass `--template` when a corporate template is present in
   `assets/`; without it a neutral template is used so the skill still runs.

       python3 scripts/build_deck.py --spec deck.json \
         --template assets/template.pptx --out deck.pptx

4. Check it:

       python3 scripts/check_deck.py deck.pptx --png-dir review/

5. If either command exits non-zero, fix the specification and repeat. Do not
   hand over a deck that has not passed both.
6. Look at the rendered images in `review/` before handing over. The checks
   catch text a reader cannot see; they do not catch a slide that is merely
   badly argued.

## Rules this skill enforces

- **Never choose a colour, a font or a coordinate.** Every one of those comes
  from the template through `build_deck.py`. Writing a hex value into the
  specification is a defect, because the deck then stops following the template
  the moment the template changes.
- **Never guess a height.** The script measures every block and refuses to
  write a deck where anything crosses the bottom of the content area. If it
  refuses, there is too much on the slide; split it.
- **Headings state a claim.** "Costs fall by a third when the cache is warm",
  not "About caching".
- **Every slide carries speaker notes.** They are what the presenter says, in
  plain sentences.

## Specification schema

```json
{
  "slides": [
    {
      "eyebrow": "Section label, optional",
      "title": "The claim this slide makes",
      "subtitle": "One supporting line, optional",
      "blocks": [],
      "notes": ["One line per sentence the presenter says"]
    }
  ]
}
```

Blocks are applied top to bottom in the order given.

| `type` | Fields | Use for |
| --- | --- | --- |
| `bullets` | `items`: list of strings | A short list of related points |
| `cards` | `items`: list of `{title, body}` | Two or three parallel ideas side by side |
| `table` | `columns`, `rows`, optional `fractions` | A comparison across more than one axis |
| `code` | `lines`: list of strings, optional `label` | An API call or command, exactly as it is typed |
| `sequence` | `steps`: list of `{caller, api, note}` | The order calls happen in, when the order is the point |
| `callout` | `text`: string | The one line to remember from the slide |

`fractions` are column widths as fractions of the content width and must sum to
1. Give the widest fraction to the column with the longest cells.

`code` lines are never wrapped, because a broken line changes what the code
means. If a line is too wide the build fails and names the line; shorten it by
extracting a variable rather than by deleting part of the call.

`sequence` numbers its steps from their position in the list, so never write a
number into `caller`, `api` or `note`. Reordering the list renumbers the slide,
which is the point: the deck cannot end up disagreeing with itself about which
call comes first. Put the exact API name in `api` and leave `note` for what the
call achieves. Use this instead of a box-and-arrow picture whenever the reader
needs the order rather than the topology.

Any text field may carry a link as `[label](https://example.com)`. Only the
label is measured, so a long URL never forces a wrap. Link the first mention of
anything a reader might want to open — a repository, a document, a console page.

## Adapting this skill

No template ships with this sample. Put the corporate one at
`assets/template.pptx`, with all of its slides deleted so only the master and
layouts remain:

```python
from pptx import Presentation

RID = ("{http://schemas.openxmlformats.org/officeDocument/2006/"
       "relationships}id")
prs = Presentation("corporate-original.pptx")
ids = prs.slides._sldIdLst
for element in list(ids):
    prs.part.drop_rel(element.get(RID))
    ids.remove(element)
prs.save("assets/template.pptx")
```

`build_deck.py` then reads the colour scheme, the font scheme and the slide
size out of that file. Nothing else needs to change.
