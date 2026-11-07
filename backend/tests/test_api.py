import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

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



