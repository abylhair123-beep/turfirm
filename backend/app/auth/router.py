from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.auth.models import User
from app.auth.schemas import Token, UserLogin, UserRegister, UserResponse
from app.agencies.models import Agency
from app.core.security import create_access_token, get_password_hash, verify_password
from app.database import get_db
from app.dependencies import get_current_user

router = APIRouter(prefix="/auth", tags=["Аутентификация"])


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(user_in: UserRegister, db: Session = Depends(get_db)):
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
def login(login_data: UserLogin, db: Session = Depends(get_db)):
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
def login_oauth(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
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
