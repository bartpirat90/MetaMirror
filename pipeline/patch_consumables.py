"""Offline-Patch: ueberlagert die kuratierten Verbrauchsgueter (Food/Trank/Oel)
in einer bereits generierten Data/MetaMirrorData.lua, OHNE einen WCL-Abruf.

Die Pipeline (run.py -> aggregate.py) wendet apply_curated_consumables kuenftig
bei jeder Neugenerierung an; dieses Skript bringt denselben Stand in die aktuell
vorhandene Datei. Deterministisch und idempotent (mehrfaches Ausfuehren = No-Op).

Aufruf:  python -m pipeline.patch_consumables [Pfad]   (Default: Data/MetaMirrorData.lua)
"""
import re
import sys

from pipeline.season import apply_curated_consumables

# Spec-Kopf im generierten Lua: genau 12 Leerzeichen Einrueckung, z.B. "            [71] = {"
_SPEC_RE = re.compile(r"^ {12}\[(\d+)\] = \{")
_CONS_RE = re.compile(r"^(?P<indent> *)consumables = \{(?P<body>.*)\},\s*$")
_PAIR_RE = re.compile(r"(\w+)\s*=\s*(\d+)")


def _rewrite_line(indent, body, spec_id):
    cons = {k: int(v) for k, v in _PAIR_RE.findall(body)}
    cons = apply_curated_consumables(spec_id, cons)
    inner = ", ".join(f"{k} = {v}" for k, v in sorted(cons.items()))
    return f"{indent}consumables = {{ {inner} }},\n"


def patch_text(text):
    out, spec_id = [], None
    for line in text.splitlines(keepends=True):
        m = _SPEC_RE.match(line)
        if m:
            spec_id = int(m.group(1))
        c = _CONS_RE.match(line)
        if c and spec_id is not None:
            out.append(_rewrite_line(c.group("indent"), c.group("body"), spec_id))
        else:
            out.append(line)
    return "".join(out)


def main(argv=None):
    path = (argv or sys.argv[1:] or ["Data/MetaMirrorData.lua"])[0]
    with open(path, encoding="utf-8") as f:
        original = f.read()
    patched = patch_text(original)
    if patched == original:
        print(f"unveraendert (bereits kuratiert): {path}")
        return 0
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(patched)
    print(f"kuratiert -> {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
