import time
import httpx

TOKEN_URL = "https://www.warcraftlogs.com/oauth/token"
API_URL = "https://www.warcraftlogs.com/api/v2/client"


class WclClient:
    def __init__(self, client_id, client_secret, transport=None, max_retries=5):
        self._id = client_id
        self._secret = client_secret
        self._max_retries = max_retries
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

    def query(self, gql, variables, _sleep=time.sleep):
        """Fuehrt eine GraphQL-Query aus; wirft RuntimeError bei GraphQL-'errors'."""
        for attempt in range(self._max_retries):
            self._ensure_token()
            r = self._client.post(
                API_URL, headers={"Authorization": f"Bearer {self._token}"},
                json={"query": gql, "variables": variables},
            )
            if r.status_code == 429:
                _sleep(2 ** attempt)
                continue
            r.raise_for_status()
            body = r.json()
            if body.get("errors"):
                raise RuntimeError("; ".join(e.get("message", "?") for e in body["errors"]))
            return body["data"]
        raise RuntimeError("WCL rate limit: retries exhausted")
