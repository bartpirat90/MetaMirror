#!/usr/bin/env bash
# Kopiert MetaMirror in den WoW-AddOns-Ordner.
#
# Kopiert wird nur, was das Addon zur Laufzeit braucht: die .toc, die Lua-Dateien
# der obersten Ebene, Data/ und die beiden TGA-Texturen. pipeline/, docs/, tests/,
# release/ und alles Ordnerfremde bleiben draussen -- wie beim Release-ZIP.
#
# Vorher werden im Ziel alle *.lua/*.toc geloescht, damit keine Datei liegen
# bleibt, die es in der Quelle nicht mehr gibt.
#
# Aufruf:  bash scripts/deploy.sh [--dry-run]
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="/d/Battle.net/World of Warcraft/_retail_/Interface/AddOns/MetaMirror"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

# Der AddOns-Ordner muss existieren. Wenn nicht, stimmt der Pfad nicht -- dann
# lieber abbrechen, als ein Addon irgendwohin zu legen, wo WoW es nie sieht.
ADDONS="$(dirname "$TARGET")"
if [ ! -d "$ADDONS" ]; then
  echo "FEHLER: AddOns-Ordner nicht gefunden: $ADDONS" >&2
  echo "Pfad in scripts/deploy.sh anpassen." >&2
  exit 1
fi

# Syntaxpruefung vor dem Kopieren: ein Tippfehler im Lua soll im Terminal
# auffallen, nicht erst beim Login.
( cd "$SRC" && luac -p ./*.lua Data/*.lua )
echo "Lua-Syntax OK"

VERSION="$(grep -m1 '^## Version:' "$SRC/MetaMirror.toc" | sed 's/^## Version:[[:space:]]*//')"

if [ "$DRY" = "1" ]; then
  echo "--dry-run: wuerde Version $VERSION kopieren nach:"
  echo "  $TARGET"
  echo "Dateien:"
  ( cd "$SRC" && ls ./*.toc ./*.lua ./*.tga Data/*.lua | sed 's/^/  /' )
  exit 0
fi

mkdir -p "$TARGET/Data"
rm -f "$TARGET"/*.lua "$TARGET"/*.toc "$TARGET"/Data/*.lua

cp "$SRC"/*.toc "$SRC"/*.lua "$SRC"/*.tga "$TARGET"/
cp "$SRC"/Data/*.lua "$TARGET"/Data/

echo "deployed $VERSION -> $TARGET"
echo "In WoW: /reload (oder neu einloggen), dann /mm"
