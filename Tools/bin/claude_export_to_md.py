#!/usr/bin/env python3
"""
Convert a Claude Code `/export` .txt transcript into clean Markdown.

The export is a screen dump of the terminal UI: prose is hard-wrapped at the
terminal width, turns are marked with glyphs (❯ > ● ⏺ ⎿ ✻ ※), and tables are
drawn with box characters. This script reverses that layout:

  - banner art      -> YAML frontmatter (version, model, cwd, date)
  - ❯ / > prompts   -> "## User" blockquotes
  - ● prose         -> "## Claude" sections, soft wraps joined
  - ● Tool(args)    -> collapsible <details> blocks (or brief/none)
  - box tables      -> GFM tables
  - ★ Insight boxes -> blockquotes
  - ✻ status lines  -> dropped

Usage:
    claude_export_to_md.py session.txt                 # writes session.md
    claude_export_to_md.py a.txt b.txt -d out/         # batch into out/
    claude_export_to_md.py session.txt -o -            # stdout
    claude_export_to_md.py session.txt --tools brief   # one line per tool call
"""

import argparse
import html
import json
import re
import sys
from pathlib import Path

ASSIST_RE = re.compile(r"^(?:●|⏺) ?(.*)$")
TOOL_RE = re.compile(
    r"^(?:●|⏺) ((?:[A-Z]\w*|mcp__[\w-]+|[a-z][\w-]*:[\w:-]+)(?: \(MCP\))?)\((.*)$"
)
OUTPUT_RE = re.compile(r"^\s{1,8}⎿ ?\s?(.*)$")
STATUS_RE = re.compile(r"^✻ ")
RECAP_RE = re.compile(r"^※ ?(.*)$")
COLLAPSED_RE = re.compile(r"^\s+(\S.*?)\s*\((?:↓ to manage · )?ctrl\+o to expand\)\s*$")
EXPAND_HINT_RE = re.compile(r"\s*\((?:↓ to manage · )?ctrl\+o to expand\)")
BOX_RE = re.compile(r"^\s*[┌├└│]")
TABLE_TOP_RE = re.compile(r"^\s*┌[─┬]+┐\s*$")
DIAGRAM_RE = re.compile(r"[─│┌┐└┘├┤┬┴┼▼▲►◄]")
QUOTE_RE = re.compile(r"^▎ ?")
RULE_RE = re.compile(r"^\s*─{8,}\s*$")
INSIGHT_RE = re.compile(r"^\s*★ Insight")
LIST_RE = re.compile(r"^(\s*)(?:[-*•·]|\d+[.)])\s+")
CODEY_RE = re.compile(
    r"[{};]\s*$|\w\(.*\)\s*$|=>|->|::|\s[!=]==?\s|^\s*[@$#]|^\s*(def|end|class|module|"
    r"import|from|return|if|for|while|const|let|var|function|require|fn|pub|use)\b"
)
RECORD_KEY_RE = re.compile(r"^\s*[A-Z][a-z][\w /-]{0,30}: ")
VERSION_RE = re.compile(r"Claude Code v([\d.]+)")
CWD_RE = re.compile(r"\s((?:~|/)\S*)\s*$")
MODEL_RE = re.compile(r"((?:Opus|Sonnet|Haiku|Fable|Claude)[^·]*?)\s*·")
DATE_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})(?:-(\d{2})(\d{2})(\d{2}))?")

FENCE_LANG = {"Bash": "bash", "PowerShell": "powershell"}


# ---------------------------------------------------------------- parsing


def indent_of(line):
    return len(line) - len(line.lstrip(" "))


def is_marker(line):
    return bool(
        ASSIST_RE.match(line) or STATUS_RE.match(line) or RECAP_RE.match(line)
    )


class Parser:
    """Line-based state machine producing a flat list of blocks."""

    def __init__(self, lines):
        self.lines = [l.rstrip("\n").replace(" ", " ") for l in lines]
        self.prompt_re = re.compile(
            r"^❯ ?(.*)$" if any(l.startswith("❯") for l in self.lines) else r"^> ?(.*)$"
        )
        self.width = self._detect_width()
        self.meta = {}
        self.blocks = []

    def _detect_width(self):
        # Prompt lines are space-padded to the terminal width.
        widths = [len(l) for l in self.lines if self.prompt_re.match(l) and l.endswith(" ")]
        return max(widths) if widths else 80

    def is_prompt(self, line):
        return bool(self.prompt_re.match(line))

    def is_top(self, line):
        return self.is_prompt(line) or is_marker(line)

    def parse(self):
        i = self._parse_banner()
        n = len(self.lines)
        while i < n:
            line = self.lines[i]
            if not line.strip():
                i += 1
            elif self.is_prompt(line):
                i = self._parse_prompt(i)
            elif STATUS_RE.match(line):
                i += 1
            elif RECAP_RE.match(line):
                i = self._parse_recap(i)
            elif OUTPUT_RE.match(line):
                i = self._parse_output(i, owner=None)
            elif COLLAPSED_RE.match(line):
                self.blocks.append(("note", EXPAND_HINT_RE.sub("", line).strip()))
                i += 1
            elif TOOL_RE.match(line):
                i = self._parse_tool(i)
            else:
                i = self._parse_prose(i)
        return self.blocks

    def _parse_banner(self):
        for i, line in enumerate(self.lines):
            if self.is_top(line):
                break
            if m := VERSION_RE.search(line):
                self.meta["claude_code_version"] = m.group(1)
            elif m := MODEL_RE.search(line):
                self.meta["model"] = m.group(1).strip()
            elif "model" in self.meta and "cwd" not in self.meta and (m := CWD_RE.search(line)):
                self.meta["cwd"] = m.group(1)
        else:
            return len(self.lines)
        return i

    def _parse_prompt(self, i):
        out = [self.prompt_re.match(self.lines[i]).group(1)]
        raw = [self.lines[i]]
        i += 1
        while i < len(self.lines):
            line = self.lines[i]
            if self.is_top(line) or OUTPUT_RE.match(line) or COLLAPSED_RE.match(line):
                break
            out.append(line)
            raw.append(line)
            i += 1
        self.blocks.append(("user", unwrap(raw, out, self.width)))
        return i

    def _parse_recap(self, i):
        parts = [RECAP_RE.match(self.lines[i]).group(1)]
        i += 1
        while i < len(self.lines) and self.lines[i].strip() and not self.is_top(self.lines[i]):
            parts.append(self.lines[i].strip())
            i += 1
        text = " ".join(parts)
        text = re.sub(r"^recap:\s*", "", text, flags=re.I)
        self.blocks.append(("recap", text))
        return i

    def _collect_output(self, i):
        """Collect ⎿ lines and their deeper-indented continuation."""
        out = []
        n = len(self.lines)
        while i < n:
            line = self.lines[i]
            if m := OUTPUT_RE.match(line):
                out.append(m.group(1))
            elif line.strip() and indent_of(line) >= 5 and not self.is_top(line):
                out.append(line[5:] if line[:5].isspace() else line.strip())
            elif not line.strip():
                j = i + 1
                while j < n and not self.lines[j].strip():
                    j += 1
                nxt = self.lines[j] if j < n else ""
                if nxt and indent_of(nxt) >= 5 and not self.is_top(nxt):
                    out.append("")
                else:
                    break
            else:
                break
            i += 1
        return [EXPAND_HINT_RE.sub("", l).rstrip() for l in out], i

    def _parse_output(self, i, owner):
        out, i = self._collect_output(i)
        self.blocks.append(("output", owner, out))
        return i

    def _parse_tool(self, i):
        m = TOOL_RE.match(self.lines[i])
        name, header = m.group(1), [m.group(2)]
        j = i + 1
        while j < len(self.lines):
            line = self.lines[j]
            if not line.strip() or OUTPUT_RE.match(line) or self.is_top(line) or indent_of(line) < 4:
                break
            header.append(line[6:] if line[:6].isspace() else line.strip())
            j += 1
        args = "\n".join(header).rstrip()
        if not (args.endswith(")") or args.endswith("…)")):
            return self._parse_prose(i)  # "● Foo(bar) is prose", not a call
        args = args[:-1].rstrip("…").rstrip() if args.endswith(")") else args
        output, j = self._collect_output(j)
        self.blocks.append(("tool", name, args, output))
        return j

    def _parse_prose(self, i):
        first = self.lines[i]
        m = ASSIST_RE.match(first)
        raw, body = [first], ["  " + m.group(1) if m else first]
        i += 1
        n = len(self.lines)
        while i < n:
            line = self.lines[i]
            if self.is_top(line) or OUTPUT_RE.match(line) or COLLAPSED_RE.match(line):
                break
            if not line.strip():
                j = i + 1
                while j < n and not self.lines[j].strip():
                    j += 1
                nxt = self.lines[j] if j < n else ""
                if not nxt or self.is_top(nxt) or OUTPUT_RE.match(nxt) or COLLAPSED_RE.match(nxt):
                    break
            if line.strip() and indent_of(line) == 0:
                line = "  " + line  # col-0 wrap of a ● notification line
            raw.append(line)
            body.append(line)
            i += 1
        lines = [l[2:] if l.startswith("  ") else l.lstrip() for l in body]
        self.blocks.append(("prose", lines, [len(r.rstrip()) for r in raw]))
        if i < n and OUTPUT_RE.match(self.lines[i]):
            i = self._parse_output(i, owner=lines[0] if lines else "")
        return i


# ---------------------------------------------------------------- reflow


def first_word(line):
    parts = line.split()
    return parts[0] if parts else ""


def starts_block(line):
    s = line.strip()
    return (
        not s
        or bool(LIST_RE.match(line))
        or bool(RECORD_KEY_RE.match(line))
        or BOX_RE.match(line) is not None
        or RULE_RE.match(line) is not None
        or INSIGHT_RE.match(line) is not None
        or s.startswith(("|", "```", "#", ">"))
    )


def unwrap(raw, text, width, raw_lens=None, lower_join=False):
    """Join soft-wrapped lines.

    A break is soft when the next line's first word would not have fit
    on the current line, i.e. the terminal was forced to wrap there.
    With `lower_join`, a line that starts lowercase also continues an
    unpunctuated, non-code previous line (narrow table-cell wraps).
    `raw` are the on-screen lines (for width), `text` the content lines.
    """
    lens = raw_lens or [len(r.rstrip()) for r in raw]
    out = []
    for k, line in enumerate(text):
        line = line.rstrip()
        if out and k > 0 and line.strip() and out[-1].strip():
            prev_len = lens[k - 1]
            fits = prev_len + 1 + len(first_word(line)) <= width
            soft = prev_len <= width and not fits
            lower = (
                lower_join
                and line.lstrip()[:1].islower()
                and out[-1].rstrip()[-1:] not in ".:;!?"
                and not CODEY_RE.search(out[-1])
                and not CODEY_RE.search(line)
            )
            if (soft or lower) and not starts_block(line) \
                    and not DIAGRAM_RE.search(out[-1]) and not DIAGRAM_RE.search(line):
                out[-1] = out[-1] + " " + line.strip()
                continue
        out.append(line)
    return out


# ---------------------------------------------------------------- rendering


def fence(body, lang=""):
    tick = "````" if "```" in body else "```"
    return f"{tick}{lang}\n{body}\n{tick}"


def box_table(lines):
    rows, cur = [], None
    for l in lines:
        s = l.strip()
        if s[:1] in "┌├└":
            if cur:
                rows.append(cur)
            cur = None
        elif s.startswith("│"):
            cells = [c.strip() for c in s.strip("│").split("│")]
            if cur is None:
                cur = cells
            else:
                for k, c in enumerate(cells):
                    if c and k < len(cur):
                        cur[k] = f"{cur[k]} {c}".strip()
    if cur:
        rows.append(cur)
    if not rows:
        return ""
    ncol = max(len(r) for r in rows)
    rows = [[c.replace("|", "\\|") for c in r] + [""] * (ncol - len(r)) for r in rows]
    md = ["| " + " | ".join(rows[0]) + " |", "|" + "---|" * ncol]
    md += ["| " + " | ".join(r) + " |" for r in rows[1:]]
    return "\n".join(md)


def is_heading(para, has_next):
    if len(para) != 1 or not has_next:
        return False
    s = para[0].strip()
    return (
        0 < len(s) <= 60
        and indent_of(para[0]) == 0
        and s[0].isupper()
        and s[-1] not in ".:,;!?)…—-"
        and not LIST_RE.match(para[0])
        and "`" not in s
    )


def render_paragraph(para):
    if len(para) > 1 and sum(bool(DIAGRAM_RE.search(l)) for l in para) / len(para) >= 0.25:
        return fence("\n".join(para))
    if any(LIST_RE.match(l) for l in para):
        return "\n".join(para)
    if len(para) > 1 and sum(bool(CODEY_RE.search(l)) for l in para) / len(para) >= 0.6:
        return fence("\n".join(para))
    return "  \n".join(l.strip() if k else l for k, l in enumerate(para))


def render_prose(lines, lens, width):
    """Render dedented assistant lines. `lens` are the on-screen widths."""
    segs, k, n = [], 0, len(lines)
    text, text_lens = [], []

    def flush():
        if text:
            segs.append(("text", unwrap(None, text, width, list(text_lens), lower_join=True)))
            text.clear()
            text_lens.clear()

    while k < n:
        line = lines[k]
        if QUOTE_RE.match(line):
            # Rendered markdown blockquote: unwrap content, keep on-screen widths.
            flush()
            j = k
            while j < n and (QUOTE_RE.match(lines[j]) or (
                    not lines[j].strip() and j + 1 < n and QUOTE_RE.match(lines[j + 1]))):
                j += 1
            inner = [QUOTE_RE.sub("", l) for l in lines[k:j]]
            body = render_prose(inner, lens[k:j], width)
            segs.append(("raw", "\n".join(f"> {l}" if l else ">" for l in body.splitlines())))
            k = j
        elif TABLE_TOP_RE.match(line):
            flush()
            j = k
            while j < n and BOX_RE.match(lines[j]):
                j += 1
            segs.append(("table", box_table(lines[k:j])))
            k = j
        elif INSIGHT_RE.match(line):
            flush()
            j = k + 1
            while j < n and not RULE_RE.match(lines[j]):
                j += 1
            inner = render_prose(lines[k + 1:j], lens[k + 1:j], width)
            title = re.sub(r"─+", "", line).strip()
            quoted = "\n".join(f"> {l}" if l else ">" for l in inner.splitlines())
            segs.append(("raw", f"> **{title}**\n>\n{quoted}"))
            k = j + 1
        elif RULE_RE.match(line):
            flush()
            segs.append(("raw", "---"))
            k += 1
        else:
            text.append(line)
            text_lens.append(lens[k] if k < len(lens) else len(line) + 2)
            k += 1
    flush()

    out = []
    for kind, val in segs:
        if kind != "text":
            out.append(val)
            continue
        paras, cur = [], []
        for l in val:
            if l.strip():
                cur.append(l)
            elif cur:
                paras.append(cur)
                cur = []
        if cur:
            paras.append(cur)
        for p_i, para in enumerate(paras):
            if is_heading(para, p_i + 1 < len(paras)):
                out.append(f"#### {para[0].strip()}")
            else:
                out.append(render_paragraph(para))
    return "\n\n".join(o for o in out if o)


def summary_text(name, args):
    first = args.splitlines()[0] if args else ""
    if len(first) > 90:
        first = first[:87] + "…"
    return f"<code>{html.escape(name)}</code> {html.escape(first)}".rstrip()


def render_tool(name, args, output, mode):
    if mode == "none":
        return ""
    if mode == "brief":
        head = args.splitlines()[0] if args else ""
        result = next((o for o in output if o.strip()), "")
        line = f"- `{name}({head})`"
        return line + (f" → {result.strip()}" if result else "")
    parts = ["<details>", f"<summary>{summary_text(name, args)}</summary>", ""]
    if args and ("\n" in args or name in FENCE_LANG):
        parts += [fence(args, FENCE_LANG.get(name, "")), ""]
    if output:
        parts += [fence("\n".join(output).strip("\n")), ""]
    parts.append("</details>")
    return "\n".join(parts)


def render_answers(output):
    items, cur = [], None
    for l in output:
        s = l.strip()
        if s.startswith("·"):
            cur = s.lstrip("· ").strip()
            items.append(cur)
        elif s and items:
            items[-1] += " " + s
    md = []
    for it in items:
        q, _, a = it.partition(" → ")
        md.append(f"- **{q.strip()}** → {a.strip()}" if a else f"- {it}")
    return "\n".join(md)


def render(blocks, meta, width, tools="full", title=None):
    body, in_claude = [], False
    for b in blocks:
        kind = b[0]
        if kind == "user":
            in_claude = False
            text = "\n".join(b[1]).strip("\n")
            body.append("## User\n\n" + "\n".join(f"> {l}" if l.strip() else ">" for l in text.splitlines()))
            continue
        if kind == "recap":
            body.append(f"> **Recap:** {b[1]}")
            continue
        chunk = ""
        if kind == "prose":
            chunk = render_prose(b[1], b[2], width)
        elif kind == "tool":
            chunk = render_tool(b[1], b[2], b[3], tools)
        elif kind == "note":
            chunk = f"*{b[1]}*" if tools != "none" else ""
        elif kind == "output":
            owner, output = b[1], b[2]
            if owner and owner.startswith("User answered"):
                chunk = render_answers(output)
            elif len([o for o in output if o.strip()]) == 1 and tools != "none":
                chunk = "*" + next(o for o in output if o.strip()).strip() + "*"
            elif tools == "full":
                chunk = fence("\n".join(output).strip("\n"))
            elif tools == "brief" and output:
                chunk = "*" + output[0].strip() + "*"
        if not chunk:
            continue
        if not in_claude:
            body.append("## Claude")
            in_claude = True
        body.append(chunk)

    prompts = [b[1] for b in blocks if b[0] == "user"]
    bare_cmd = re.compile(r"^\s*[/!]\S*\s*$")
    first_user = next((p for p in prompts if not bare_cmd.match(" ".join(p))), prompts[0] if prompts else [""])
    title = title or " ".join(" ".join(first_user).split())[:80] or "Claude Code session"
    fm = ["---", f"title: {json.dumps(title, ensure_ascii=False)}"]
    for key in ("date", "claude_code_version", "model", "cwd", "source"):
        if key in meta:
            fm.append(f"{key}: {json.dumps(meta[key], ensure_ascii=False)}")
    fm.append("---")
    return "\n".join(fm) + "\n\n" + "\n\n".join(body).rstrip() + "\n"


def convert(text, source_name=None, tools="full", width=None, title=None):
    p = Parser(text.splitlines())
    if width:
        p.width = width
    blocks = p.parse()
    meta = dict(p.meta)
    if source_name:
        meta["source"] = source_name
        if m := DATE_RE.match(Path(source_name).name):
            meta["date"] = m.group(1) + (f"T{m.group(2)}:{m.group(3)}:{m.group(4)}" if m.group(2) else "")
    return render(blocks, meta, p.width, tools=tools, title=title)


# ---------------------------------------------------------------- CLI


def main():
    ap = argparse.ArgumentParser(
        description="Convert Claude Code /export .txt transcripts to clean Markdown."
    )
    ap.add_argument("inputs", nargs="+", help="export .txt file(s), or - for stdin")
    ap.add_argument("-o", "--output", help="output file (single input only); - for stdout")
    ap.add_argument("-d", "--out-dir", help="directory for output files (default: beside input)")
    ap.add_argument("--tools", choices=["full", "brief", "none"], default="full",
                    help="tool calls as collapsible blocks, one-liners, or omitted (default: full)")
    ap.add_argument("--width", type=int, help="terminal width the export was taken at (default: auto)")
    ap.add_argument("--title", help="override the document title")
    args = ap.parse_args()

    if args.output and len(args.inputs) > 1:
        ap.error("--output takes a single input; use --out-dir for batches")

    for src in args.inputs:
        if src == "-":
            text, name = sys.stdin.read(), None
        else:
            path = Path(src)
            if not path.is_file():
                print(f"skip: {src} not found", file=sys.stderr)
                continue
            text, name = path.read_text(encoding="utf-8", errors="replace"), path.name

        md = convert(text, name, tools=args.tools, width=args.width, title=args.title)

        if args.output == "-" or (src == "-" and not args.output):
            sys.stdout.write(md)
            continue
        if args.output:
            dest = Path(args.output)
        else:
            base = Path(src).with_suffix(".md")
            dest = Path(args.out_dir) / base.name if args.out_dir else base
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(md, encoding="utf-8")
        print(f"{src} -> {dest}", file=sys.stderr)


if __name__ == "__main__":
    main()
