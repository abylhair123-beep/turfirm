import logging
import random
import re
from typing import Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.agencies.models import Agency
from app.auth.models import User
from app.auth.schemas import (
    EmailSendCodeRequest,
    EmailVerifyCodeRequest,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    ResetPasswordRequest,
    SmsSendOtpRequest,
    SmsSendOtpResponse,
    SmsVerifyOtpRequest,
    Token,
    UserLogin,
    UserRegister,
    UserResponse,
)
from app.auth.sms_service import SmsAuthService, normalize_phone
from app.core.cache import cache
from app.core.config import settings
from app.core.limiter import limiter
from app.core.security import create_access_token, get_password_hash, verify_password
from app.database import get_db
from app.dependencies import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["Аутентификация"])


def _build_token(user: User) -> Token:
    token = create_access_token(user.id)
    return Token(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        email=user.email,
        role=user.role,
        full_name=user.full_name,
        isEmailVerified=user.is_email_verified,
        isPhoneVerified=user.is_phone_verified,
    )


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.rate_limit_auth)
def register(request: Request, user_in: UserRegister, db: Session = Depends(get_db)):
    clean_email = user_in.email.lower().strip()
    existing = db.query(User).filter(User.email == clean_email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Пользователь с таким email уже существует",
        )

    clean_phone = normalize_phone(user_in.phone) if user_in.phone else None
    if clean_phone:
        existing_phone = db.query(User).filter(User.phone == clean_phone).first()
        if existing_phone:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Пользователь с таким номером телефона уже существует",
            )

    user = User(
        email=clean_email,
        hashed_password=get_password_hash(user_in.password),
        full_name=user_in.full_name.strip(),
        phone=clean_phone,
        role=user_in.role if user_in.role in ("client", "agency", "admin") else "client",
        is_active=True,
        is_email_verified=False,
        is_phone_verified=False,
    )
    db.add(user)
    db.flush()

    if user.role == "agency":
        agency_name = (user_in.agency_name or user_in.full_name).strip()
        slug = agency_name.lower().replace(" ", "-").replace("'", "")
        base_slug = slug or "agency"
        count = 1
        while db.query(Agency).filter(Agency.slug == slug).first():
            slug = f"{base_slug}-{count}"
            count += 1

        agency = Agency(
            name=agency_name,
            slug=slug,
            email=user.email,
            phone=user.phone,
            user_id=user.id,
            verified=False,
            description="Турагентство на платформе Sapar",
        )
        db.add(agency)

    db.commit()
    db.refresh(user)

    # Автоматически отправляем код подтверждения email в фоне
    verify_code = str(random.randint(100000, 999999))
    cache.set(f"sapar:email_verify:{clean_email}", verify_code, ttl_seconds=900)
    logger.info(f"[EMAIL_VERIFY] Код верификации для {clean_email}: {verify_code}")

    return _build_token(user)


@router.post("/login", response_model=Token)
@limiter.limit(settings.rate_limit_auth)
def login(request: Request, login_data: UserLogin, db: Session = Depends(get_db)):
    clean_email = login_data.email.lower().strip()
    user = db.query(User).filter(User.email == clean_email).first()
    if not user or not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный email или пароль",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Учетная запись отключена. Обратитесь в службу поддержки.",
        )

    return _build_token(user)


@router.post("/oauth-token", response_model=Token)
@limiter.limit(settings.rate_limit_auth)
def login_oauth(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    clean_email = form_data.username.lower().strip()
    user = db.query(User).filter(User.email == clean_email).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный email или пароль",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Учетная запись отключена",
        )
    return _build_token(user)


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Удаление аккаунта пользователя (требование Apple App Store Guideline 5.1.1(v))."""
    db.delete(current_user)
    db.commit()
    return None


# ==================== ПОДТВЕРЖДЕНИЕ EMAIL ====================

@router.post("/email/send-code")
@limiter.limit(settings.rate_limit_auth)
def send_email_verification_code(request: Request, req_in: EmailSendCodeRequest, db: Session = Depends(get_db)):
    """Отправка 6-значного кода подтверждения на Email."""
    clean_email = req_in.email.lower().strip()
    user = db.query(User).filter(User.email == clean_email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь с указанным email не найден")

    code = str(random.randint(100000, 999999))
    cache.set(f"sapar:email_verify:{clean_email}", code, ttl_seconds=900)
    logger.info(f"[EMAIL_VERIFY] Отправлен код на {clean_email}: {code}")

    return {
        "status": "ok",
        "message": f"Код подтверждения отправлен на {clean_email}",
        "expiresIn": 900,
        "devCode": code if settings.debug or settings.environment == "development" else None,
    }


@router.post("/email/verify-code")
@limiter.limit(settings.rate_limit_auth)
def verify_email_code(request: Request, req_in: EmailVerifyCodeRequest, db: Session = Depends(get_db)):
    """Проверка 6-значного кода и подтверждение Email."""
    clean_email = req_in.email.lower().strip()
    cached_code = cache.get(f"sapar:email_verify:{clean_email}")
    if not cached_code or str(cached_code) != req_in.code.strip():
        raise HTTPException(status_code=400, detail="Неверный или просроченный код подтверждения")

    user = db.query(User).filter(User.email == clean_email).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    user.is_email_verified = True
    db.commit()
    cache.delete(f"sapar:email_verify:{clean_email}")

    return {
        "status": "ok",
        "message": "Email успешно подтвержден",
        "isEmailVerified": True,
    }


# ==================== ВОССТАНОВЛЕНИЕ ПАРОЛЯ ====================

@router.post("/forgot-password", response_model=ForgotPasswordResponse)
@limiter.limit(settings.rate_limit_auth)
async def forgot_password(request: Request, req_in: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Запрос кода восстановления пароля по Email или SMS."""
    raw_ident = req_in.identifier.strip()
    is_phone = bool(re.search(r"^\+?[0-9\s\-\(\)]{10,18}$", raw_ident))

    user = None
    channel = "email"
    target_contact = ""

    if is_phone:
        clean_phone = normalize_phone(raw_ident)
        user = db.query(User).filter(User.phone == clean_phone).first()
        channel = "sms"
        target_contact = clean_phone
    else:
        clean_email = raw_ident.lower()
        user = db.query(User).filter(User.email == clean_email).first()
        channel = "email"
        target_contact = clean_email

    if not user:
        # Для безопасности возвращаем 200, даже если пользователя нет (anti-enumeration),
        # но в dev-режиме указываем подробнее.
        return ForgotPasswordResponse(
            status="ok",
            message=f"Если аккаунт существует, код отправлен на {raw_ident}",
            expiresIn=900,
            channel=channel,
            devCode=None,
        )

    code = str(random.randint(100000, 999999))
    cache_key = f"sapar:pwd_reset:{user.id}"
    cache.set(cache_key, code, ttl_seconds=900)
    logger.info(f"[PWD_RESET] Код сброса для пользователя {user.id} ({target_contact}): {code}")

    dev_code = code if settings.debug or settings.environment == "development" else None

    if channel == "sms" and user.phone:
        await SmsAuthService.request_otp(user.phone)

    return ForgotPasswordResponse(
        status="ok",
        message=f"Код сброса пароля отправлен ({channel.upper()})",
        expiresIn=900,
        channel=channel,
        devCode=dev_code,
    )


@router.post("/reset-password", response_model=Token)
@limiter.limit(settings.rate_limit_auth)
def reset_password(request: Request, reset_in: ResetPasswordRequest, db: Session = Depends(get_db)):
    """Сброс пароля с проверкой проверочного кода."""
    raw_ident = reset_in.identifier.strip()
    is_phone = bool(re.search(r"^\+?[0-9\s\-\(\)]{10,18}$", raw_ident))

    if is_phone:
        user = db.query(User).filter(User.phone == normalize_phone(raw_ident)).first()
    else:
        user = db.query(User).filter(User.email == raw_ident.lower()).first()

    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    cache_key = f"sapar:pwd_reset:{user.id}"
    cached_code = cache.get(cache_key)

    # Проверка через SMS OTP сервис, если код был по SMS
    sms_ok, _ = SmsAuthService.verify_otp(user.phone or "", reset_in.code) if user.phone else (False, "")

    if not (cached_code and str(cached_code) == reset_in.code.strip()) and not sms_ok:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Неверный или просроченный проверочный код",
        )

    if len(reset_in.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Новый пароль должен содержать минимум 6 символов",
        )

    user.hashed_password = get_password_hash(reset_in.new_password)
    db.commit()
    db.refresh(user)

    cache.delete(cache_key)
    logger.info(f"[PWD_RESET] Пароль успешно сброшен для пользователя {user.id}")

    return _build_token(user)


# ==================== SMS OTP АВТОРИЗАЦИЯ ====================

@router.post("/sms/send-otp", response_model=SmsSendOtpResponse)
@limiter.limit(settings.rate_limit_auth)
async def send_sms_otp(request: Request, otp_in: SmsSendOtpRequest):
    """Отправка 4-значного OTP-кода по SMS для быстрой авторизации без пароля."""
    ok, msg, dev_code = await SmsAuthService.request_otp(otp_in.phone)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=msg,
        )
    return SmsSendOtpResponse(
        status="ok",
        message=msg,
        expiresIn=settings.sms_otp_expire_seconds,
        devCode=dev_code,
    )


@router.post("/sms/verify-otp", response_model=Token)
@limiter.limit(settings.rate_limit_auth)
def verify_sms_otp(request: Request, verify_in: SmsVerifyOtpRequest, db: Session = Depends(get_db)):
    """Верификация SMS-кода и автоматический вход или регистрация пользователя."""
    clean_phone = normalize_phone(verify_in.phone)
    ok, msg = SmsAuthService.verify_otp(clean_phone, verify_in.code)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=msg,
        )

    # Ищем пользователя по телефону
    user = db.query(User).filter(User.phone == clean_phone).first()

    # Fallback поиск по сгенерированному email
    fallback_email = f"{clean_phone.replace('+', '')}@sapar.kz"
    if not user:
        user = db.query(User).filter(User.email == fallback_email).first()

    # Если пользователь новый — регистрируем в системе
    if not user:
        user = User(
            email=fallback_email,
            hashed_password=get_password_hash(uuid.uuid4().hex),
            full_name=f"Турист {clean_phone[-4:]}",
            phone=clean_phone,
            role="client",
            is_active=True,
            is_phone_verified=True,
            is_email_verified=False,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        user.is_phone_verified = True
        db.commit()

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Учетная запись отключена",
        )

    return _build_token(user)
