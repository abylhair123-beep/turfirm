import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.audit import mask_card_number, mask_email, mask_phone
from app.core.totp import (
    generate_backup_codes,
    generate_totp_secret,
    get_totp_code,
    get_totp_uri,
    verify_totp_code,
)
from app.database import Base, get_db
from app.main import app
from app.seed import seed_data

# In-memory SQLite database for tests
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session", autouse=True)
def setup_database():
    from app.core.cache import cache
    cache.delete_pattern("sapar:cache:tours:*")
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    seed_data(db)
    db.close()
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(autouse=True)
def reset_rate_limiter():
    from app.core.limiter import limiter
    limiter.reset()
    yield
    limiter.reset()


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)


def test_health():
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"


def test_get_categories():
    res = client.get("/api/v1/tours/categories")
    assert res.status_code == 200
    data = res.json()
    assert len(data) >= 5
    category_names = [c["name"] for c in data]
    assert "Пляжный отдых" in category_names
    assert "Горы" in category_names


def test_get_tours():
    res = client.get("/api/v1/tours")
    assert res.status_code == 200
    tours = res.json()
    assert len(tours) >= 2
    tour_ids = [t["id"] for t in tours]
    assert "antalya-7n" in tour_ids
    assert "dubai-5n" in tour_ids


def test_filter_tours_by_category():
    res = client.get("/api/v1/tours?category=Горы")
    assert res.status_code == 200
    tours = res.json()
    assert len(tours) >= 1
    for t in tours:
        assert t["category"] == "Горы"


def test_filter_tours_by_stars_and_meal_and_beach():
    # 5 stars only
    res5 = client.get("/api/v1/tours?hotelStars=5")
    assert res5.status_code == 200
    tours5 = res5.json()
    assert len(tours5) >= 1
    for t in tours5:
        assert t["hotelStars"] >= 5

    # Beach line 1
    res_beach = client.get("/api/v1/tours?beachLine=1")
    assert res_beach.status_code == 200
    beach_tours = res_beach.json()
    assert len(beach_tours) >= 1
    for t in beach_tours:
        assert t["beachLine"] <= 1

    # Meal type AI
    res_meal = client.get("/api/v1/tours?mealType=AI")
    assert res_meal.status_code == 200
    ai_tours = res_meal.json()
    assert any("AI" in t["mealType"] or "вкл" in t["meal"].lower() for t in ai_tours)

    # Duration filter
    res_dur = client.get("/api/v1/tours?minDuration=6&maxDuration=8")
    assert res_dur.status_code == 200
    dur_tours = res_dur.json()
    assert len(dur_tours) >= 1
    for t in dur_tours:
        assert 6 <= t["durationNights"] <= 8


def test_get_tour_by_id():
    res = client.get("/api/v1/tours/antalya-7n")
    assert res.status_code == 200
    tour = res.json()
    assert tour["id"] == "antalya-7n"
    assert tour["agency"] == "Turan Travel"
    assert tour["priceFrom"] == 245000
    assert len(tour["included"]) == 4


def test_create_booking():
    booking_payload = {
        "tourId": "antalya-7n",
        "customerName": "Айгерим Сериковна",
        "customerPhone": "+7 701 234 56 78",
        "customerEmail": "aigerim@mail.kz",
        "guestsCount": 2,
        "paymentMethod": "Kaspi Pay",
    }
    res = client.post("/api/v1/bookings", json=booking_payload)
    assert res.status_code == 201
    booking = res.json()
    assert booking["tourId"] == "antalya-7n"
    assert booking["guestsCount"] == 2
    assert booking["serviceFee"] == 9800
    assert booking["totalPrice"] == (245000 * 2) + 9800
    assert booking["status"] == "paid"


def test_auth_login():
    login_data = {
        "email": "admin@sapar.kz",
        "password": "Admin123!",
    }
    res = client.post("/api/v1/auth/login", json=login_data)
    assert res.status_code == 200
    token_data = res.json()
    assert "access_token" in token_data
    assert token_data["role"] == "admin"


def test_reviews():
    rev_payload = {
        "tourId": "antalya-7n",
        "authorName": "Нурлан",
        "rating": 5.0,
        "comment": "Отличный сервис и отель!",
    }
    res = client.post("/api/v1/reviews/tours/antalya-7n", json=rev_payload)
    assert res.status_code == 201

    res_list = client.get("/api/v1/reviews/tours/antalya-7n")
    assert res_list.status_code == 200
    reviews = res_list.json()
    assert any(r["authorName"] == "Нурлан" for r in reviews)


# --- Тесты платежной системы Kaspi Pay ---

def test_kaspi_payment_config_status():
    res = client.get("/api/v1/payments/config-status")
    assert res.status_code == 200
    data = res.json()
    assert data["provider"] == "Kaspi Pay"
    assert "isTestMode" in data
    assert "apiUrl" in data


def test_initiate_and_confirm_kaspi_payment():
    # 1. Создаем бронь
    booking_res = client.post("/api/v1/bookings", json={
        "tourId": "dubai-5n",
        "customerName": "Асет Муратов",
        "customerPhone": "+7 777 123 45 67",
        "customerEmail": "aset@gmail.com",
        "guestsCount": 1,
        "paymentMethod": "Kaspi Pay",
    })
    assert booking_res.status_code == 201
    booking_id = booking_res.json()["id"]

    # 2. Инициируем оплату через Kaspi Pay
    pay_res = client.post("/api/v1/payments/initiate", json={
        "bookingId": booking_id,
        "paymentMethod": "Kaspi Pay",
        "customerPhone": "+7 777 123 45 67",
        "customerName": "Асет Муратов",
    })
    assert pay_res.status_code == 201
    pay_data = pay_res.json()
    payment_id = pay_data["paymentId"]
    assert pay_data["bookingId"] == booking_id
    assert pay_data["provider"] == "kaspi"
    assert "kaspi.kz" in pay_data["paymentUrl"]
    assert pay_data["qrCodeData"] is not None
    assert pay_data["status"] == "pending"

    # 3. Проверяем статус платежа
    status_res = client.get(f"/api/v1/payments/{payment_id}")
    assert status_res.status_code == 200
    assert status_res.json()["status"] == "pending"

    # 4. Подтверждаем оплату (клиент оплатил в приложении Kaspi)
    confirm_res = client.post(f"/api/v1/payments/{payment_id}/confirm")
    assert confirm_res.status_code == 200
    assert confirm_res.json()["status"] == "success"

    # 5. Проверяем, что статус бронирования обновился на 'paid'
    check_booking = client.get(f"/api/v1/bookings/{booking_id}")
    assert check_booking.status_code == 200
    assert check_booking.json()["status"] == "paid"


def test_kaspi_webhook():
    # Создаем бронь и платеж
    b_res = client.post("/api/v1/bookings", json={
        "tourId": "antalya-7n",
        "customerName": "Гульнар",
        "customerPhone": "+7 705 999 88 77",
        "customerEmail": "gulnar@mail.kz",
        "guestsCount": 1,
        "paymentMethod": "Kaspi Pay",
    })
    booking_id = b_res.json()["id"]

    pay_res = client.post("/api/v1/payments/initiate", json={
        "bookingId": booking_id,
        "paymentMethod": "Kaspi Pay",
    })
    payment_id = pay_res.json()["paymentId"]

    # Отправляем вебхук от Kaspi
    webhook_res = client.post("/api/v1/payments/kaspi/webhook", json={
        "orderId": payment_id,
        "status": "paid",
        "amount": 245000 + 9800,
    })
    assert webhook_res.status_code == 200
    assert webhook_res.json()["status"] == "success"


def test_agency_stats():
    # Логинимся как менеджер агентства
    login_res = client.post("/api/v1/auth/login", json={
        "email": "turan@sapar.kz",
        "password": "Agency123!",
    })
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    res = client.get("/api/v1/agencies/me/stats", headers=headers)
    assert res.status_code == 200
    stats = res.json()
    assert "agencyName" in stats
    assert stats["agencyName"] == "Turan Travel"
    assert "activeToursCount" in stats
    assert "totalRevenueKzt" in stats


def test_favorites():
    # Логинимся клиентом
    login_res = client.post("/api/v1/auth/login", json={
        "email": "aigerim@mail.kz",
        "password": "User123!",
    })
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Добавляем тур в избранное
    fav_res = client.post("/api/v1/favorites/antalya-7n", headers=headers)
    assert fav_res.status_code == 201

    # 2. Проверяем наличие
    check_res = client.get("/api/v1/favorites/check/antalya-7n", headers=headers)
    assert check_res.status_code == 200
    assert check_res.json()["isFavorite"] is True

    # 3. Список избранного
    list_res = client.get("/api/v1/favorites", headers=headers)
    assert list_res.status_code == 200
    fav_tours = list_res.json()
    assert any(t["id"] == "antalya-7n" for t in fav_tours)

    # 4. Удаляем из избранного
    del_res = client.delete("/api/v1/favorites/antalya-7n", headers=headers)
    assert del_res.status_code == 200

    check_again = client.get("/api/v1/favorites/check/antalya-7n", headers=headers)
    assert check_again.json()["isFavorite"] is False


def test_health_extended():
    res = client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ok"
    assert "redis" in data
    assert "rate_limiting" in data
    assert "sentry" in data


def test_rate_limiting_enforcement():
    """Проверка срабатывания Rate Limiting (slowapi 5/minute) при серии запросов."""
    from app.core.limiter import limiter
    limiter.reset()

    # 5 запросов разрешены
    for _ in range(5):
        resp = client.post("/api/v1/auth/login", json={
            "email": "invalid@sapar.kz",
            "password": "wrongpassword",
        })
        # Возвращается 401 Unauthorized (логика бэкенда)
        assert resp.status_code in (401, 200)

    # 6-й запрос блокируется лимитером (429 Too Many Requests)
    exceeded_resp = client.post("/api/v1/auth/login", json={
        "email": "invalid@sapar.kz",
        "password": "wrongpassword",
    })
    assert exceeded_resp.status_code == 429
    limiter.reset()


def test_redis_cache_manager():
    """Проверка генерации ключей и отказоустойчивости менеджера кэша."""
    from app.core.cache import cache

    # Генерация детерминированных ключей
    key1 = cache.generate_key("tours", cat="Пляжный отдых", min_p=100000)
    key2 = cache.generate_key("tours", cat="Пляжный отдых", min_p=100000)
    key3 = cache.generate_key("tours", cat="Горы", min_p=100000)
    assert key1 == key2
    assert key1 != key3

    # Если Redis оффлайн, get/set/delete не должны вызывать исключений
    val = cache.get("non_existent_key")
    assert val is None
    cache.delete("non_existent_key")
    cache.delete_pattern("sapar:cache:tours:*")


def test_database_backup_module():
    """Проверка структуры и парсера параметров в scripts/backup_db.py."""
    from scripts.backup_db import parse_db_url
    params = parse_db_url("postgresql+psycopg2://testuser:testpass@db.sapar.kz:5432/sapardb")
    assert params["user"] == "testuser"
    assert params["password"] == "testpass"
    assert params["host"] == "db.sapar.kz"
    assert params["port"] == 5432
    assert params["dbname"] == "sapardb"


def test_booking_pdf_voucher_and_verification():
    """Тест генерации PDF-ваучера поездки и публичной верификации."""
    # 1. Создаем тестовое бронирование
    booking_res = client.post("/api/v1/bookings", json={
        "tourId": "antalya-7n",
        "customerName": "Айдар Сериков",
        "customerPhone": "+7 777 555 44 33",
        "customerEmail": "aidar@sapar.kz",
        "guestsCount": 2,
        "paymentMethod": "Kaspi Pay",
    })
    assert booking_res.status_code == 201
    booking_id = booking_res.json()["id"]

    # 2. Запрашиваем PDF-ваучер
    pdf_res = client.get(f"/api/v1/bookings/{booking_id}/voucher.pdf")
    assert pdf_res.status_code == 200
    assert pdf_res.headers["content-type"] == "application/pdf"
    assert pdf_res.content.startswith(b"%PDF")
    assert len(pdf_res.content) > 1000

    # 3. Проверяем QR-ссылку верификации
    verify_res = client.get(f"/api/v1/bookings/{booking_id}/verify")
    assert verify_res.status_code == 200
    data = verify_res.json()
    assert data["valid"] is True
    assert data["bookingId"] == booking_id
    assert data["customerName"] == "Айдар Сериков"
    assert "message" in data


def test_sms_authentication_flow():
    """Тест авторизации по номеру телефона через SMS и 4-значный OTP-код."""
    from app.core.cache import cache
    from app.auth.sms_service import normalize_phone
    test_phone = "+7 777 888 99 00"
    clean = normalize_phone(test_phone)
    cache.delete(f"sapar:sms_cooldown:{clean}")
    cache.delete(f"sapar:otp:{clean}")

    # 1. Запрос 4-значного OTP-кода
    send_res = client.post("/api/v1/auth/sms/send-otp", json={
        "phone": test_phone,
    })
    assert send_res.status_code == 200
    send_data = send_res.json()
    assert send_data["status"] == "ok"
    assert "expiresIn" in send_data
    otp_code = send_data.get("devCode")
    assert otp_code is not None
    assert len(str(otp_code)) == 4

    # 2. Проверка неверного кода (должен вернуть 400)
    invalid_verify = client.post("/api/v1/auth/sms/verify-otp", json={
        "phone": test_phone,
        "code": "0000",
    })
    assert invalid_verify.status_code == 400

    # 3. Проверка правильного кода (должен вернуть Token)
    verify_res = client.post("/api/v1/auth/sms/verify-otp", json={
        "phone": test_phone,
        "code": str(otp_code),
    })
    assert verify_res.status_code == 200
    token_data = verify_res.json()
    assert "access_token" in token_data
    assert token_data["token_type"] == "bearer"
    assert token_data["role"] == "client"

    # 4. Проверяем доступ к /me с полученным JWT-токеном
    me_res = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token_data['access_token']}"},
    )
    assert me_res.status_code == 200
    assert me_res.json()["phone"] == "+77778889900"


def test_agency_b2b_dashboard():
    """Тест B2B функционала агентства: аналитика, канбан броней, экспорт в Excel и пауза тура."""
    # 1. Авторизация менеджера турагентства Turan Travel
    login_res = client.post("/api/v1/auth/login", json={
        "email": "turan@sapar.kz",
        "password": "Agency123!",
    })
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Получение расширенной аналитики (выручка, 10% комиссия, средний чек, график)
    analytics_res = client.get("/api/v1/agencies/me/analytics?period=month", headers=headers)
    assert analytics_res.status_code == 200
    analytics = analytics_res.json()
    assert "totalRevenueKzt" in analytics
    assert "commissionKzt" in analytics
    assert "averageCheckKzt" in analytics
    assert "statusCounts" in analytics
    assert "salesChart" in analytics
    assert isinstance(analytics["salesChart"], list)
    assert len(analytics["salesChart"]) > 0

    # 3. Список заявок туристов (Канбан)
    bookings_res = client.get("/api/v1/agencies/me/bookings", headers=headers)
    assert bookings_res.status_code == 200
    bookings = bookings_res.json()
    assert isinstance(bookings, list)

    # 4. Выгрузка в Excel (XLSX)
    excel_res = client.get("/api/v1/agencies/me/bookings/export-xlsx", headers=headers)
    assert excel_res.status_code == 200
    assert "spreadsheetml.sheet" in excel_res.headers["content-type"]
    assert len(excel_res.content) > 1000

    # 5. Управление туром: быстрая пауза (снятие с продажи) и возобновление
    # Находим тур агентства
    tours_res = client.get("/api/v1/agencies/me/tours", headers=headers)
    assert tours_res.status_code == 200
    tours = tours_res.json()
    if tours:
        first_tour_id = tours[0]["id"]
        # Тогл активности
        toggle_res = client.patch(f"/api/v1/tours/{first_tour_id}/toggle-active", headers=headers)
        assert toggle_res.status_code == 200
        # Восстановление активности
        toggle_back = client.patch(f"/api/v1/tours/{first_tour_id}/toggle-active", headers=headers)
        assert toggle_back.status_code == 200


def test_role_based_access_control():
    """Тест четкого разграничения прав по ролям: клиент, агентство, админ."""
    # 1. Логин клиента (Айгерим)
    res_client = client.post("/api/v1/auth/login", json={"email": "aigerim@mail.kz", "password": "User123!"})
    token_client = res_client.json()["access_token"]
    headers_client = {"Authorization": f"Bearer {token_client}"}

    # Клиент НЕ имеет доступа к кабинету агентства
    res_forbidden = client.get("/api/v1/agencies/me/bookings", headers=headers_client)
    assert res_forbidden.status_code == 403

    # 2. Логин агентства (Turan Travel)
    res_agency = client.post("/api/v1/auth/login", json={"email": "turan@sapar.kz", "password": "Agency123!"})
    token_agency = res_agency.json()["access_token"]
    headers_agency = {"Authorization": f"Bearer {token_agency}"}

    # Агентство имеет доступ к своим заявкам
    res_agency_bookings = client.get("/api/v1/agencies/me/bookings", headers=headers_agency)
    assert res_agency_bookings.status_code == 200

    # 3. Логин админа
    res_admin = client.post("/api/v1/auth/login", json={"email": "admin@sapar.kz", "password": "Admin123!"})
    token_admin = res_admin.json()["access_token"]
    headers_admin = {"Authorization": f"Bearer {token_admin}"}

    # Админ имеет доступ ко всем бронированиям
    res_admin_bookings = client.get("/api/v1/bookings", headers=headers_admin)
    assert res_admin_bookings.status_code == 200


def test_email_verification_and_password_recovery():
    """Тест верификации email и сброса пароля."""
    # Регистрация нового туриста
    test_email = "newtourist@sapar.kz"
    reg_res = client.post("/api/v1/auth/register", json={
        "email": test_email,
        "password": "Password123!",
        "fullName": "Новый Турист",
        "phone": "+7 777 555 44 33",
        "role": "client",
    })
    assert reg_res.status_code == 201

    # 1. Отправка кода верификации Email
    send_res = client.post("/api/v1/auth/email/send-code", json={"email": test_email})
    assert send_res.status_code == 200
    code = send_res.json()["devCode"]

    # 2. Подтверждение Email
    verify_res = client.post("/api/v1/auth/email/verify-code", json={
        "email": test_email,
        "code": code,
    })
    assert verify_res.status_code == 200
    assert verify_res.json()["isEmailVerified"] is True

    # 3. Запрос восстановления пароля
    forgot_res = client.post("/api/v1/auth/forgot-password", json={"identifier": test_email})
    assert forgot_res.status_code == 200
    reset_code = forgot_res.json()["devCode"]

    # 4. Сброс пароля на новый
    new_password = "BrandNewPassword2026!"
    reset_res = client.post("/api/v1/auth/reset-password", json={
        "identifier": test_email,
        "code": reset_code,
        "newPassword": new_password,
    })
    assert reset_res.status_code == 200
    assert "access_token" in reset_res.json()

    # 5. Проверка логина с новым паролем
    relogin_res = client.post("/api/v1/auth/login", json={
        "email": test_email,
        "password": new_password,
    })
    assert relogin_res.status_code == 200
    assert relogin_res.json()["email"] == test_email


def test_referral_system_blogger_flow():
    """Тест реферальной программы для блогеров:
    - Автогенерация и кастомные ссылки/промокоды
    - Трекинг кликов и проверка валидности промокода
    - Оформление бронирования с реферальным кодом и начисление вознаграждения
    - Сводная статистика блогера и заявка на вывод средств (Payout)
    """
    # 1. Регистрация и логин блогера
    blogger_email = "blogger_travel@sapar.kz"
    reg_res = client.post("/api/v1/auth/register", json={
        "email": blogger_email,
        "password": "BloggerPassword2026!",
        "fullName": "Алихан Трэвел",
        "phone": "+77081112233",
        "role": "client",
    })
    assert reg_res.status_code == 201
    blogger_token = reg_res.json()["access_token"]
    blogger_headers = {"Authorization": f"Bearer {blogger_token}"}

    # 2. Получение списка кампаний (должна автосоздаться первая ссылка)
    me_res = client.get("/api/v1/referrals/me", headers=blogger_headers)
    assert me_res.status_code == 200
    campaigns = me_res.json()
    assert len(campaigns) >= 1
    initial_code = campaigns[0]["code"]
    assert "https://sapar.kz/?ref=" in campaigns[0]["referralUrl"]

    # 3. Создание кастомной кампании
    custom_code = "ALIKHAN_INSTA"
    create_res = client.post("/api/v1/referrals/campaigns", headers=blogger_headers, json={
        "code": custom_code,
        "campaignName": "Instagram Stories 2026",
        "commissionRate": 3.0,
    })
    assert create_res.status_code == 201
    created_data = create_res.json()
    assert created_data["code"] == custom_code
    assert created_data["campaignName"] == "Instagram Stories 2026"

    # 4. Проверка публичного эндпоинта валидации промокода
    check_ok = client.get(f"/api/v1/referrals/check/{custom_code}")
    assert check_ok.status_code == 200
    assert check_ok.json()["valid"] is True
    assert check_ok.json()["bloggerName"] == "Алихан Трэвел"

    check_fail = client.get("/api/v1/referrals/check/FAKE_CODE_999")
    assert check_fail.status_code == 200
    assert check_fail.json()["valid"] is False

    # 5. Трекинг перехода по ссылке (клик)
    click_res = client.post("/api/v1/referrals/click", json={
        "code": custom_code,
        "tourId": "tour-charyn-1",
        "referrerUrl": "https://instagram.com",
    })
    assert click_res.status_code == 200
    assert click_res.json()["clicksCount"] >= 1

    # 6. Оформление бронирования тура с реферальным кодом
    # Сначала получим активный тур
    tours_res = client.get("/api/v1/tours")
    tour = tours_res.json()[0]
    tour_price = tour["priceFrom"]

    booking_res = client.post("/api/v1/bookings", json={
        "tourId": tour["id"],
        "customerName": "Серик Подписчик",
        "customerPhone": "+77079998877",
        "customerEmail": "subscriber@gmail.com",
        "guestsCount": 2,
        "paymentMethod": "Kaspi Pay",
        "referralCode": custom_code,
    })
    assert booking_res.status_code == 201
    booking_data = booking_res.json()
    assert booking_data["referralCode"] == custom_code
    expected_reward = int((tour_price * 2) * 0.03)
    assert booking_data["referralReward"] == expected_reward

    # 7. Проверка обновленной статистики блогера
    stats_res = client.get("/api/v1/referrals/stats", headers=blogger_headers)
    assert stats_res.status_code == 200
    stats = stats_res.json()
    assert stats["totalClicks"] >= 1
    assert stats["totalBookings"] >= 1
    assert stats["totalEarned"] >= expected_reward
    assert stats["balance"] >= expected_reward
    assert stats["conversionRate"] > 0
    assert len(stats["recentBookings"]) >= 1
    assert stats["recentBookings"][0]["customerName"] == "Серик Подписчик"

    # 8. Запрос на вывод средств блогером
    payout_res = client.post("/api/v1/referrals/payout", headers=blogger_headers, json={
        "amount": 1000,
        "paymentDetails": "Kaspi Gold +7 708 111 22 33",
    })
    assert payout_res.status_code == 200
    payout_data = payout_res.json()
    assert payout_data["status"] == "pending"
    assert payout_data["remainingBalance"] == stats["balance"] - 1000


def test_admin_financial_balance_and_records():
    """Тест финансового баланса и админ-панели:
    - Защита доступа (только admin)
    - Сводка приходов, расходов, чистой прибыли
    - Внесение рекламных поступлений и операционных затрат
    - Детализация по категориям и динамика
    """
    # 1. Попытка неавторизованного доступа и доступа клиентом
    unauth = client.get("/api/v1/admin/finances/summary")
    assert unauth.status_code == 401

    client_login = client.post("/api/v1/auth/login", json={
        "email": "aigerim@mail.kz",
        "password": "User123!",
    })
    client_token = client_login.json()["access_token"]
    forbidden = client.get("/api/v1/admin/finances/summary", headers={"Authorization": f"Bearer {client_token}"})
    assert forbidden.status_code == 403

    # 2. Логин администратора
    admin_login = client.post("/api/v1/auth/login", json={
        "email": "admin@sapar.kz",
        "password": "Admin123!",
    })
    assert admin_login.status_code == 200
    admin_token = admin_login.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 3. Получение сводного отчёта
    summary_res = client.get("/api/v1/admin/finances/summary?period=all", headers=admin_headers)
    assert summary_res.status_code == 200
    summary = summary_res.json()
    assert "totalIncome" in summary
    assert "totalExpense" in summary
    assert "netProfit" in summary
    assert summary["netProfit"] == summary["totalIncome"] - summary["totalExpense"]
    assert "incomeBreakdown" in summary
    assert "expenseBreakdown" in summary
    assert "chartPoints" in summary
    assert "recentTransactions" in summary

    # 4. Добавление записи дохода от рекламы
    initial_income = summary["totalIncome"]
    ad_res = client.post("/api/v1/admin/finances/records", headers=admin_headers, json={
        "type": "income",
        "category": "advertising",
        "amount": 250000,
        "title": "Спонсорский баннер: Отель Rixos Borovoe",
        "description": "Рекламный блок на главном экране",
        "referenceId": "AD-BOROVOE-01",
    })
    assert ad_res.status_code == 201
    assert ad_res.json()["amount"] == 250000

    # 5. Проверка обновления сводки после внесения дохода
    updated_summary = client.get("/api/v1/admin/finances/summary", headers=admin_headers).json()
    assert updated_summary["totalIncome"] == initial_income + 250000


def test_tour_promotion_ranking_and_accounting():
    """Тест системы рекламы туров:
    - Покупка продвижения тура агентством
    - Флаг isPromoted и ранжирование выше обычных туров
    - Фиксация оплаты рекламы в финансовом отчёте
    - Отключение продвижения
    """
    # 1. Логин турагентства Turan Travel
    agency_login = client.post("/api/v1/auth/login", json={
        "email": "turan@sapar.kz",
        "password": "Agency123!",
    })
    assert agency_login.status_code == 200
    agency_token = agency_login.json()["access_token"]
    agency_headers = {"Authorization": f"Bearer {agency_token}"}

    # Получаем тур агентства
    tours_res = client.get("/api/v1/tours?agencyId=agn-turan-travel")
    assert tours_res.status_code == 200
    tours = tours_res.json()
    assert len(tours) > 0
    target_tour = tours[-1]  # берём тур, который изначально не в самом топе
    tour_id = target_tour["id"]

    # 2. Покупка рекламного тарифа «Тур недели» (7 дней, 29 000 ₸)
    promote_res = client.post(f"/api/v1/tours/{tour_id}/promote", headers=agency_headers, json={
        "days": 7,
        "tier": "top",
        "paymentMethod": "Kaspi Pay",
    })
    assert promote_res.status_code == 200
    promote_data = promote_res.json()
    assert promote_data["isPromoted"] is True
    assert promote_data["promotionTier"] == "top"
    assert promote_data["amountPaid"] == 29000

    # 3. Проверка ранжирования: проплаченный тур поднимается на 1-е место в выдаче
    all_tours_res = client.get("/api/v1/tours")
    assert all_tours_res.status_code == 200
    all_tours = all_tours_res.json()
    assert all_tours[0]["id"] == tour_id
    assert all_tours[0]["isPromoted"] is True

    # 4. Проверка финансового отчёта админа: сумма 29 000 ₸ учтена в доходах от рекламы
    admin_login = client.post("/api/v1/auth/login", json={
        "email": "admin@sapar.kz",
        "password": "Admin123!",
    })
    admin_token = admin_login.json()["access_token"]
    finances = client.get("/api/v1/admin/finances/summary", headers={"Authorization": f"Bearer {admin_token}"}).json()
    ad_item = next((item for item in finances["incomeBreakdown"] if item["category"] == "advertising"), None)
    assert ad_item is not None
    assert ad_item["amount"] >= 29000

    # 5. Отмена/завершение продвижения
    cancel_res = client.delete(f"/api/v1/tours/{tour_id}/promote", headers=agency_headers)
    assert cancel_res.status_code == 204

    # Проверка, что флаг сбросился
    check_tour = client.get(f"/api/v1/tours/{tour_id}").json()
    assert check_tour["isPromoted"] is False


def test_crm_call_center_and_voip_system():
    """Тест системы обзвона клиентов и турфирм (мини-CRM + IP-телефония)."""
    # 1. Авторизация менеджера агентства (Turan Travel)
    login_res = client.post("/api/v1/auth/login", json={
        "email": "turan@sapar.kz",
        "password": "Agency123!",
    })
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Получение умной очереди обзвона
    queue_res = client.get("/api/v1/crm/calls/queue", headers=headers)
    assert queue_res.status_code == 200
    queue = queue_res.json()
    assert len(queue) >= 1
    first_item = queue[0]
    assert "target_name" in first_item
    assert "target_phone" in first_item
    assert "priority" in first_item

    # 3. Фиксация ручного звонка менеджером (клиент подтвердил тур, но попросил перезвонить)
    call_payload = {
        "target_type": "customer",
        "target_name": "Бауржан Момышев",
        "target_phone": "+7 705 123 45 67",
        "direction": "outbound",
        "status": "callback_needed",
        "duration_seconds": 65,
        "notes": "Уточняет даты отпуска с супругой. Просил перезвонить завтра утром.",
        "telephony_provider": "manual",
    }
    create_res = client.post("/api/v1/crm/calls/logs", json=call_payload, headers=headers)
    assert create_res.status_code == 201
    call_log = create_res.json()
    call_id = call_log["id"]
    assert call_log["target_name"] == "Бауржан Момышев"
    assert call_log["status"] == "callback_needed"
    assert call_log["manager_name"] is not None

    # 4. Обновление статуса звонка после повторного разговора
    patch_res = client.patch(
        f"/api/v1/crm/calls/logs/{call_id}",
        json={
            "status": "successful",
            "notes": "Перезвонили. Клиент подтвердил тур и внёс оплату.",
            "duration_seconds": 140,
        },
        headers=headers,
    )
    assert patch_res.status_code == 200
    patched_call = patch_res.json()
    assert patched_call["status"] == "successful"
    assert patched_call["duration_seconds"] == 140

    # 5. Проверка истории звонков с фильтрацией
    logs_res = client.get("/api/v1/crm/calls/logs?status=successful", headers=headers)
    assert logs_res.status_code == 200
    logs = logs_res.json()
    assert any(log["id"] == call_id for log in logs)

    # 6. Проверка аналитики обзвона (статистика, % дозвона, средняя длительность)
    stats_res = client.get("/api/v1/crm/calls/stats", headers=headers)
    assert stats_res.status_code == 200
    stats = stats_res.json()
    assert stats["total_calls"] >= 1
    assert stats["successful_calls"] >= 1
    assert "answer_rate_pct" in stats
    assert "status_breakdown" in stats

    # 7. Тестовая симуляция автообзвона через IP-телефонию (click-to-call)
    sim_res = client.post(
        "/api/v1/crm/calls/simulate-voip",
        json={
            "target_phone": "+7 701 999 88 77",
            "target_name": "Кайрат Нуртас",
            "target_type": "customer",
            "simulated_outcome": "successful",
            "notes": "Автообзвон SIP: подтверждение трансфера в аэропорт.",
        },
        headers=headers,
    )
    assert sim_res.status_code == 200
    sim_call = sim_res.json()
    assert sim_call["telephony_provider"] == "voip_simulator"
    assert sim_call["recording_url"] is not None
    assert sim_call["duration_seconds"] > 0

    # 8. Приём вебхука от внешней IP-АТС (Mango / Zadarma / Asterisk)
    webhook_res = client.post(
        "/api/v1/crm/calls/webhook",
        json={
            "event": "call_ended",
            "external_call_id": "EXT-PBX-998822",
            "caller_phone": "+7 727 300 11 22",
            "callee_phone": "+7 777 555 12 34",
            "direction": "outbound",
            "status": "successful",
            "duration_seconds": 185,
            "recording_url": "https://storage.sapar.travel/recordings/ext-998822.mp3",
            "provider": "mango_telecom",
        },
    )
    assert webhook_res.status_code == 200
    webhook_data = webhook_res.json()
    assert webhook_data["status"] == "created"
    assert "call_id" in webhook_data


def test_tickets_search_and_booking_flow():
    """Тест модуля билетов: поиск авиа и ЖД рейсов, фильтры, бронирование и получение билетов."""
    # 1. Популярные города
    cities_res = client.get("/api/v1/tickets/cities")
    assert cities_res.status_code == 200
    cities = cities_res.json()
    assert len(cities) >= 5
    city_names = [c["city"] for c in cities]
    assert "Алматы" in city_names
    assert "Астана" in city_names

    # 2. Поиск всех билетов
    search_all = client.get("/api/v1/tickets/search")
    assert search_all.status_code == 200
    all_tickets = search_all.json()
    assert len(all_tickets) >= 5

    # 3. Фильтрация только по авиарейсам
    flights_res = client.get("/api/v1/tickets/search?transport_type=flight&departure_city=Алматы")
    assert flights_res.status_code == 200
    flights = flights_res.json()
    assert len(flights) >= 1
    for f in flights:
        assert f["transport_type"] == "flight"
        assert "Алматы" in f["departure_city"]

    # 4. Фильтрация только по поездам (ЖД)
    trains_res = client.get("/api/v1/tickets/search?transport_type=train")
    assert trains_res.status_code == 200
    trains = trains_res.json()
    assert len(trains) >= 1
    for t in trains:
        assert t["transport_type"] == "train"

    # 5. Оформление и покупка билета
    target_flight = flights[0]
    initial_seats = target_flight["available_seats"]

    book_res = client.post("/api/v1/tickets/book", json={
        "flight_id": target_flight["id"],
        "customer_name": "Касымхан Жандосов",
        "customer_phone": "+7 701 333 44 55",
        "customer_email": "kasymkhan@sapar.kz",
        "document_number": "990102300456",
        "passengers_count": 2,
        "payment_method": "Kaspi Pay",
    })
    assert book_res.status_code == 201
    booking = book_res.json()
    assert booking["customer_name"] == "Касымхан Жандосов"
    assert booking["passengers_count"] == 2
    assert booking["total_price"] == target_flight["price"] * 2
    assert "ticket_number" in booking
    assert "seat_numbers" in booking

    # Проверка списания мест
    updated_flight_res = client.get(f"/api/v1/tickets/{target_flight['id']}")
    assert updated_flight_res.status_code == 200
    assert updated_flight_res.json()["available_seats"] == initial_seats - 2

    # 6. Получение списка моих купленных билетов
    my_tickets = client.get("/api/v1/tickets/bookings/me?email=kasymkhan@sapar.kz")
    assert my_tickets.status_code == 200
    user_bookings = my_tickets.json()
    assert any(b["id"] == booking["id"] for b in user_bookings)


# ==================== ЭПИК 12: КИБЕРБЕЗОПАСНОСТЬ (2FA, XSS, AUDIT) ====================

def test_cybersecurity_totp_rfc6238():
    """Проверка генерации и верификации TOTP по RFC 6238."""
    secret = generate_totp_secret()
    assert len(secret) >= 26
    code = get_totp_code(secret)
    assert len(code) == 6
    assert code.isdigit()
    assert verify_totp_code(secret, code) is True

    wrong_code = "000000" if code != "000000" else "111111"
    assert verify_totp_code(secret, wrong_code) is False

    uri = get_totp_uri(secret, "admin@sapar.kz", "Sapar")
    assert uri.startswith("otpauth://totp/Sapar:admin%40sapar.kz?")
    assert f"secret={secret}" in uri


def test_cybersecurity_pii_masking():
    """Проверка маскирования персональных данных (PII)."""
    assert mask_email("abylhair.123@gmail.com") == "a***3@gmail.com"
    assert mask_phone("+7 777 123 4567") == "+7 *** *** 67"
    assert mask_card_number("4400 1234 5678 9012") == "**** **** **** 9012"


def test_cybersecurity_headers():
    """Проверка наличия стандартизированных OWASP HTTP заголовков безопасности."""
    res = client.get("/health")
    assert res.status_code == 200
    headers = res.headers
    assert "Strict-Transport-Security" in headers
    assert "X-Content-Type-Options" in headers
    assert headers["X-Content-Type-Options"] == "nosniff"
    assert "X-Frame-Options" in headers
    assert headers["X-Frame-Options"] == "DENY"
    assert "X-XSS-Protection" in headers
    assert "Content-Security-Policy" in headers


def test_cybersecurity_xss_sanitization():
    """Проверка нейтрализации XSS тегов в теле JSON-запросов."""
    payload = {
        "email": "xss_safe_user_test@sapar.kz",
        "password": "Password123!",
        "fullName": "Алихан <script>alert('XSS Attack')</script> Омаров",
        "phone": "+7 701 999 8877",
        "role": "client",
    }
    res = client.post("/api/v1/auth/register", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert "<script>" not in data["full_name"]
    assert "alert('XSS Attack')" not in data["full_name"]
    assert "Алихан  Омаров" in data["full_name"]


def test_cybersecurity_2fa_full_lifecycle():
    """Полный цикл: логин -> 2FA setup -> verify -> login с 2FA -> disable."""
    # 1. Логин как админ
    login_res = client.post("/api/v1/auth/login", json={"email": "admin@sapar.kz", "password": "Admin123!"})
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    auth_headers = {"Authorization": f"Bearer {token}"}

    # 2. Проверка статуса 2FA
    status_res = client.get("/api/v1/auth/2fa/status", headers=auth_headers)
    assert status_res.status_code == 200
    assert status_res.json()["is_2fa_enabled"] is False
    assert status_res.json()["is_required_for_role"] is True

    # 3. Настройка 2FA: генерация секрета и резервных кодов
    setup_res = client.post("/api/v1/auth/2fa/setup", headers=auth_headers)
    assert setup_res.status_code == 200
    setup_data = setup_res.json()
    totp_secret = setup_data["secret"]
    backup_codes = setup_data["backup_codes"]
    assert len(backup_codes) == 8

    # 4. Попытка подтверждения с неверным кодом
    bad_verify = client.post("/api/v1/auth/2fa/verify", json={"code": "000000"}, headers=auth_headers)
    assert bad_verify.status_code == 400

    # 5. Подтверждение с валидным TOTP кодом
    valid_code = get_totp_code(totp_secret)
    good_verify = client.post("/api/v1/auth/2fa/verify", json={"code": valid_code}, headers=auth_headers)
    assert good_verify.status_code == 200
    assert good_verify.json()["is_2fa_enabled"] is True

    # 6. Теперь логин требует 2FA!
    login_2fa_prompt = client.post("/api/v1/auth/login", json={"email": "admin@sapar.kz", "password": "Admin123!"})
    assert login_2fa_prompt.status_code == 200
    prompt_data = login_2fa_prompt.json()
    assert prompt_data["status"] == "2fa_required"
    temp_token = prompt_data["temp_token"]

    # 7. Попытка подтверждения входа неверным кодом
    bad_login_verify = client.post("/api/v1/auth/2fa/login-verify", json={"temp_token": temp_token, "code": "999999"})
    assert bad_login_verify.status_code == 400

    # 8. Успешный вход по TOTP коду
    current_code = get_totp_code(totp_secret)
    good_login_verify = client.post("/api/v1/auth/2fa/login-verify", json={"temp_token": temp_token, "code": current_code})
    assert good_login_verify.status_code == 200
    admin_new_token = good_login_verify.json()["access_token"]
    new_headers = {"Authorization": f"Bearer {admin_new_token}"}

    # 9. Проверка входа по резервному коду восстановления
    login_prompt_2 = client.post("/api/v1/auth/login", json={"email": "admin@sapar.kz", "password": "Admin123!"})
    temp_token_2 = login_prompt_2.json()["temp_token"]
    backup_code_to_use = backup_codes[0]
    backup_login = client.post("/api/v1/auth/2fa/login-verify", json={"temp_token": temp_token_2, "code": backup_code_to_use})
    assert backup_login.status_code == 200

    # Использованный резервный код нельзя применить второй раз
    login_prompt_3 = client.post("/api/v1/auth/login", json={"email": "admin@sapar.kz", "password": "Admin123!"})
    temp_token_3 = login_prompt_3.json()["temp_token"]
    reuse_backup = client.post("/api/v1/auth/2fa/login-verify", json={"temp_token": temp_token_3, "code": backup_code_to_use})
    assert reuse_backup.status_code == 400

    # 10. Отключение 2FA с проверкой пароля
    disable_res = client.post("/api/v1/auth/2fa/disable", json={"password": "Admin123!"}, headers=new_headers)
    assert disable_res.status_code == 200
    assert disable_res.json()["is_2fa_enabled"] is False

    # После отключения вход снова прямой
    direct_login = client.post("/api/v1/auth/login", json={"email": "admin@sapar.kz", "password": "Admin123!"})
    assert "access_token" in direct_login.json()


def test_cybersecurity_admin_audit_logs():
    """Проверка эндпоинта журнала аудита безопасности."""
    login_res = client.post("/api/v1/auth/login", json={"email": "admin@sapar.kz", "password": "Admin123!"})
    token = login_res.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {token}"}

    res = client.get("/api/v1/admin/audit-logs", headers=admin_headers)
    assert res.status_code == 200
    data = res.json()
    assert "items" in data
    assert data["total"] >= 1
    first_item = data["items"][0]
    assert "action" in first_item
    assert "createdAt" in first_item
    assert "status" in first_item


# ==================== ЭПИК 4: ПОЛНЫЙ НАБОР B2B-ЭНДПОИНТОВ ДЛЯ ТУРФИРМ ====================

def test_agency_b2b_portal_full_endpoints():
    """Тест полного набора B2B-эндпоинтов для десктоп-портала:
    - Профиль компании и реквизиты (GET/PUT /agencies/me/profile)
    - Управление каталогом туров (POST/PUT/DELETE /agencies/me/tours)
    - Управление бронированиями и статусами (PATCH /agencies/me/bookings/{id}/status)
    - Финансовый баланс, комиссия 10% и заявка на выплату (GET /agencies/me/finances, POST /agencies/me/payout-request)
    """
    # 1. Логин как менеджер турагентства
    login_res = client.post("/api/v1/auth/login", json={"email": "turan@sapar.kz", "password": "Agency123!"})
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    agency_headers = {"Authorization": f"Bearer {token}"}

    # 2. Получение и обновление реквизитов агентства
    profile_res = client.get("/api/v1/agencies/me/profile", headers=agency_headers)
    assert profile_res.status_code == 200
    profile_data = profile_res.json()
    assert "id" in profile_data

    update_payload = {
        "binIin": "990102300456",
        "legalAddress": "г. Алматы, пр. Достык, 180, офис 401",
        "bankName": "Kaspi Bank",
        "bankIban": "KZ123456789012345678",
        "bankBic": "CASPKZKA",
        "contactPerson": "Арман Касымов",
        "phone": "+7 701 555 1234",
    }
    put_res = client.put("/api/v1/agencies/me/profile", json=update_payload, headers=agency_headers)
    assert put_res.status_code == 200
    updated_profile = put_res.json()
    assert updated_profile["binIin"] == "990102300456"
    assert updated_profile["bankIban"] == "KZ123456789012345678"

    # 3. Создание нового тура агентством
    new_tour_payload = {
        "title": "B2B Эксклюзив: Бодрум Премиум 5★",
        "destination": "Бодрум, Турция",
        "category": "beach",
        "nights": "8 ночей",
        "durationNights": 8,
        "dates": "15.07 - 23.07",
        "meal": "Ultra All Inclusive",
        "hotelStars": 5,
        "beachLine": 1,
        "departureCity": "Алматы",
        "priceFrom": 490000,
        "seatsLeft": 15,
        "description": "Эксклюзивный тур для семейного отдыха",
    }
    create_tour_res = client.post("/api/v1/agencies/me/tours", json=new_tour_payload, headers=agency_headers)
    assert create_tour_res.status_code == 201
    created_tour = create_tour_res.json()
    tour_id = created_tour["id"]
    assert created_tour["title"] == new_tour_payload["title"]
    assert created_tour["priceFrom"] == 490000

    # 4. Редактирование тура
    edit_tour_res = client.put(f"/api/v1/agencies/me/tours/{tour_id}", json={"priceFrom": 465000, "seatsLeft": 12}, headers=agency_headers)
    assert edit_tour_res.status_code == 200
    assert edit_tour_res.json()["priceFrom"] == 465000
    assert edit_tour_res.json()["seatsLeft"] == 12

    # 5. Получение бронирований агентства
    bookings_res = client.get("/api/v1/agencies/me/bookings", headers=agency_headers)
    assert bookings_res.status_code == 200
    bookings = bookings_res.json()
    if len(bookings) > 0:
        target_booking = bookings[0]
        # 6. Смена статуса бронирования
        patch_res = client.patch(
            f"/api/v1/agencies/me/bookings/{target_booking['id']}/status",
            json={"status": "confirmed", "note": "Бронь подтверждена отелем"},
            headers=agency_headers,
        )
        assert patch_res.status_code == 200
        assert patch_res.json()["status"] == "confirmed"

    # 7. Финансовый баланс агентства (10% комиссия)
    fin_res = client.get("/api/v1/agencies/me/finances", headers=agency_headers)
    assert fin_res.status_code == 200
    fin_data = fin_res.json()
    assert "totalSalesKzt" in fin_data
    assert "commissionRate" in fin_data
    assert fin_data["commissionRate"] == 0.10
    assert "totalCommissionEarned" in fin_data
    assert "availableBalanceKzt" in fin_data

    # 8. Заявка на вывод средств (если есть доступный баланс)
    avail = fin_data["availableBalanceKzt"]
    if avail > 1000:
        payout_amount = min(50000, avail)
        payout_res = client.post("/api/v1/agencies/me/payout-request", json={
            "amount": payout_amount,
            "iban": "KZ123456789012345678",
            "bankName": "Kaspi Bank",
            "comment": "Выплата комиссии за октябрь",
        }, headers=agency_headers)
        assert payout_res.status_code == 201
        payout_data = payout_res.json()
        assert payout_data["amount"] == payout_amount
        assert payout_data["status"] == "pending"

    # 9. Удаление созданного тура
    del_res = client.delete(f"/api/v1/agencies/me/tours/{tour_id}", headers=agency_headers)
    assert del_res.status_code == 204










