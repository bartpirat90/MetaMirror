# -*- coding: utf-8 -*-
"""Erhoeht die Patch-Stelle der Addon-Version in der .toc und gibt sie auf stdout aus.

Hintergrund: CurseForge benennt jede hochgeladene Datei nach der .toc-Version
(MetaMirror-0.9.1.zip). Bliebe die Version bei jedem woechentlichen Daten-Refresh
gleich, haetten alle Uploads denselben Dateinamen und waeren in der Dateiliste nicht
auseinanderzuhalten. Der CI-Lauf ruft dieses Modul darum genau dann auf, wenn sich
Daten geaendert haben, und committet die neue .toc zusammen mit den Daten.

Schema: MAJOR.MINOR.PATCH -- PATCH = automatischer Daten-Refresh (dieses Modul),
MINOR/MAJOR werden bei Code-Aenderungen von Hand erhoeht.

    python -m pipeline.bump_version               # MetaMirror.toc, +1 Patch
    python -m pipeline.bump_version --dry-run     # nur die neue Version zeigen
"""
import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOC = os.path.join(REPO, "MetaMirror.toc")

# "## Version: 0.9.1" -- Praefix und Wert getrennt, damit nur der Wert ersetzt wird.
VERSION_RE = re.compile(r"^(##\s*Version:\s*)(\S+)\s*$", re.IGNORECASE)


def next_version(version):
    """'0.9.0' -> '0.9.1', '0.9' -> '0.9.1', '0.9.9' -> '0.9.10'.

    Eine zweistellige Version wird auf drei Stellen ergaenzt; alles hinter der dritten
    Stelle faellt weg. Nicht-numerische Versionen sind ein Fehler (lieber laut
    scheitern, als im CI eine kaputte Version zu committen)."""
    parts = str(version).strip().split(".")
    if not 1 <= len(parts) <= 4 or not all(p.isdigit() for p in parts[:3]):
        raise ValueError("Version nicht im Format MAJOR.MINOR.PATCH: " + repr(version))
    nums = [int(p) for p in parts[:3]] + [0] * (3 - len(parts[:3]))
    nums[2] += 1
    return "{}.{}.{}".format(*nums)


def bump_toc(path=TOC, dry_run=False):
    """Erhoeht die Version in der .toc und liefert (alt, neu). Zeilenenden bleiben
    erhalten (newline=''), damit die Datei im CI nicht komplett als geaendert gilt."""
    with open(path, encoding="utf-8", newline="") as f:
        text = f.read()

    old = None
    out = []
    for line in text.splitlines(keepends=True):
        m = VERSION_RE.match(line.rstrip("\r\n"))
        if m and old is None:
            old = m.group(2)
            new = next_version(old)
            eol = line[len(line.rstrip("\r\n")):]
            line = m.group(1) + new + eol
        out.append(line)

    if old is None:
        raise ValueError("Keine '## Version:'-Zeile in " + path)

    if not dry_run:
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write("".join(out))
    return old, next_version(old)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--toc", default=TOC)
    ap.add_argument("--dry-run", action="store_true", help="nichts schreiben, nur ausgeben")
    args = ap.parse_args(argv)

    old, new = bump_toc(args.toc, dry_run=args.dry_run)
    print(new)                                   # stdout = nur die Version (fuer die CI)
    print("{} -> {}".format(old, new), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
