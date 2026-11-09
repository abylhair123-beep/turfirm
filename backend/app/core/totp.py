import base64
import hashlib
import hmac
import secrets
import struct
import time
import urllib.parse
from typing import List, Optional


def generate_totp_secret(length: int = 20) -> str:
    """Генерирует криптографически стойкий 160-битный base32-секрет для TOTP (Google Authenticator)."""
    random_bytes = secrets.token_bytes(length)
    return base64.b32encode(random_bytes).decode("utf-8").rstrip("=")


def get_totp_uri(secret: str, account_name: str, issuer: str = "Sapar") -> str:
    """Генерирует URI по стандарту keyuri (otpauth://totp/...) для QR-кода."""
    clean_secret = secret.strip().replace(" ", "").upper()
    params = {
        "secret": clean_secret,
        "issuer": issuer,
        "algorithm": "SHA1",
        "digits": 6,
        "period": 30,
    }
    label = f"{urllib.parse.quote(issuer)}:{urllib.parse.quote(account_name)}"
    return f"otpauth://totp/{label}?{urllib.parse.urlencode(params)}"


def get_totp_code(secret: str, for_time: Optional[int] = None, interval: int = 30) -> str:
    """Вычисляет 6-значный TOTP код на заданный момент времени (RFC 6238)."""
    if for_time is None:
        for_time = int(time.time())
    counter = int(for_time // interval)

    clean_secret = secret.strip().replace(" ", "").upper()
    missing_padding = len(clean_secret) % 8
    if missing_padding != 0:
        clean_secret += "=" * (8 - missing_padding)

    key = base64.b32decode(clean_secret, casefold=True)
    msg = struct.pack(">Q", counter)
    h = hmac.new(key, msg, hashlib.sha1).digest()
    offset = h[-1] & 0x0F
    code_int = struct.unpack(">I", h[offset : offset + 4])[0] & 0x7FFFFFFF
    code = code_int % 1000000
    return f"{code:06d}"


def verify_totp_code(secret: str, code: str, window: int = 1, interval: int = 30) -> bool:
    """Проверяет 6-значный код с допуском отклонения по времени (+- window интервалов по 30 сек)."""
    if not secret or not code:
        return False
    clean_code = str(code).strip()
    if not clean_code.isdigit() or len(clean_code) != 6:
        return False

    current_time = int(time.time())
    for offset in range(-window, window + 1):
        check_time = current_time + (offset * interval)
        expected_code = get_totp_code(secret, check_time, interval)
        if hmac.compare_digest(clean_code, expected_code):
            return True
    return False


def generate_backup_codes(count: int = 8) -> List[str]:
    """Генерирует одноразовые 8-значные резервные коды восстановления."""
    return [f"{secrets.randbelow(90000000) + 10000000}" for _ in range(count)]
