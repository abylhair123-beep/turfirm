from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field


class UserBase(BaseModel):
    email: EmailStr
    full_name: str = Field(alias="fullName")
    phone: Optional[str] = None
    role: str = "client"

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class UserRegister(UserBase):
    password: str
    agency_name: Optional[str] = Field(default=None, alias="agencyName")


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    email: str
    role: str
    full_name: str
    is_email_verified: bool = Field(default=False, alias="isEmailVerified")
    is_phone_verified: bool = Field(default=False, alias="isPhoneVerified")

    model_config = {"populate_by_name": True}


class TokenPayload(BaseModel):
    sub: Optional[str] = None
    exp: Optional[int] = None


class UserResponse(UserBase):
    id: str
    is_active: bool
    is_email_verified: bool = Field(default=False, alias="isEmailVerified")
    is_phone_verified: bool = Field(default=False, alias="isPhoneVerified")
    created_at: datetime

    model_config = {
        "from_attributes": True,
        "populate_by_name": True,
    }


class SmsSendOtpRequest(BaseModel):
    phone: str


class SmsSendOtpResponse(BaseModel):
    status: str
    message: str
    expiresIn: int
    devCode: Optional[str] = None


class SmsVerifyOtpRequest(BaseModel):
    phone: str
    code: str


# Восстановление пароля
class ForgotPasswordRequest(BaseModel):
    identifier: str = Field(description="Email или номер телефона пользователя")


class ForgotPasswordResponse(BaseModel):
    status: str
    message: str
    expiresIn: int
    channel: str  # "email" or "sms"
    devCode: Optional[str] = None


class ResetPasswordRequest(BaseModel):
    identifier: str
    code: str
    new_password: str = Field(alias="newPassword")

    model_config = {"populate_by_name": True}


# Подтверждение Email
class EmailSendCodeRequest(BaseModel):
    email: EmailStr


class EmailVerifyCodeRequest(BaseModel):
    email: EmailStr
    code: str
