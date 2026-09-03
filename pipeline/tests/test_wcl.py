import json
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


def test_rate_limit_query_returns_dict():
    def handler(request):
        if request.url.path == "/oauth/token":
            return httpx.Response(200, json={"access_token": "T", "expires_in": 3600})
        body = json.loads(request.content)
        assert "rateLimitData" in body["query"]
        return httpx.Response(200, json={"data": {"rateLimitData": {
            "limitPerHour": 3600, "pointsSpentThisHour": 42.5, "pointsResetIn": 1200,
        }}})
    c = WclClient("id", "secret", transport=httpx.MockTransport(handler))
    info = c.rate_limit()
    assert info == {"limitPerHour": 3600, "pointsSpentThisHour": 42.5, "pointsResetIn": 1200}


def test_query_pauses_when_quota_exhausted():
    sleeps = []
    logs = []

    def handler(request):
        if request.url.path == "/oauth/token":
            return httpx.Response(200, json={"access_token": "T", "expires_in": 3600})
        body = json.loads(request.content)
        if "rateLimitData" in body["query"]:
            return httpx.Response(200, json={"data": {"rateLimitData": {
                "limitPerHour": 3600, "pointsSpentThisHour": 3500, "pointsResetIn": 100,
            }}})
        return httpx.Response(200, json={"data": {"ok": True}})

    c = WclClient(
        "id", "secret", transport=httpx.MockTransport(handler),
        check_every=1, log=logs.append,
    )
    out = c.query("{ ok }", {}, _sleep=sleeps.append)
    assert out == {"ok": True}
    assert sleeps == [130]   # pointsResetIn 100 + RESET_MARGIN_S
    assert len(logs) == 1


def test_query_does_not_pause_below_reserve():
    sleeps = []

    def handler(request):
        if request.url.path == "/oauth/token":
            return httpx.Response(200, json={"access_token": "T", "expires_in": 3600})
        body = json.loads(request.content)
        if "rateLimitData" in body["query"]:
            return httpx.Response(200, json={"data": {"rateLimitData": {
                "limitPerHour": 3600, "pointsSpentThisHour": 1000, "pointsResetIn": 500,
            }}})
        return httpx.Response(200, json={"data": {"ok": True}})

    c = WclClient("id", "secret", transport=httpx.MockTransport(handler), check_every=1)
    out = c.query("{ ok }", {}, _sleep=sleeps.append)
    assert out == {"ok": True}
    assert sleeps == []


def test_check_every_limits_rate_limit_queries():
    rate_limit_calls = []

    def handler(request):
        if request.url.path == "/oauth/token":
            return httpx.Response(200, json={"access_token": "T", "expires_in": 3600})
        body = json.loads(request.content)
        if "rateLimitData" in body["query"]:
            rate_limit_calls.append(1)
            return httpx.Response(200, json={"data": {"rateLimitData": {
                "limitPerHour": 3600, "pointsSpentThisHour": 10, "pointsResetIn": 10,
            }}})
        return httpx.Response(200, json={"data": {"ok": True}})

    c = WclClient("id", "secret", transport=httpx.MockTransport(handler), check_every=3)
    for _ in range(6):
        c.query("{ ok }", {}, _sleep=lambda s: None)
    assert len(rate_limit_calls) <= 2


def test_429_waits_for_reset():
    sleeps = []
    state = {"data_calls": 0}

    def handler(request):
        if request.url.path == "/oauth/token":
            return httpx.Response(200, json={"access_token": "T", "expires_in": 3600})
        body = json.loads(request.content)
        if "rateLimitData" in body["query"]:
            return httpx.Response(200, json={"data": {"rateLimitData": {
                "limitPerHour": 3600, "pointsSpentThisHour": 0, "pointsResetIn": 30,
            }}})
        state["data_calls"] += 1
        if state["data_calls"] == 1:
            return httpx.Response(429)
        return httpx.Response(200, json={"data": {"ok": True}})

    c = WclClient("id", "secret", transport=httpx.MockTransport(handler), check_every=25)
    out = c.query("{ ok }", {}, _sleep=sleeps.append)
    assert out == {"ok": True}
    assert sleeps == [60]    # pointsResetIn 30 + RESET_MARGIN_S


def test_429_fallback_when_rate_limit_query_fails():
    sleeps = []
    state = {"data_calls": 0}

    def handler(request):
        if request.url.path == "/oauth/token":
            return httpx.Response(200, json={"access_token": "T", "expires_in": 3600})
        body = json.loads(request.content)
        if "rateLimitData" in body["query"]:
            return httpx.Response(500)
        state["data_calls"] += 1
        if state["data_calls"] == 1:
            return httpx.Response(429)
        return httpx.Response(200, json={"data": {"ok": True}})

    c = WclClient("id", "secret", transport=httpx.MockTransport(handler), check_every=25)
    out = c.query("{ ok }", {}, _sleep=sleeps.append)
    assert out == {"ok": True}
    assert sleeps == [60]
