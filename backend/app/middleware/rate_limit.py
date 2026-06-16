from __future__ import annotations

import time
from typing import Callable

from jose import JWTError, jwt
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from starlette.types import ASGIApp

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

# One sliding window: 60 seconds
_WINDOW = 60

_AUTH_PREFIX = "/api/v1/auth/"
_LOGIN_PATH = "/api/v1/auth/login"
_LOGIN_LIMIT = 10  # attempts per minute per IP


class PerUserRateLimitMiddleware(BaseHTTPMiddleware):
    """
    Applies a sliding-window rate limit keyed by authenticated user ID.
    Falls back to IP address when no valid JWT is present.

    Only applies to /api/ routes, excluding auth endpoints which are
    already guarded by Nginx's auth_limit zone (10 req/min per IP).

    Fails open: if Redis is unavailable, requests pass through normally.
    """

    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        if not settings.RATE_LIMIT_ENABLED:
            return await call_next(request)

        path = request.url.path

        # Apply a strict per-IP limit on the login endpoint regardless of Nginx
        if path == _LOGIN_PATH:
            try:
                from app.db.redis import get_redis_pool
                redis = await get_redis_pool()
                ip = self._get_real_ip(request)
                exceeded = await self._sliding_window(redis, f"rl:login:{ip}", _LOGIN_LIMIT, _WINDOW)
                if exceeded:
                    return JSONResponse(
                        status_code=429,
                        content={
                            "success": False,
                            "error": {
                                "code": "RATE_LIMIT_EXCEEDED",
                                "message": "Too many login attempts. Please wait a minute and try again.",
                                "details": {"retry_after_seconds": _WINDOW},
                            },
                        },
                        headers={"Retry-After": str(_WINDOW)},
                    )
            except Exception:
                pass  # fail-open so a Redis outage never blocks legitimate logins
            return await call_next(request)

        # Skip remaining auth paths (register handled by its own helper)
        if not path.startswith("/api/") or path.startswith(_AUTH_PREFIX):
            return await call_next(request)

        # Obtain Redis — fail open if unavailable so Redis outage never blocks users
        try:
            from app.db.redis import get_redis_pool
            redis = await get_redis_pool()
        except Exception:
            return await call_next(request)

        identity, is_user = self._resolve_identity(request)
        key = f"rl:{'user' if is_user else 'ip'}:{identity}"
        limit = settings.RATE_LIMIT_REQUESTS_PER_MINUTE

        try:
            exceeded = await self._sliding_window(redis, key, limit, _WINDOW)
        except Exception:
            # Redis error: fail open
            return await call_next(request)

        if exceeded:
            logger.warning(
                "rate_limit_exceeded",
                identity_type="user" if is_user else "ip",
                identity=identity,
                path=path,
            )
            return JSONResponse(
                status_code=429,
                content={
                    "success": False,
                    "error": {
                        "code": "RATE_LIMIT_EXCEEDED",
                        "message": "Too many requests. Please slow down and try again.",
                        "details": {"retry_after_seconds": _WINDOW},
                    },
                },
                headers={"Retry-After": str(_WINDOW)},
            )

        return await call_next(request)

    def _get_real_ip(self, request: Request) -> str:
        """Return the real client IP, trusting X-Forwarded-For only when configured."""
        if settings.TRUST_PROXY_HEADERS:
            forwarded = request.headers.get("X-Forwarded-For", "")
            if forwarded:
                return forwarded.split(",")[0].strip()
        return request.client.host if request.client else "unknown"

    def _resolve_identity(self, request: Request) -> tuple[str, bool]:
        """Return (identity_key, is_authenticated_user).

        Verifies JWT signature to prevent identity spoofing, but skips
        expiry check — the route handler already enforces that, and we
        don't want a just-expired token to silently fall back to IP limiting.
        """
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth[7:]
            try:
                payload = jwt.decode(
                    token,
                    settings.JWT_SECRET_KEY,
                    algorithms=[settings.JWT_ALGORITHM],
                    audience=settings.JWT_AUDIENCE,
                    issuer=settings.JWT_ISSUER,
                    options={"verify_exp": False},
                )
                sub = payload.get("sub")
                if sub:
                    return sub, True
            except JWTError:
                pass  # invalid signature → fall through to IP

        return self._get_real_ip(request), False

    @staticmethod
    async def _sliding_window(redis, key: str, limit: int, window: int) -> bool:
        """Sliding-window counter using a Redis sorted set. Returns True if over limit."""
        now = int(time.time())
        pipe = redis.pipeline()
        pipe.zremrangebyscore(key, 0, now - window)
        pipe.zadd(key, {f"{now}:{time.monotonic_ns()}": now})
        pipe.zcard(key)
        pipe.expire(key, window + 1)
        results = await pipe.execute()
        count = results[2]
        return count > limit
