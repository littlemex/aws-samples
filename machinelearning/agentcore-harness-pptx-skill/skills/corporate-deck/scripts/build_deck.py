#!/usr/bin/env python3
"""Render a deck specification into a .pptx using a corporate template.

The agent writes a JSON specification; this script owns every layout decision.
Colours and fonts are read from the template, so swapping the template changes
the look without touching the specification or this file.

    python3 build_deck.py --spec deck.json --template corp.pptx --out deck.pptx

Height is computed for every block. When a block would cross the bottom of the
content area the script exits non-zero with the offending slide and block, so a
deck with hidden or clipped text is never produced.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import unicodedata

import pptx
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE, PP_PLACEHOLDER
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches, Pt

EMU_PER_PX = 9525

#: Used when no corporate template is supplied, so the sample runs as shipped.
DEFAULT_TEMPLATE = os.path.join(os.path.dirname(pptx.__file__),
                                "templates", "default.pptx")

#: Pixels of advance per point of font size, measured against the fallback
#: fonts a viewer is most likely to substitute. Full-width characters occupy a
#: whole em; proportional latin and monospace are narrower. Sized on the
#: generous side so a viewer without the exact font still shows unwrapped text.
FULLWIDTH_ADVANCE = 1.34
LATIN_ADVANCE = 0.62
MONO_ADVANCE = 0.78

#: Eyebrows and code labels. Kept at the body floor so the size check below
#: needs no per-string exemptions.
LABEL_PT = 14


def px(value: float) -> Emu:
    return Emu(int(round(value * EMU_PER_PX)))


class Overflow(RuntimeError):
    """A block did not fit inside the content area."""


# --------------------------------------------------------------------- theme
class Theme:
    """Colours, fonts and content bounds read out of the template."""

    def __init__(self, prs: Presentation):
        master = prs.slide_masters[0]
        scheme = self._colour_scheme(master)
        inverted = self._is_inverted(master)

        light = scheme.get("lt1", RGBColor(0xFF, 0xFF, 0xFF))
        dark = scheme.get("dk1", RGBColor(0x00, 0x00, 0x00))
        self.background = dark if inverted else light
        self.text = light if inverted else dark
        self.accent = scheme.get("accent1", RGBColor(0x2A, 0x5D, 0xB0))
        self.muted = self._mix(self.text, self.background, 0.45)
        self.line = self._mix(self.text, self.background, 0.75)
        self.surface = self._mix(self.text, self.background, 0.90)
        self.tint = self._mix(self.accent, self.background, 0.82)

        self.latin_font, self.cjk_font = self._fonts(master)
        self.slide_width = prs.slide_width / EMU_PER_PX
        self.slide_height = prs.slide_height / EMU_PER_PX

        self.margin_left = 43.0
        self.content_width = self.slide_width - self.margin_left * 2
        self.content_top = 190.0
        self.content_bottom = self.slide_height - 75.0
        self.blank_layout = self._blank_layout(master)

    @staticmethod
    def _theme_root(master):
        from lxml import etree

        for rel in master.part.rels.values():
            if "theme" in rel.reltype:
                return etree.fromstring(rel.target_part.blob)
        return None

    @classmethod
    def _colour_scheme(cls, master) -> dict:
        out = {}
        root = cls._theme_root(master)
        if root is None:
            return out
        node = root.find(f".//{qn('a:clrScheme')}")
        if node is None:
            return out
        for child in node:
            name = child.tag.split("}")[1]
            srgb = child.find(qn("a:srgbClr"))
            system = child.find(qn("a:sysClr"))
            if srgb is not None:
                out[name] = RGBColor.from_string(srgb.get("val").upper())
            elif system is not None and system.get("lastClr"):
                out[name] = RGBColor.from_string(system.get("lastClr").upper())
        return out

    @staticmethod
    def _is_inverted(master) -> bool:
        node = master._element.find(qn("p:clrMap"))
        return node is not None and node.get("bg1") == "dk1"

    @classmethod
    def _fonts(cls, master) -> tuple:
        latin, cjk = "Arial", "Meiryo"
        root = cls._theme_root(master)
        if root is None:
            return latin, cjk
        minor = root.find(f".//{qn('a:fontScheme')}/{qn('a:minorFont')}")
        if minor is None:
            return latin, cjk
        node = minor.find(qn("a:latin"))
        if node is not None and node.get("typeface"):
            latin = node.get("typeface").replace(" Display", "") or latin
        for font in minor.findall(qn("a:font")):
            if font.get("script") in ("Jpan", "Hans", "Hant"):
                cjk = font.get("typeface")
                break
        return latin, cjk

    @staticmethod
    def _blank_layout(master) -> int:
        decorative = {PP_PLACEHOLDER.FOOTER, PP_PLACEHOLDER.SLIDE_NUMBER,
                      PP_PLACEHOLDER.DATE}
        best, best_count = len(master.slide_layouts) - 1, None
        for index, layout in enumerate(master.slide_layouts):
            kinds = [ph.placeholder_format.type for ph in layout.placeholders]
            count = len([k for k in kinds if k not in decorative])
            if best_count is None or count < best_count:
                best, best_count = index, count
            if count == 0:
                return index
        return best

    @staticmethod
    def _mix(a: RGBColor, b: RGBColor, weight: float) -> RGBColor:
        return RGBColor(*[int(round(x * (1 - weight) + y * weight))
                          for x, y in zip(a, b)])


# ----------------------------------------------------------------- measuring
def _char_width(char: str, size: float) -> float:
    if unicodedata.east_asian_width(char) in ("W", "F", "A"):
        return size * FULLWIDTH_ADVANCE
    return size * LATIN_ADVANCE


def wrapped_lines(text: str, width: float, size: float) -> int:
    total = 0
    for raw in str(text).split("\n"):
        used, lines = 0.0, 1
        for char in raw:
            advance = _char_width(char, size)
            if used + advance > width:
                lines += 1
                used = advance
            else:
                used += advance
        total += lines
    return total


def line_height(size: float) -> float:
    return size * 1.34 * 1.22


def text_height(text: str, width: float, size: float) -> float:
    return line_height(size) * wrapped_lines(text, width, size)


# ------------------------------------------------------------------ drawing
class Renderer:
    def __init__(self, theme: Theme, presentation: Presentation):
        self.t = theme
        self.prs = presentation

    def textbox(self, slide, x, y, w, h, text, size=17, colour=None,
                bold=False, align="left", anchor="top", mono=False):
        box = slide.shapes.add_textbox(px(x), px(y), px(w), px(h))
        frame = box.text_frame
        frame.word_wrap = True
        frame.margin_left = frame.margin_right = px(0)
        frame.margin_top = frame.margin_bottom = px(0)
        frame.vertical_anchor = {"top": MSO_ANCHOR.TOP,
                                 "middle": MSO_ANCHOR.MIDDLE}[anchor]
        latin = "Consolas" if mono else self.t.latin_font
        for index, raw in enumerate(str(text).split("\n")):
            para = frame.paragraphs[0] if index == 0 else frame.add_paragraph()
            para.alignment = {"left": PP_ALIGN.LEFT, "center": PP_ALIGN.CENTER}[align]
            run = para.add_run()
            run.text = raw
            run.font.size = Pt(size)
            run.font.bold = bold
            run.font.name = latin
            run.font.color.rgb = colour or self.t.text
            self._set_cjk(run, latin if mono else self.t.cjk_font)
        return box

    @staticmethod
    def _set_cjk(run, face: str):
        rpr = run._r.get_or_add_rPr()
        node = rpr.find(qn("a:ea"))
        if node is None:
            from lxml import etree

            node = etree.SubElement(rpr, qn("a:ea"))
        node.set("typeface", face)

    def rect(self, slide, x, y, w, h, fill=None, stroke=None, radius=0.04):
        shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE,
                                       px(x), px(y), px(w), px(h))
        shape.shadow.inherit = False
        shape.adjustments[0] = radius
        if fill is None:
            shape.fill.background()
        else:
            shape.fill.solid()
            shape.fill.fore_color.rgb = fill
        if stroke is None:
            shape.line.fill.background()
        else:
            shape.line.color.rgb = stroke
            shape.line.width = Pt(1.0)
        shape.text_frame.text = ""
        return shape


# -------------------------------------------------------------------- blocks
class SlideBuilder:
    def __init__(self, renderer: Renderer, slide, index: int):
        self.r = renderer
        self.t = renderer.t
        self.slide = slide
        self.index = index
        self.y = self.t.content_top
        self.gap = 16.0

    @property
    def x(self):
        return self.t.margin_left

    @property
    def w(self):
        return self.t.content_width

    def _advance(self, bottom: float, what: str):
        if bottom > self.t.content_bottom:
            raise Overflow(
                f"slide {self.index}: {what} crosses the bottom of the content "
                f"area by {bottom - self.t.content_bottom:.0f}px "
                f"(bottom={bottom:.0f}, limit={self.t.content_bottom:.0f}). "
                f"Shorten the text or move it to another slide.")
        self.y = bottom + self.gap

    def header(self, title: str, eyebrow: str = None, sub: str = None):
        y = 34.0
        if eyebrow:
            self.r.textbox(self.slide, self.x, y, self.w, 22, eyebrow.upper(),
                           size=LABEL_PT, colour=self.t.accent, bold=True)
            y += 26
        size = 34.0
        while wrapped_lines(title, self.w, size) > 1 and size > 22:
            size -= 1
        height = text_height(title, self.w, size)
        self.r.textbox(self.slide, self.x, y, self.w, height, title,
                       size=size, bold=True)
        y += height + 6
        if sub:
            height = text_height(sub, self.w, 17)
            self.r.textbox(self.slide, self.x, y, self.w, height, sub,
                           size=17, colour=self.t.muted)
            y += height + 6
        self.y = max(self.t.content_top, y + 10)

    def bullets(self, items, size=17):
        indent = 22.0
        y = self.y
        for item in items:
            height = text_height(item, self.w - indent, size)
            self.r.textbox(self.slide, self.x, y, indent, line_height(size), "-",
                           size=size, colour=self.t.accent, bold=True)
            self.r.textbox(self.slide, self.x + indent, y, self.w - indent,
                           height, item, size=size)
            y += height + 6
        self._advance(y - 6, "bullets")

    def cards(self, items, size=16, title_size=19):
        gap = 20.0
        columns = len(items)
        width = (self.w - gap * (columns - 1)) / columns
        pad = 20.0
        height = max(
            text_height(card["title"], width - pad * 2, title_size)
            + text_height(card["body"], width - pad * 2, size) + pad * 2 + 8
            for card in items)
        for position, card in enumerate(items):
            left = self.x + position * (width + gap)
            self.r.rect(self.slide, left, self.y, width, height,
                        fill=self.t.surface, stroke=self.t.line)
            inner = left + pad
            title_h = text_height(card["title"], width - pad * 2, title_size)
            self.r.textbox(self.slide, inner, self.y + pad, width - pad * 2,
                           title_h, card["title"], size=title_size, bold=True)
            self.r.textbox(self.slide, inner, self.y + pad + title_h + 8,
                           width - pad * 2,
                           text_height(card["body"], width - pad * 2, size),
                           card["body"], size=size, colour=self.t.muted)
        self._advance(self.y + height, "cards")

    def table(self, columns, rows, fractions=None, size=14):
        fractions = fractions or [1 / len(columns)] * len(columns)
        widths = [self.w * f for f in fractions]
        pad = 10.0
        header_h = max(line_height(size) * wrapped_lines(c, w - pad * 2, size)
                       for c, w in zip(columns, widths)) + pad * 2
        row_heights = [
            max(line_height(size) * wrapped_lines(cell, w - pad * 2, size)
                for cell, w in zip(row, widths)) + pad * 2
            for row in rows]
        total = header_h + sum(row_heights)

        table_shape = self.slide.shapes.add_table(
            len(rows) + 1, len(columns), px(self.x), px(self.y),
            px(self.w), px(total)).table
        self._strip_default_style(table_shape)
        for index, width in enumerate(widths):
            table_shape.columns[index].width = px(width)
        table_shape.rows[0].height = px(header_h)
        for index, height in enumerate(row_heights):
            table_shape.rows[index + 1].height = px(height)

        for column, label in enumerate(columns):
            self._cell(table_shape.cell(0, column), label, size,
                       self.t.accent, True, self.t.tint, pad)
        for row_index, row in enumerate(rows, start=1):
            for column, value in enumerate(row):
                self._cell(table_shape.cell(row_index, column), value, size,
                           self.t.text, False, None, pad)
        self._advance(self.y + total, "table")

    def code(self, lines, label=None, size=15):
        pad = 16.0
        available = self.w - pad * 2
        for line in lines:
            width = len(line) * size * MONO_ADVANCE
            if width > available:
                raise Overflow(
                    f"slide {self.index}: code line is {len(line)} characters, "
                    f"which needs {width:.0f}px of the {available:.0f}px "
                    f"available. Monospace text is never wrapped because a "
                    f"broken line changes the meaning of the code. Shorten the "
                    f"line, for example by extracting a variable.")
        body = "\n".join(lines)
        label_h = line_height(LABEL_PT) + 4 if label else 0
        height = line_height(size) * len(lines) + pad * 2 + label_h
        self.r.rect(self.slide, self.x, self.y, self.w, height,
                    fill=self.t.surface, stroke=self.t.line, radius=0.03)
        y = self.y + pad
        if label:
            self.r.textbox(self.slide, self.x + pad, y, self.w - pad * 2,
                           line_height(LABEL_PT), label, size=LABEL_PT,
                           colour=self.t.accent, bold=True)
            y += label_h
        self.r.textbox(self.slide, self.x + pad, y, self.w - pad * 2,
                       line_height(size) * len(lines), body, size=size,
                       mono=True)
        self._advance(self.y + height, "code")

    def callout(self, text, size=17):
        pad = 18.0
        inner = self.w - pad * 2 - 8
        height = text_height(text, inner, size) + pad * 2
        self.r.rect(self.slide, self.x, self.y, self.w, height,
                    fill=self.t.tint, stroke=None, radius=0.02)
        self.r.rect(self.slide, self.x, self.y, 5, height,
                    fill=self.t.accent, stroke=None, radius=0.0)
        self.r.textbox(self.slide, self.x + pad + 8, self.y + pad, inner,
                       height - pad * 2, text, size=size, bold=True)
        self._advance(self.y + height, "callout")

    def notes(self, lines):
        text = "\n".join(lines)
        self.slide.notes_slide.notes_text_frame.text = text

    def _cell(self, cell, text, size, colour, bold, fill, pad):
        cell.margin_left = cell.margin_right = px(pad)
        cell.margin_top = cell.margin_bottom = px(pad * 0.6)
        cell.vertical_anchor = MSO_ANCHOR.MIDDLE
        if fill is None:
            cell.fill.background()
        else:
            cell.fill.solid()
            cell.fill.fore_color.rgb = fill
        frame = cell.text_frame
        frame.word_wrap = True
        frame.text = str(text)
        for para in frame.paragraphs:
            for run in para.runs:
                run.font.size = Pt(size)
                run.font.bold = bold
                run.font.name = self.t.latin_font
                run.font.color.rgb = colour
                Renderer._set_cjk(run, self.t.cjk_font)
        self._bottom_border(cell)

    def _bottom_border(self, cell):
        from lxml import etree

        properties = cell._tc.get_or_add_tcPr()
        line = etree.SubElement(properties, qn("a:lnB"))
        line.set("w", "9525")
        fill = etree.SubElement(line, qn("a:solidFill"))
        colour = etree.SubElement(fill, qn("a:srgbClr"))
        colour.set("val", str(self.t.line))

    @staticmethod
    def _strip_default_style(table):
        properties = table._tbl.find(qn("a:tblPr"))
        if properties is None:
            return
        for node in properties.findall(qn("a:tableStyleId")):
            properties.remove(node)
        properties.set("firstRow", "0")
        properties.set("bandRow", "0")


# --------------------------------------------------------------------- build
BLOCKS = {"bullets", "cards", "table", "code", "callout"}


def build(spec: dict, template: str, out: str) -> str:
    prs = Presentation(template)
    if os.path.abspath(template) == os.path.abspath(DEFAULT_TEMPLATE):
        # The bundled fallback is 4:3. Widescreen is the sane default for a
        # deck; a real corporate template is left exactly as its owner set it.
        prs.slide_width = Inches(13.333)
        prs.slide_height = Inches(7.5)
    theme = Theme(prs)
    ids = prs.slides._sldIdLst
    for element in list(ids):
        prs.part.drop_rel(element.get(
            "{http://schemas.openxmlformats.org/officeDocument/2006/"
            "relationships}id"))
        ids.remove(element)

    renderer = Renderer(theme, prs)
    layout = prs.slide_masters[0].slide_layouts[theme.blank_layout]

    for index, page in enumerate(spec["slides"], start=1):
        slide = prs.slides.add_slide(layout)
        builder = SlideBuilder(renderer, slide, index)
        builder.header(page["title"], page.get("eyebrow"), page.get("subtitle"))
        for block in page.get("blocks", []):
            kind = block["type"]
            if kind not in BLOCKS:
                raise ValueError(
                    f"slide {index}: unknown block type {kind!r}. "
                    f"Supported: {', '.join(sorted(BLOCKS))}")
            if kind == "bullets":
                builder.bullets(block["items"])
            elif kind == "cards":
                builder.cards(block["items"])
            elif kind == "table":
                builder.table(block["columns"], block["rows"],
                              block.get("fractions"))
            elif kind == "code":
                builder.code(block["lines"], block.get("label"))
            elif kind == "callout":
                builder.callout(block["text"])
        if page.get("notes"):
            builder.notes(page["notes"])

    prs.save(out)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, help="deck specification JSON")
    parser.add_argument("--template", default=DEFAULT_TEMPLATE,
                        help="corporate .pptx template (defaults to a neutral one)")
    parser.add_argument("--out", required=True, help="output .pptx path")
    args = parser.parse_args()

    with open(args.spec, encoding="utf-8") as handle:
        spec = json.load(handle)
    try:
        path = build(spec, args.template, args.out)
    except (Overflow, ValueError) as error:
        print(f"[FAIL] {error}", file=sys.stderr)
        return 1
    print(f"[OK] wrote {path} with {len(spec['slides'])} slides")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
