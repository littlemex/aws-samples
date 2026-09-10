#!/usr/bin/env python3
"""Check a generated deck against the invariants a reader would notice.

    python3 check_deck.py deck.pptx [--png-dir out/] [--min-pt 14]

Checks, all of which have produced a visibly broken deck at least once:

  bounds      no shape extends past the edge of the slide
  font size   no text run is smaller than --min-pt
  notes       every slide carries speaker notes
  empty       no slide is left with nothing but a title

Exits non-zero when any check fails, so this can gate a pipeline. With
--png-dir the deck is also rendered to images through LibreOffice when it is
installed, because a check cannot see everything a human sees.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from pptx import Presentation

EMU_PER_PX = 9525


def check_bounds(prs) -> list:
    problems = []
    width, height = prs.slide_width, prs.slide_height
    for index, slide in enumerate(prs.slides, start=1):
        for shape in slide.shapes:
            if shape.left is None or shape.top is None:
                continue
            right = shape.left + (shape.width or 0)
            bottom = shape.top + (shape.height or 0)
            if shape.left < 0 or shape.top < 0 or right > width or bottom > height:
                problems.append(
                    f"slide {index}: {shape.shape_type} named {shape.name!r} "
                    f"sits outside the slide "
                    f"(right={right / EMU_PER_PX:.0f}px, "
                    f"bottom={bottom / EMU_PER_PX:.0f}px)")
    return problems


def _text_frames(slide):
    for shape in slide.shapes:
        if shape.has_text_frame:
            yield shape.text_frame
        if getattr(shape, "has_table", False) and shape.has_table:
            for row in shape.table.rows:
                for cell in row.cells:
                    yield cell.text_frame


def check_font_size(prs, minimum: float) -> list:
    problems = []
    for index, slide in enumerate(prs.slides, start=1):
        for frame in _text_frames(slide):
            for para in frame.paragraphs:
                for run in para.runs:
                    if run.font.size is None or not run.text.strip():
                        continue
                    if run.font.size.pt < minimum:
                        problems.append(
                            f"slide {index}: {run.font.size.pt:.0f}pt text "
                            f"{run.text.strip()[:40]!r} is below the "
                            f"{minimum:.0f}pt floor")
    return problems


def check_notes(prs) -> list:
    problems = []
    for index, slide in enumerate(prs.slides, start=1):
        if not slide.has_notes_slide:
            problems.append(f"slide {index}: no speaker notes")
            continue
        if not slide.notes_slide.notes_text_frame.text.strip():
            problems.append(f"slide {index}: speaker notes are empty")
    return problems


def check_not_empty(prs) -> list:
    problems = []
    for index, slide in enumerate(prs.slides, start=1):
        bodies = [f for f in _text_frames(slide) if f.text.strip()]
        if len(bodies) < 2:
            problems.append(f"slide {index}: nothing on it but a heading")
    return problems


def render(path: Path, out_dir: Path) -> str:
    soffice = shutil.which("soffice") or shutil.which("libreoffice")
    if soffice is None:
        return "LibreOffice not installed, skipped rendering"
    out_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run([soffice, "--headless", "--convert-to", "pdf",
                    "--outdir", str(out_dir), str(path)],
                   check=True, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL)
    pdf = out_dir / (path.stem + ".pdf")
    if shutil.which("pdftoppm") is None:
        return f"wrote {pdf}, install poppler for per-slide images"
    subprocess.run(["pdftoppm", "-r", "110", "-png", str(pdf),
                    str(out_dir / "slide")], check=True)
    count = len(list(out_dir.glob("slide-*.png")))
    return f"wrote {count} images to {out_dir}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("deck", help="the .pptx to check")
    parser.add_argument("--min-pt", type=float, default=14.0,
                        help="smallest acceptable body font size")
    parser.add_argument("--png-dir", help="also render images here")
    args = parser.parse_args()

    prs = Presentation(args.deck)
    results = {
        "bounds": check_bounds(prs),
        "font size": check_font_size(prs, args.min_pt),
        "notes": check_notes(prs),
        "empty": check_not_empty(prs),
    }

    failed = False
    for name, problems in results.items():
        if problems:
            failed = True
            print(f"[FAIL] {name}")
            for problem in problems:
                print(f"  {problem}")
        else:
            print(f"[OK] {name}")

    if args.png_dir:
        print(f"[INFO] {render(Path(args.deck), Path(args.png_dir))}")

    if failed:
        print("\nFix the reported items and rebuild. A deck that fails these "
              "checks has text a reader cannot see.", file=sys.stderr)
        return 1
    print(f"\n[OK] {len(prs.slides._sldIdLst)} slides passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
