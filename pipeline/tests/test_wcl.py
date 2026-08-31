import httpx
from pipeline.wcl import WclClient

TOKEN_URL = "https://www.warcraftlogs.com/oauth/token"
API_URL = "https://www.warcraftlogs.com/api/v2/client"


def _transport():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/oauth/token":
            return httpx.Response(200, json={"access_token": "TESTTOKEN", "expires_in": 3600})
        if request.url.path == "/api/v2/client":
            assert request.headers["authorization"] == "Bearer TESTTOKEN"
            return httpx.Response(200, json={"data": {"ok": True}})
        return httpx.Response(404)
    return httpx.MockTransport(handler)


def test_token_and_query():
    c = WclClient("id", "secret", transport=_transport())
    out = c.query("{ ok }", {})
    assert out == {"ok": True}


def test_graphql_errors_raise():
    def handler(request):
        if request.url.path == "/oauth/token":
            return httpx.Response(200, json={"access_token": "T", "expires_in": 3600})
        return httpx.Response(200, json={"errors": [{"message": "bad"}]})
    c = WclClient("id", "secret", transport=httpx.MockTransport(handler))
    try:
        c.query("{ x }", {})
        assert False, "should raise"
    except RuntimeError as e:
        assert "bad" in str(e)
