import json
import logging
import re
from typing import Any
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger("sapar.security")

# Регулярные выражения для обнаружения и нейтрализации опасных XSS инъекций
DANGEROUS_XSS_PATTERNS = [
    re.compile(r"<\s*script[^>]*>.*?<\s*/\s*script\s*>", re.IGNORECASE | re.DOTALL),
    re.compile(r"<\s*script[^>]*>", re.IGNORECASE),
    re.compile(r"<\s*/\s*script\s*>", re.IGNORECASE),
    re.compile(r"javascript\s*:", re.IGNORECASE),
    re.compile(r"vbscript\s*:", re.IGNORECASE),
    re.compile(r"data\s*:\s*text/html", re.IGNORECASE),
    re.compile(r"on\w+\s*=\s*[\"'][^\"']*[\"']", re.IGNORECASE),
    re.compile(r"on\w+\s*=\s*[^>\s]+", re.IGNORECASE),
]


def sanitize_input_value(val: Any) -> Any:
    """Рекурсивно санитизирует строки, удаляя вредоносные XSS-фрагменты."""
    if isinstance(val, str):
        cleaned = val
        for pattern in DANGEROUS_XSS_PATTERNS:
            if pattern.search(cleaned):
                logger.warning(f"[SECURITY] XSS payload detected and stripped from input: {cleaned[:80]}")
                cleaned = pattern.sub("", cleaned)
        return cleaned
    elif isinstance(val, dict):
        return {k: sanitize_input_value(v) for k, v in val.items()}
    elif isinstance(val, list):
        return [sanitize_input_value(item) for item in val]
    return val


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Добавляет стандартизированные защитные HTTP-заголовки (OWASP / CIS)."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        response = await call_next(request)

        # HSTS (HTTP Strict Transport Security - 1 год с поддоменами)
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"

        # Защита от MIME-sniffing
        response.headers["X-Content-Type-Options"] = "nosniff"

        # Защита от Clickjacking
        response.headers["X-Frame-Options"] = "DENY"

        # Встроенный XSS фильтр браузера
        response.headers["X-XSS-Protection"] = "1; mode=block"

        # Управление утечкой Referrer
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

        # Content Security Policy (базовый профиль защиты)
        response.headers["Content-Security-Policy"] = (
            "default-src 'self' 'unsafe-inline' 'unsafe-eval' https: data: blob:;"
        )

        # Ограничение доступа к аппаратным API
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=(self)"

        return response


class InputSanitizationMiddleware(BaseHTTPMiddleware):
    """Проверяет входящие JSON-запросы на наличие XSS-пейлоадов и санитизирует тело."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        if request.method in ("POST", "PUT", "PATCH"):
            content_type = request.headers.get("content-type", "")
            if "application/json" in content_type:
                try:
                    body_bytes = await request.body()
                    if body_bytes:
                        json_data = json.loads(body_bytes.decode("utf-8"))
                        sanitized_data = sanitize_input_value(json_data)
                        new_body = json.dumps(sanitized_data).encode("utf-8")

                        # Обновляем кэш тела Starlette и подменяем поток чтения
                        request._body = new_body

                        async def receive():
                            return {"type": "http.request", "body": new_body, "more_body": False}

                        request._receive = receive
                except Exception as e:
                    logger.debug(f"Input sanitization skipped (non-json or empty): {e}")

        return await call_next(request)
