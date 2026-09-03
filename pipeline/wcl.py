import time
import httpx

TOKEN_URL = "https://www.warcraftlogs.com/oauth/token"
API_URL = "https://www.warcraftlogs.com/api/v2/client"

RATE_LIMIT_QUERY = "query { rateLimitData { limitPerHour pointsSpentThisHour pointsResetIn } }"
# Puffer nach pointsResetIn: im Live-Lauf 2026-09-02 kamen direkt nach einer Pause von
# pointsResetIn+5 s noch 429er (Fenster serverseitig noch nicht zurueckgesetzt).
RESET_MARGIN_S = 30


class WclClient:
    def __init__(
        self, client_id, client_secret, transport=None, max_retries=5,
        reserve_points=150, check_every=25, log=print,
    ):
        self._id = client_id
        self._secret = client_secret
        self._max_retries = max_retries
        self._reserve_points = reserve_points
        self._check_every = check_every
        self._log = log
        self._query_count = 0
        self._client = httpx.Client(timeout=60.0, transport=transport)
        self._token = None
        self._token_exp = 0.0

    def _ensure_token(self):
        if self._token and time.monotonic() < self._token_exp - 60:
            return
        r = self._client.post(
            TOKEN_URL, data={"grant_type": "client_credentials"},
            auth=(self._id, self._secret),
        )
        r.raise_for_status()
        body = r.json()
        self._token = body["access_token"]
        self._token_exp = time.monotonic() + float(body.get("expires_in", 3600))

    def rate_limit(self):
        """Fragt das WCL-Stundenkontingent ab (kostet selbst kaum Punkte).

        Nutzt dieselbe Token-/Transport-Logik wie query(), aber OHNE die
        Pausier-Logik aus query() (sonst Rekursion).
        """
        self._ensure_token()
        r = self._client.post(
            API_URL, headers={"Authorization": f"Bearer {self._token}"},
            json={"query": RATE_LIMIT_QUERY, "variables": {}},
        )
        r.raise_for_status()
        body = r.json()
        data = (body.get("data") or {}).get("rateLimitData") or {}
        return {
            "limitPerHour": data.get("limitPerHour", 3600),
            "pointsSpentThisHour": data.get("pointsSpentThisHour", 0),
            "pointsResetIn": data.get("pointsResetIn", 0),
        }

    def _maybe_pause_for_quota(self, _sleep):
        """Prueft das Stundenkontingent und pausiert bis zum Reset, falls
        (fast) erschoepft. Scheitert die Abfrage selbst, wird sie ignoriert
        (kein Grund, den eigentlichen Query-Versuch zu verhindern)."""
        try:
            info = self.rate_limit()
        except Exception:
            return
        spent = info["pointsSpentThisHour"]
        limit = info["limitPerHour"]
        reset_in = info["pointsResetIn"]
        if spent + self._reserve_points >= limit:
            wait = reset_in + RESET_MARGIN_S
            self._log(
                f"WCL-Kontingent erschoepft ({spent}/{limit}) - "
                f"pausiere {wait} s bis zum Reset"
            )
            _sleep(wait)
            # Fenster ist nach der Pause neu - Zaehler danach ignorieren.

    def _wait_after_429(self, attempt):
        """Ermittelt die Wartezeit nach einer 429-Antwort ueber die
        rateLimitData-Abfrage; faellt bei Fehler oder pointsResetIn=0 auf
        60 * (attempt + 1) Sekunden zurueck."""
        reset_in = 0
        try:
            info = self.rate_limit()
            reset_in = info["pointsResetIn"]
        except Exception:
            reset_in = 0
        if reset_in:
            return reset_in + RESET_MARGIN_S
        return 60 * (attempt + 1)

    def query(self, gql, variables, _sleep=time.sleep):
        """Fuehrt eine GraphQL-Query aus; wirft RuntimeError bei GraphQL-'errors'."""
        if self._query_count % self._check_every == 0:
            self._maybe_pause_for_quota(_sleep)
        self._query_count += 1

        for attempt in range(self._max_retries):
            self._ensure_token()
            r = self._client.post(
                API_URL, headers={"Authorization": f"Bearer {self._token}"},
                json={"query": gql, "variables": variables},
            )
            if r.status_code == 429:
                _sleep(self._wait_after_429(attempt))
                continue
            r.raise_for_status()
            body = r.json()
            if body.get("errors"):
                raise RuntimeError("; ".join(e.get("message", "?") for e in body["errors"]))
            return body["data"]
        raise RuntimeError("WCL rate limit: retries exhausted")
