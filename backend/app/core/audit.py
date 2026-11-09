from datetime import datetime, timezone
import json
import logging
import re
from typing import Any, Dict, Optional
import uuid
from sqlalchemy import Column, DateTime, Integer, String, Text
from app.database import Base

logger = logging.getLogger("sapar.audit")


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    user_id = Column(String(36), nullable=True, index=True)
    user_email = Column(String(255), nullable=True, index=True)
    user_role = Column(String(30), nullable=True)
    ip_address = Column(String(45), nullable=True)
    action = Column(String(60), nullable=False, index=True)
    resource = Column(String(60), nullable=False)
    status = Column(String(20), default="SUCCESS", nullable=False)  # SUCCESS, WARNING, FAILED
    details = Column(Text, nullable=True)


def mask_email(email: Optional[str]) -> Optional[str]:
    """Маскирует email: abylhair.123@gmail.com -> a***3@gmail.com"""
    if not email or "@" not in email:
        return email
    local, domain = email.split("@", 1)
    if len(local) <= 2:
        masked_local = local[0] + "***"
    else:
        masked_local = local[0] + "***" + local[-1]
    return f"{masked_local}@{domain}"


def mask_phone(phone: Optional[str]) -> Optional[str]:
    """Маскирует номер телефона: +7 777 123 4567 -> +7 *** *** 67"""
    if not phone:
        return phone
    digits = re.sub(r"\D", "", phone)
    if len(digits) >= 10:
        return f"+{digits[0]} *** *** {digits[-2:]}"
    return f"***{digits[-2:]}" if len(digits) >= 2 else "***"


def mask_card_number(card: Optional[str]) -> Optional[str]:
    """Маскирует номер банковской карты: 4400 1234 5678 9012 -> **** **** **** 9012"""
    if not card:
        return card
    digits = re.sub(r"\D", "", card)
    if len(digits) >= 4:
        return f"**** **** **** {digits[-4:]}"
    return "****"


def sanitize_pii_dict(data: Dict[str, Any]) -> Dict[str, Any]:
    """Рекурсивно маскирует чувствительные персональные данные перед логированием."""
    sensitive_keys = {
        "password": "[REDACTED]",
        "hashed_password": "[REDACTED]",
        "token": "[REDACTED]",
        "temp_token": "[REDACTED]",
        "access_token": "[REDACTED]",
        "secret": "[REDACTED]",
        "totp_secret": "[REDACTED]",
        "cvv": "[REDACTED]",
        "cvc": "[REDACTED]",
    }
    result = {}
    for k, v in data.items():
        k_lower = k.lower()
        if k_lower in sensitive_keys:
            result[k] = sensitive_keys[k_lower]
        elif "email" in k_lower and isinstance(v, str):
            result[k] = mask_email(v)
        elif "phone" in k_lower and isinstance(v, str):
            result[k] = mask_phone(v)
        elif "card" in k_lower and isinstance(v, str):
            result[k] = mask_card_number(v)
        elif isinstance(v, dict):
            result[k] = sanitize_pii_dict(v)
        else:
            result[k] = v
    return result


def log_audit_event(
    db,
    action: str,
    resource: str,
    user_id: Optional[str] = None,
    user_email: Optional[str] = None,
    user_role: Optional[str] = None,
    ip_address: Optional[str] = None,
    status: str = "SUCCESS",
    details: Optional[Dict[str, Any]] = None,
) -> AuditLog:
    """Записывает событие безопасности и аудита в базу данных и структурированный лог."""
    sanitized_details_str = None
    if details is not None:
        try:
            sanitized_data = sanitize_pii_dict(details)
            sanitized_details_str = json.dumps(sanitized_data, ensure_ascii=False)
        except Exception:
            sanitized_details_str = str(details)[:500]

    log_entry = AuditLog(
        id=str(uuid.uuid4()),
        created_at=datetime.now(timezone.utc),
        user_id=user_id,
        user_email=mask_email(user_email) if user_email else None,
        user_role=user_role,
        ip_address=ip_address,
        action=action,
        resource=resource,
        status=status,
        details=sanitized_details_str,
    )
    try:
        db.add(log_entry)
        db.commit()
    except Exception as e:
        logger.error(f"Failed to persist audit log: {e}")
        try:
            db.rollback()
        except Exception:
            pass

    logger.info(
        f"[AUDIT] action={action} status={status} user={user_email or user_id or 'anon'} ip={ip_address} resource={resource}"
    )
    return log_entry
