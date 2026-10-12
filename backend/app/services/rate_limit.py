"""Redis-backed gates for notification anti-spam.

Two primitives:

- `acquire(key, ttl_seconds)` — TTL gate. First call within the window
  returns True; subsequent calls return False until the key expires.
  Used to enforce "max 1 notification per key per N seconds".

- `should_emit_change(key, value, ttl_seconds)` — debounce helper.
  Returns True only if the cached value for `key` differs from the
  new `value`. Used to suppress flapping printer status updates.

All operations are best-effort: if Redis is unreachable, they fail OPEN
(return True / emit) so notifications still fire. We never want
anti-spam to silently swallow critical alerts because the cache is down.
"""

from __future__ import annotations

import logging
from typing import Optional

import redis

from app.core.config import settings

logger = logging.getLogger(__name__)

_KEY_PREFIX = "notif:rl:"
_DEBOUNCE_PREFIX = "notif:dbnc:"

_client: Optional[redis.Redis] = None


def _get_client() -> Optional[redis.Redis]:
    """Lazy sync client. Returns None if Redis can't be reached so callers
    fail open.
    """
    global _client
    if _client is not None:
        return _client
    try:
        _client = redis.Redis.from_url(
            settings.REDIS_URL,
            socket_connect_timeout=1,
            socket_timeout=1,
            decode_responses=True,
        )
        _client.ping()
        return _client
    except Exception:
        logger.warning("rate-limit redis unavailable; failing open", exc_info=True)
        _client = None
        return None


def acquire(key: str, ttl_seconds: int) -> bool:
    """Return True if this is the first call for `key` within `ttl_seconds`.

    Uses `SET key 1 NX EX ttl` — atomic single round-trip.
    """
    if not key or ttl_seconds <= 0:
        return True
    client = _get_client()
    if client is None:
        return True
    try:
        result = client.set(f"{_KEY_PREFIX}{key}", "1", nx=True, ex=ttl_seconds)
        return bool(result)
    except Exception:
        logger.warning("rate-limit acquire failed for key=%s", key, exc_info=True)
        return True


def should_emit_change(key: str, value: str, ttl_seconds: int = 86400) -> bool:
    """Debounce helper.

    Compares the new `value` against the cached one. Returns True when:
    - cache miss (first observation), OR
    - cached value differs from `value` (state actually changed).

    Caller passes the *current* status string (e.g. "online" / "offline").
    Flapping events with the same status are silently dropped.
    """
    if not key:
        return True
    client = _get_client()
    if client is None:
        return True
    try:
        full_key = f"{_DEBOUNCE_PREFIX}{key}"
        prior = client.get(full_key)
        if prior == value:
            return False
        client.set(full_key, value, ex=ttl_seconds)
        return True
    except Exception:
        logger.warning("debounce check failed for key=%s", key, exc_info=True)
        return True


def reset(key: str) -> None:
    """Manually clear a rate-limit / debounce key. Useful in tests."""
    client = _get_client()
    if client is None:
        return
    try:
        client.delete(f"{_KEY_PREFIX}{key}", f"{_DEBOUNCE_PREFIX}{key}")
    except Exception:
        pass
