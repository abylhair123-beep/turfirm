from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.auth.models import User
from app.auth.schemas import (
    SmsSendOtpRequest,
    SmsSendOtpResponse,
    SmsVerifyOtpRequest,
    Token,
    UserLogin,
    UserRegister,
    UserResponse,
)
from app.auth.sms_service import SmsAuthService, normalize_phone
from app.agencies.models import Agency
from app.core.config import settings
from app.core.limiter import limiter
from app.core.security import create_access_token, get_password_hash, verify_password
from app.database import get_db
from app.dependencies import get_current_user

router = APIRouter(prefix="/auth", tags=["Аутентификация"])


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.rate_limit_auth)
def register(request: Request, user_in: UserRegister, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == user_in.email.lower()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Пользователь с таким email уже существует",
        )

    user = User(
        email=user_in.email.lower(),
        hashed_password=get_password_hash(user_in.password),
        full_name=user_in.full_name,
        phone=user_in.phone,
        role=user_in.role if user_in.role in ("client", "agency", "admin") else "client",
    )
    db.add(user)
    db.flush()

    if user.role == "agency":
        agency_name = user_in.agency_name or user_in.full_name
        slug = agency_name.lower().replace(" ", "-").replace("'", "")
        # ensure unique slug
        base_slug = slug
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

    token = create_access_token(user.id)
    return Token(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        email=user.email,
        role=user.role,
        full_name=user.full_name,
    )




@router.post("/login", response_model=Token)
@limiter.limit(settings.rate_limit_auth)
def login(request: Request, login_data: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == login_data.email.lower()).first()
    if not user or not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный email или пароль",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Учетная запись отключена",
        )

    token = create_access_token(user.id)
    return Token(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        email=user.email,
        role=user.role,
        full_name=user.full_name,
    )




@router.post("/oauth-token", response_model=Token)
@limiter.limit(settings.rate_limit_auth)
def login_oauth(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username.lower()).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный email или пароль",
        )
    token = create_access_token(user.id)
    return Token(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        email=user.email,
        role=user.role,
        full_name=user.full_name,
    )




@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Удаление аккаунта пользователя (требование Apple App Store Guideline 5.1.1(v))."""
    db.delete(current_user)
    db.commit()
    return None



@router.post("/sms/send-otp", response_model=SmsSendOtpResponse)
@limiter.limit(settings.rate_limit_auth)
async def send_sms_otp(request: Request, otp_in: SmsSendOtpRequest):
    """Отправка 4-значного OTP-кода по SMS для авторизации/регистрации."""
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
        import uuid
        user = User(
            email=fallback_email,
            hashed_password=get_password_hash(uuid.uuid4().hex),
            full_name=f"Турист {clean_phone[-4:]}",
            phone=clean_phone,
            role="client",
            is_active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Учетная запись отключена",
        )

    token = create_access_token(user.id)
    return Token(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        email=user.email,
        role=user.role,
        full_name=user.full_name,
    )



