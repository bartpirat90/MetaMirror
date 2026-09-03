# CurseForge-Upload / Auto-Update

MetaMirror kann sich selbst auf CurseForge veröffentlichen — manuell per Skript
oder vollautomatisch nach dem wöchentlichen Daten-Refresh (GitHub Actions).

Das Skript baut aus dem Repo ein sauberes Addon-ZIP (nur die in `MetaMirror.toc`
gelisteten Lua-Dateien + `Icon.tga` + `bar-mask.tga`, **niemals** Pipeline,
Secrets oder Screenshots) und lädt es über die CurseForge-Upload-API hoch.

---

## Einmalige Einrichtung

### 1. Projekt auf CurseForge anlegen
Der **allererste** Upload muss von Hand passieren, damit das Projekt existiert:
- „Create a Project" → World of Warcraft → Addon anlegen, `MetaMirror-0.9.zip` hochladen.
- Danach steht auf der Projektseite die **Project ID** (Zahl). Die brauchst du gleich.

### 2. API-Token erzeugen
CurseForge → Settings → **My API Tokens** → Namen vergeben → **Generate Token**.
Das Token ist ein **Geheimnis wie ein Passwort** — nicht committen, nicht teilen.

### 3a. Lokale Uploads (von deinem Rechner)
Trage Token + Project-ID in `pipeline/local_secrets.json` ein (ist gitignored):
```json
{
  "CURSEFORGE_TOKEN": "dein-token",
  "CURSEFORGE_PROJECT_ID": "123456"
}
```

### 3b. Automatische Uploads (GitHub Actions)
Im GitHub-Repo unter **Settings → Secrets and variables → Actions**:
- **Secret** `CURSEFORGE_TOKEN` = dein Token
- **Variable** `CURSEFORGE_PROJECT_ID` = deine Project-ID
- **Variable** `CF_PUBLISH` = `true`  ← der Schalter, der den Upload scharf stellt

Ist `CF_PUBLISH` nicht `true`, läuft der Upload-Schritt **nicht** — die Daten-Pipeline
selbst arbeitet unabhängig davon weiter.

---

## Nutzung

**Trockenlauf** (baut das ZIP, löst die Spielversion auf, lädt NICHT hoch):
```bash
python -m pipeline.cf_upload --dry-run
```

**Manuell veröffentlichen:**
```bash
python -m pipeline.cf_upload --release-type release --changelog "Was ist neu…"
```

Nützliche Optionen:
- `--release-type {release,beta,alpha}` (Standard: `release`)
- `--changelog "Text"` oder `--changelog-file pfad.md` (+ `--changelog-type markdown`)
- `--name "Anzeigename"` / `--append-date` (hängt das Datum an)
- `--game-version 12.1.0` oder `--game-version-id 1234` (falls die Auto-Erkennung
  aus der `## Interface`-Nummer mal nicht die richtige Spielversion trifft)

---

## Wie das Auto-Update läuft

`.github/workflows/update-data.yml` läuft jeden Montag (und per „Run workflow"):
1. Meta-Daten aus Warcraft Logs neu generieren, Lua-Syntax prüfen.
2. Nur bei **tatsächlicher Datenänderung** committen und pushen.
3. **Nur dann** — und nur wenn `CF_PUBLISH=true` — per `pipeline.cf_upload`
   automatisch eine neue Version auf CurseForge hochladen (mit Datum im Namen).

So bekommt CurseForge nach jedem echten Meta-Update automatisch eine frische
Version, ohne dass eine unveränderte Woche einen überflüssigen Upload erzeugt.

> Tipp: Für ein **Feature-Release** (neuer Code, nicht nur Daten) erhöhe die
> `## Version` in `MetaMirror.toc` und lade einmal manuell hoch bzw. stoße den
> Workflow an — der Anzeigename übernimmt die Version automatisch.
