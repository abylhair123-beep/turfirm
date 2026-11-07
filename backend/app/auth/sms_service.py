import logging
import random
import re
from typing import Optional, Tuple
import httpx

from app.core.cache import cache
from app.core.config import settings

logger = logging.getLogger("app.sms")


def normalize_phone(raw_phone: str) -> str:
    """Нормализует номер телефона в формат +77XXXXXXXXX или +XXXXXXXXXXX."""
    digits = re.sub(r"\D", "", raw_phone)
    if digits.startswith("87") and len(digits) == 11:
        digits = "7" + digits[1:]
    elif digits.startswith("7") and len(digits) == 11:
        pass
    elif len(digits) == 10:
        digits = "7" + digits
    return f"+{digits}"


def generate_otp_code() -> str:
    """Генерация 4-значного числового одноразового пароля."""
    return f"{random.randint(1000, 9999)}"


async def send_sms_via_provider(phone: str, text: str) -> Tuple[bool, str]:
    """Отправка SMS через шлюз Mobizon / KazInfoTech / Twilio или локальный Mock."""
    provider = (settings.sms_provider or "mock").lower()

    # 1. Dev / Mock режим (вывод в консоль/лог)
    if provider == "mock" or not settings.sms_api_key:
        logger.info(f"📱 [SMS ШЛЮЗ (Mock)] Получатель: {phone} | Сообщение: '{text}'")
        return True, "Отправлено через Mock-шлюз"

    # 2. Mobizon Казахстан (api.mobizon.kz)
    if provider == "mobizon":
        url = settings.sms_api_url or "https://api.mobizon.kz/service/message/sendsmsmessage"
        params = {
            "output": "json",
            "api": "v1",
            "apiKey": settings.sms_api_key,
            "recipient": phone.lstrip("+"),
            "text": text,
        }
        if settings.sms_sender_name:
            params["from"] = settings.sms_sender_name
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                res = await client.post(url, params=params)
                data = res.json()
                if data.get("code") == 0:
                    return True, "SMS успешно отправлено через Mobizon"
                err_msg = data.get("message", "Ошибка Mobizon API")
                logger.error(f"Ошибка Mobizon SMS: {err_msg}")
                return False, err_msg
        except Exception as e:
            logger.error(f"Исключение при отправке через Mobizon: {e}")
            return False, str(e)

    # 3. KazInfoTech SMS Gateway
    if provider == "kazinfotech":
        url = settings.sms_api_url or "https://sms.kazinfotech.kz/api/v1/send"
        payload = {
            "api_key": settings.sms_api_key,
            "phone": phone,
            "text": text,
            "sender": settings.sms_sender_name,
        }
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                res = await client.post(url, json=payload)
                if res.status_code in (200, 201):
                    return True, "SMS отправлено через KazInfoTech"
                return False, f"Ошибка KazInfoTech HTTP {res.status_code}"
        except Exception as e:
            logger.error(f"Исключение KazInfoTech: {e}")
            return False, str(e)

    # Fallback на лог
    logger.info(f"📱 [SMS Провайдер ({provider})] Получатель: {phone} | Текст: {text}")
    return True, f"Отправлено через {provider}"


class SmsAuthService:
    @staticmethod
    def is_cooldown_active(phone: str) -> bool:
        """Проверка кулдауна повторной отправки (60 секунд)."""
        key = f"sapar:sms_cooldown:{phone}"
        return cache.get(key) is not None

    @staticmethod
    def set_cooldown(phone: str, seconds: int = 60):
        key = f"sapar:sms_cooldown:{phone}"
        cache.set(key, True, ttl_seconds=seconds)

    @classmethod
    async def request_otp(cls, raw_phone: str) -> Tuple[bool, str, Optional[str]]:
        """Запрашивает отправку OTP-кода. Возвращает (success, message, dev_code)."""
        phone = normalize_phone(raw_phone)
        if len(phone) < 11:
            return False, "Некорректный номер телефона", None

        if cls.is_cooldown_active(phone):
            return False, "Повторная отправка SMS возможна через 1 минуту", None

        code = generate_otp_code()
        text = f"Ваш код для входа в Sapar: {code}. Никому не сообщайте его."

        # Сохраняем код в кэше с TTL (5 минут)
        otp_key = f"sapar:otp:{phone}"
        cache.set(otp_key, {"code": code, "attempts": 0}, ttl_seconds=settings.sms_otp_expire_seconds)
        cls.set_cooldown(phone, seconds=60)

        ok, msg = await send_sms_via_provider(phone, text)
        if not ok:
            return False, msg, None

        # В dev-режиме или при mock возвращаем код в ответе для быстрого тестирования
        dev_code = code if (settings.debug or settings.sms_provider == "mock" or not settings.sms_api_key) else None
        return True, "SMS с 4-значным кодом отправлено", dev_code

    @classmethod
    def verify_otp(cls, raw_phone: str, input_code: str) -> Tuple[bool, str]:
        """Проверка введённого OTP-кода."""
        phone = normalize_phone(raw_phone)
        otp_key = f"sapar:otp:{phone}"
        saved_data = cache.get(otp_key)

        if not saved_data:
            return False, "Код подтверждения истек или не запрашивался. Запросите новый код."

        saved_code = saved_data.get("code")
        attempts = saved_data.get("attempts", 0)

        if attempts >= 3:
            cache.delete(otp_key)
            return False, "Превышено число попыток ввода. Запросите новый код."

        if str(input_code).strip() != str(saved_code).strip():
            saved_data["attempts"] = attempts + 1
            cache.set(otp_key, saved_data, ttl_seconds=settings.sms_otp_expire_seconds)
            return False, f"Неверный код. Осталось попыток: {3 - saved_data['attempts']}"

        # Код верный — удаляем одноразовый ключ
        cache.delete(otp_key)
        return True, "Успешная верификация"
