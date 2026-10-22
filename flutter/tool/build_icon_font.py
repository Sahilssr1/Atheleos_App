"""Builds assets/fonts/AthIcons.ttf and lib/core/widgets/ath_icons.dart from the
icon packages used by the Atheleos website (reicon-react + @heroicons/react).

Usage: python tool/build_icon_font.py [path-to-website-node_modules]
Requires: pip install picosvg fonttools
"""
import pathlib
import re
import sys

import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path
from picosvg.svg import SVG

ROOT = pathlib.Path(__file__).resolve().parent.parent
NODE_MODULES = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else r"D:\Atheleos\node_modules")
UPM = 960
SCALE = UPM / 24

# (dart name, reicon name, weight)
REICONS = [
    ("home", "Home", "O"), ("homeFill", "Home", "F"),
    ("search", "Search", "O"), ("searchFill", "Search", "F"),
    ("playCircle", "PlayCircle", "O"), ("playCircleFill", "PlayCircle", "F"),
    ("plusCircle", "PlusCircle", "O"), ("plusCircleFill", "PlusCircle", "F"),
    ("calendar", "Calendar", "O"), ("calendarFill", "Calendar", "F"),
    ("chatRound", "ChatRound", "O"), ("chatRoundFill", "ChatRound", "F"),
    ("bell", "Bell", "O"), ("bellFill", "Bell", "F"),
    ("heart", "Heart", "O"), ("heartFill", "Heart", "F"),
    ("send", "Send2", "O"), ("sendFill", "Send2", "F"),
    ("bookmark", "Bookmark", "O"), ("bookmarkFill", "Bookmark", "F"),
    ("more", "More", "O"),
    ("play", "Play", "F"), ("pause", "Pause", "F"),
    ("volumeHigh", "VolumeHigh", "O"), ("volumeMute", "VolumeMute", "O"),
]

HERO_OUTLINE = """AcademicCap ArrowDownTray ArrowLeft ArrowRight ArrowRightOnRectangle ArrowPath
ArrowUpTray BuildingLibrary BuildingOffice BuildingStorefront Camera ChartBar
ChatBubbleLeftRight ChatBubbleOvalLeftEllipsis ChatBubbleOvalLeft CheckBadge CheckCircle Check
ChevronDown ChevronLeft ChevronRight ChevronUp Clock CloudArrowUp Cog6Tooth CpuChip DevicePhoneMobile
DocumentArrowDown DocumentText DocumentDuplicate EllipsisHorizontal EllipsisVertical Envelope
ExclamationTriangle ExclamationCircle Eye EyeSlash Film Flag GlobeAlt InformationCircle Key Link
LockClosed LockOpen MagnifyingGlass MapPin NoSymbol PaperAirplane PaperClip PencilSquare Pencil Phone Photo
Plus PlusCircle QuestionMarkCircle Share ShieldCheck Sparkles Squares2X2 Star Ticket Trash Trophy
UserGroup User UserCircle UserPlus UserMinus Users VideoCamera XMark XCircle Wifi Signal SignalSlash
ArrowUturnLeft Briefcase Megaphone Newspaper Cake QrCode Scale Bolt CurrencyRupee ArrowTrendingUp
Funnel AdjustmentsHorizontal Hashtag AtSymbol Identification ClipboardDocumentList Language
Bars3 HandThumbUp Fire Swatch FolderOpen Document Inbox ArrowTopRightOnSquare Minus Stop""".split()
HERO_SOLID = ["CheckBadge", "CheckCircle", "Star", "Heart", "Bookmark", "MapPin", "User", "ExclamationCircle"]


def camel(name):
    return name[0].lower() + name[1:]


def reicon_svg(name, weight):
    src = (NODE_MODULES / "reicon-react" / "icons" / f"{name}.js").read_text(encoding="utf-8")
    match = re.search(weight + r":\s*`([^`]*)`", src)
    if not match:
        raise SystemExit(f"reicon {name} has no {weight} variant")
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">{match.group(1)}</svg>'


def hero_svg(name, style):
    path = NODE_MODULES / "@heroicons" / "react" / "24" / style / f"{name}Icon.js"
    if not path.exists():
        return None
    src = path.read_text(encoding="utf-8")
    parts = []
    for match in re.finditer(r'createElement\("path",\s*\{(.*?)\}\)', src, re.S):
        body = match.group(1)
        d = re.search(r'd:\s*"([^"]+)"', body).group(1)
        attrs = ' fill-rule="evenodd" clip-rule="evenodd"' if "fillRule" in body else ""
        parts.append(f'<path{attrs} d="{d}"/>')
    inner = "".join(parts)
    if style == "outline":
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
                'stroke="currentColor" stroke-width="1.5" stroke-linecap="round" '
                f'stroke-linejoin="round">{inner}</svg>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">{inner}</svg>'


def svg_to_path(svg_text):
    if 'stroke="currentColor"' in svg_text:
        return _stroked_svg_to_path(svg_text)
    pico = SVG.fromstring(svg_text.replace("currentColor", "black")).topicosvg()
    paths = []
    for shape in pico.shapes():
        p = pathops.Path()
        parse_path(shape.as_path().d, _PathopsPen(p))
        if getattr(shape, "fill_rule", "nonzero") == "evenodd":
            p.fillType = pathops.FillType.EVEN_ODD
        paths.append(p)
    result = pathops.Path()
    builder = pathops.OpBuilder(fix_winding=True, keep_starting_points=False)
    for p in paths:
        builder.add(p, pathops.PathOp.UNION)
    return builder.resolve()


def _stroked_svg_to_path(svg_text):
    width = float(re.search(r'stroke-width="([\d.]+)"', svg_text).group(1))
    result = None
    contours = []
    for d in re.findall(r'\sd="([^"]+)"', svg_text):
        full = pathops.Path()
        parse_path(d, _PathopsPen(full))
        contours.extend(full.contours)
    for p in contours:
        p.stroke(width, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
        p.convertConicsToQuads()
        p = pathops.simplify(p, fix_winding=True, keep_starting_points=False)
        result = p if result is None else pathops.op(
            result, p, pathops.PathOp.UNION, fix_winding=True, keep_starting_points=False)
    return result


class _PathopsPen:
    """Adapts fontTools' segment pen protocol to a pathops Path."""

    def __init__(self, path):
        self._pen = path.getPen()

    def moveTo(self, pt):
        self._pen.moveTo(pt)

    def lineTo(self, pt):
        self._pen.lineTo(pt)

    def curveTo(self, *pts):
        self._pen.curveTo(*pts)

    def qCurveTo(self, *pts):
        self._pen.qCurveTo(*pts)

    def closePath(self):
        self._pen.closePath()

    def endPath(self):
        self._pen.endPath()


def build():
    entries = []
    for dart_name, name, weight in REICONS:
        entries.append((dart_name, reicon_svg(name, weight)))
    taken = {e[0] for e in entries}
    for name in HERO_OUTLINE:
        dart_name = camel(name)
        if dart_name in taken:
            dart_name = "hero" + name
        svg = hero_svg(name, "outline")
        if svg is None:
            print("skip missing heroicon", name)
            continue
        entries.append((dart_name, svg))
        taken.add(dart_name)
    for name in HERO_SOLID:
        dart_name = camel(name) + "Solid"
        svg = hero_svg(name, "solid")
        if svg is not None:
            entries.append((dart_name, svg))

    glyph_order = [".notdef"]
    glyphs = {}
    cmap = {}
    advance = {}
    empty = TTGlyphPen(None)
    glyphs[".notdef"] = empty.glyph()
    advance[".notdef"] = (UPM, 0)

    codepoints = []
    for index, (dart_name, svg) in enumerate(entries):
        codepoint = 0xE000 + index
        path = svg_to_path(svg)
        tt_pen = TTGlyphPen(None)
        # SVG is y-down in a 24 unit box; fonts are y-up.
        transform = TransformPen(Cu2QuPen(tt_pen, max_err=1.0, reverse_direction=True),
                                 (SCALE, 0, 0, -SCALE, 0, UPM))
        path.draw(transform)
        glyphs[dart_name] = tt_pen.glyph()
        glyph_order.append(dart_name)
        cmap[codepoint] = dart_name
        advance[dart_name] = (UPM, 0)
        codepoints.append((dart_name, codepoint))

    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(advance)
    fb.setupHorizontalHeader(ascent=UPM, descent=0)
    fb.setupNameTable({"familyName": "AthIcons", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=UPM, sTypoDescender=0, usWinAscent=UPM, usWinDescent=0)
    fb.setupPost()
    font_path = ROOT / "assets" / "fonts" / "AthIcons.ttf"
    font_path.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(font_path))

    lines = [
        "// Generated by tool/build_icon_font.py from the Atheleos website icon packages",
        "// (reicon-react and @heroicons/react 24). Do not edit by hand.",
        "import 'package:flutter/widgets.dart';",
        "",
        "class AthIcons {",
        "  AthIcons._();",
        "",
        "  static const String _family = 'AthIcons';",
        "",
    ]
    for dart_name, codepoint in codepoints:
        lines.append(f"  static const IconData {dart_name} = IconData(0x{codepoint:X}, fontFamily: _family);")
    lines.append("}")
    (ROOT / "lib" / "core" / "widgets" / "ath_icons.dart").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"built {len(codepoints)} icons -> {font_path}")


if __name__ == "__main__":
    build()
