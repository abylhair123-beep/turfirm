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
    # Check that antalya and dubai tours are present
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
