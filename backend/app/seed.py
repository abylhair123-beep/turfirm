import logging
import re
from datetime import datetime, timedelta, timezone

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.agencies.models import Agency
from app.auth.models import User
from app.bookings.models import Booking
from app.core.cache import cache
from app.core.security import get_password_hash
from app.crm.models import CallLog
from app.database import Base, SessionLocal, engine
from app.favorites.models import Favorite
from app.payments.models import Payment
from app.promo.models import PromoCode
from app.referrals.models import ReferralPartner
from app.reviews.models import Review
from app.tours.models import Tour

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Маркетинговые колонки, добавленные после первого релиза. Для БД, созданных
# раньше, доращиваем таблицу на старте (create_all новые колонки не добавляет).
_MARKETING_COLUMNS = {
    "old_price": "INTEGER",
    "is_hot": "BOOLEAN DEFAULT FALSE NOT NULL",
    "hot_until": "TIMESTAMP",
    "seats_left": "INTEGER",
    "installment_months": "INTEGER DEFAULT 12 NOT NULL",
    "max_guests": "INTEGER DEFAULT 4 NOT NULL",
    "children_allowed": "BOOLEAN DEFAULT TRUE NOT NULL",
    "amenity_tags": "JSON DEFAULT '[]' NOT NULL",
    "hotel_name": "VARCHAR(255)",
    "hotel_stars": "INTEGER",
    "hotel_description": "TEXT",
    "hotel_photos": "JSON DEFAULT '[]' NOT NULL",
    "hotel_amenities": "JSON DEFAULT '{}' NOT NULL",
}


def ensure_marketing_schema(db: Session) -> None:
    """Idempotent: добавляет маркетинговые колонки в таблицу tours (PostgreSQL)."""
    bind = db.get_bind()
    if bind.dialect.name != "postgresql":
        return  # для sqlite таблица создаётся целиком через create_all
    for col, ddl in _MARKETING_COLUMNS.items():
        db.execute(text(f"ALTER TABLE tours ADD COLUMN IF NOT EXISTS {col} {ddl}"))
    db.commit()


def apply_demo_marketing(db: Session) -> None:
    """Проставляет демо-скидки, «горящие» туры и рассрочку.
    Idempotent: не трогает данные, если разметка уже есть."""
    tours = db.query(Tour).all()
    if not tours:
        return
    if any(t.old_price for t in tours) or any(t.is_hot for t in tours):
        return  # уже размечено

    now = datetime.now(timezone.utc)
    demo = {
        "dubai-5n": dict(old_price=459000, is_hot=True, hot_until=now + timedelta(days=2), seats_left=3),
        "antalya-7n": dict(old_price=289000, seats_left=5),
        "italy-visa-7n": dict(old_price=599000, is_hot=True, hot_until=now + timedelta(days=1, hours=6), seats_left=2),
    }
    for t in tours:
        if not t.installment_months:
            t.installment_months = 12
        for key, val in demo.get(t.id, {}).items():
            setattr(t, key, val)
    db.commit()


def apply_demo_catalog(db: Session) -> None:
    """Проставляет демо-вместимость, теги удобств и карточки отелей.
    Idempotent: пропускает, если теги уже заданы."""
    tours = db.query(Tour).all()
    if not tours or any(t.amenity_tags for t in tours):
        return

    rich = {
        "dubai-5n": dict(
            amenity_tags=["all_inclusive", "beach_first_line", "pool", "wifi", "spa", "kids_club"],
            max_guests=5,
            hotel_name="Dubai Marina Resort 5★", hotel_stars=5,
            hotel_description="Роскошный отель на первой линии с собственным пляжем, тремя бассейнами и детским клубом. 10 минут до Dubai Mall.",
            hotel_photos=[
                "https://images.unsplash.com/photo-1512453979798-5ea266f8880c",
                "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b",
            ],
            hotel_amenities={
                "Для детей": ["Детский клуб 4–12 лет", "Бассейн-лягушатник", "Детское меню", "Няня по запросу"],
                "Пляж и бассейн": ["Первая линия", "3 бассейна", "Аквапарк", "Лежаки бесплатно"],
                "Питание": ["Всё включено 24/7", "A la carte рестораны", "Бары у бассейна"],
                "Сервис": ["Wi-Fi на территории", "Трансфер", "СПА и хаммам", "Фитнес-зал"],
            },
        ),
        "antalya-7n": dict(
            amenity_tags=["all_inclusive", "beach_first_line", "pool", "wifi", "kids_club"],
            max_guests=4,
            hotel_name="Antalya Beach Hotel 4★", hotel_stars=4,
            hotel_description="Семейный отель 4★ на первой линии с анимацией и аквапарком. 12 минут от аэропорта Антальи.",
            hotel_photos=["https://images.unsplash.com/photo-1542314831-068cd1dbfeeb"],
            hotel_amenities={
                "Для детей": ["Мини-клуб", "Горки в аквапарке", "Детское меню"],
                "Пляж и бассейн": ["Первая линия", "2 бассейна", "Аквапарк"],
                "Питание": ["Всё включено", "Шведский стол"],
                "Сервис": ["Wi-Fi", "Анимация", "Трансфер"],
            },
        ),
        "italy-visa-7n": dict(
            amenity_tags=["city_center", "breakfast", "wifi"],
            max_guests=3, children_allowed=False,
            hotel_name="Hotel Roma Centro 4★", hotel_stars=4,
            hotel_description="Бутик-отель в центре Рима, 5 минут пешком до Колизея. Завтрак на террасе с видом на город.",
            hotel_photos=["https://images.unsplash.com/photo-1552832230-c0197dd311b5"],
            hotel_amenities={
                "Расположение": ["Центр города", "5 мин до Колизея", "Рядом метро"],
                "Питание": ["Завтрак включён", "Бар на крыше"],
                "Сервис": ["Wi-Fi", "Экскурсии", "Трансфер по запросу"],
            },
        ),
    }

    for t in tours:
        if not t.max_guests:
            t.max_guests = 4
        if t.id in rich:
            for key, val in rich[t.id].items():
                setattr(t, key, val)
        else:
            tags = ["wifi"]
            if "включ" in (t.meal or "").lower():
                tags.append("all_inclusive")
            t.amenity_tags = tags
    db.commit()


def _guess_stars(tour: Tour) -> int:
    text_blob = " ".join(tour.included or []) + " " + (tour.description or "")
    m = re.search(r"(\d)\s*★", text_blob)
    if m:
        return int(m.group(1))
    m = re.search(r"(\d)\s*(?:звезд|star)", text_blob, re.IGNORECASE)
    if m:
        return int(m.group(1))
    return 4


def apply_demo_hotels(db: Session) -> None:
    """Для туров без карточки отеля генерируем её из имеющихся данных,
    чтобы блок «Об отеле» показывался у всех туров. Idempotent: не трогает
    туры, у которых hotel_name уже заполнено (например, вручную агентством)."""
    tours = db.query(Tour).all()
    changed = False
    for t in tours:
        if t.hotel_name:
            continue  # карточка уже есть — не перезаписываем

        base = t.destination.split(",")[0].split("&")[0].strip()
        stars = _guess_stars(t)
        t.hotel_name = f"{base} · Отель {stars}★"
        t.hotel_stars = stars
        t.hotel_description = t.description
        if t.photo_url:
            t.hotel_photos = [t.photo_url]
        amenities: dict = {}
        if t.included:
            amenities["Включено в тур"] = list(t.included)
        if t.meal:
            amenities["Питание"] = [t.meal]
        amenities["Расположение"] = [t.destination]
        t.hotel_amenities = amenities
        changed = True

    if changed:
        db.commit()


def seed_promo_codes(db: Session) -> None:
    """Idempotent: добавляет демо-промокоды, если их ещё нет."""
    if db.query(PromoCode).first():
        return
    now = datetime.now(timezone.utc)
    db.add_all([
        PromoCode(code="SAPAR10", discount_percent=10, description="−10% на первый заказ"),
        PromoCode(code="HOT15", discount_percent=15, description="−15% на горящие туры",
                  expires_at=now + timedelta(days=30)),
        PromoCode(code="JUMA5", discount_percent=5, description="Kaspi Juma −5%"),
    ])
    db.commit()


def seed_data(db: Session) -> None:
    # 0. Доращиваем схему и демо-разметку для уже существующих БД
    ensure_marketing_schema(db)
    seed_promo_codes(db)

    # 1. Check if already seeded
    if db.query(Tour).first():
        apply_demo_marketing(db)
        apply_demo_catalog(db)
        apply_demo_hotels(db)
        cache.delete_pattern("sapar:cache:tours:*")  # сбросить устаревший кэш каталога
        logger.info("Database already seeded. Skipping.")
        return

    logger.info("Seeding database with initial Sapar platform data...")

    # 2. Users
    admin_user = User(
        id="usr-admin-1",
        email="admin@sapar.kz",
        hashed_password=get_password_hash("Admin123!"),
        full_name="Администратор Sapar",
        phone="+7 777 000 00 00",
        role="admin",
    )
    turan_user = User(
        id="usr-agency-1",
        email="turan@sapar.kz",
        hashed_password=get_password_hash("Agency123!"),
        full_name="Turan Travel Admin",
        phone="+7 701 111 22 33",
        role="agency",
    )
    voyage_user = User(
        id="usr-agency-2",
        email="voyage@sapar.kz",
        hashed_password=get_password_hash("Agency123!"),
        full_name="Voyage Asia Admin",
        phone="+7 702 333 44 55",
        role="agency",
    )
    client_user = User(
        id="usr-client-1",
        email="aigerim@mail.kz",
        hashed_password=get_password_hash("User123!"),
        full_name="Айгерим Сериковна",
        phone="+7 701 234 56 78",
        role="client",
    )

    db.add_all([admin_user, turan_user, voyage_user, client_user])
    db.flush()

    # 3. Agencies
    agency_turan = Agency(
        id="agn-turan-travel",
        name="Turan Travel",
        slug="turan-travel",
        verified=True,
        phone="+7 701 111 22 33",
        email="info@turantravel.kz",
        address="г. Алматы, пр. Достык, 180",
        description="Ведущее турагентство Казахстана по направлениям Турции, Египта и Европы.",
        rating=4.8,
        reviews_count=213,
        user_id=turan_user.id,
    )
    agency_voyage = Agency(
        id="agn-voyage-asia",
        name="Voyage Asia",
        slug="voyage-asia",
        verified=True,
        phone="+7 702 333 44 55",
        email="book@voyageasia.kz",
        address="г. Алматы, пр. Аль-Фараби, 77/7",
        description="Премиальные туры в ОАЭ, страны Персидского залива и Юго-Восточной Азии.",
        rating=4.9,
        reviews_count=98,
        user_id=voyage_user.id,
    )
    agency_nomad = Agency(
        id="agn-nomad-explore",
        name="Nomad Explore",
        slug="nomad-explore",
        verified=True,
        phone="+7 705 555 66 77",
        email="hello@nomadexplore.kz",
        address="г. Астана, ул. Достык, 5",
        description="Эксперты по горным турам, круизам и внутреннему туризму Казахстана.",
        rating=4.9,
        reviews_count=142,
    )

    db.add_all([agency_turan, agency_voyage, agency_nomad])
    db.flush()

    # 4. Tours (Includes Flutter mock data exact IDs and fields)
    tours = [
        Tour(
            id="antalya-7n",
            agency_id=agency_turan.id,
            agency_name=agency_turan.name,
            agency_verified=True,
            destination="Анталия, Турция",
            title="Тур в Анталию",
            category="Пляжный отдых",
            nights="7 ночей",
            duration_nights=7,
            dates="12–19 окт",
            meal="Всё вкл.",
            meal_type="AI",
            hotel_stars=4,
            beach_line=1,
            departure_city="Алматы",
            meta="7 ночей · вылет 12 окт · всё включено",
            rating=4.8,
            reviews_count=213,
            price_from=245000,
            photo_color="0xFF0E7C77",
            photo_url="https://images.unsplash.com/photo-1542314831-068cd1dbfeeb",
            description=(
                "Отель 4★ на первой линии с собственным пляжем, бассейном и вечерней "
                "анимацией. Идеально для семейного отдыха и пар — 12 минут от "
                "аэропорта Антальи."
            ),
            included=[
                "Перелёт туда–обратно",
                "Отель 4★, всё включено",
                "Трансфер аэропорт–отель",
                "Медицинская страховка",
            ],
            is_active=True,
        ),
        Tour(
            id="dubai-5n",
            agency_id=agency_voyage.id,
            agency_name=agency_voyage.name,
            agency_verified=True,
            destination="Дубай, ОАЭ",
            title="Дубай Delight",
            category="Пляжный отдых",
            nights="5 ночей",
            duration_nights=5,
            dates="18–23 окт",
            meal="Завтраки",
            meal_type="BB",
            hotel_stars=5,
            beach_line=2,
            departure_city="Алматы",
            meta="5 ночей · вылет 18 окт · завтраки",
            rating=4.9,
            reviews_count=98,
            price_from=398000,
            photo_color="0xFFFF6F59",
            photo_url="https://images.unsplash.com/photo-1512453979798-5ea266f8880c",
            description=(
                "Отель 5★ в центре Дубая, вид на Бурдж-Халифа, шаттл до пляжа "
                "каждый час. Подходит для первой поездки в ОАЭ."
            ),
            included=[
                "Перелёт туда–обратно",
                "Отель 5★, завтраки",
                "Трансфер аэропорт–отель",
                "Медицинская страховка",
            ],
            is_active=True,
        ),
        Tour(
            id="shymbulak-mountains-4n",
            agency_id=agency_nomad.id,
            agency_name=agency_nomad.name,
            agency_verified=True,
            destination="Шымбулак & Медеу, Алматы",
            title="Горный уикенд на Шымбулаке",
            category="Горы",
            nights="4 ночи",
            duration_nights=4,
            dates="24–28 окт",
            meal="Завтраки",
            meal_type="BB",
            hotel_stars=4,
            beach_line=0,
            departure_city="Алматы",
            meta="4 ночи · вылет 24 окт · спа-отель",
            rating=4.9,
            reviews_count=87,
            price_from=125000,
            photo_color="0xFF2E7D32",
            photo_url="https://images.unsplash.com/photo-1464822759023-fed622ff2c3b",
            description=(
                "Уютный эко-отель в горах Заилийского Алатау. Ски-пассы на канатную дорогу, "
                "термальные бассейны и чистейший горный воздух."
            ),
            included=[
                "Проживание в шале 4★",
                "Завтраки шведский стол",
                "Ски-пасс на 3 дня",
                "Трансфер из аэропорта/города",
            ],
            is_active=True,
        ),
        Tour(
            id="italy-visa-7n",
            agency_id=agency_turan.id,
            agency_name=agency_turan.name,
            agency_verified=True,
            destination="Рим & Флоренция, Италия",
            title="Гранд-тур по Италии",
            category="Визовые туры",
            nights="7 ночей",
            duration_nights=7,
            dates="05–12 ноя",
            meal="Завтраки",
            meal_type="BB",
            hotel_stars=4,
            beach_line=0,
            departure_city="Алматы",
            meta="7 ночей · вылет 5 ноя · визовая помощь",
            rating=4.7,
            reviews_count=64,
            price_from=520000,
            photo_color="0xFF8E24AA",
            photo_url="https://images.unsplash.com/photo-1552832230-c0197dd311b5",
            description=(
                "Классический маршрут Рим — Ватикан — Флоренция. Полное визовое "
                "сопровождение через аккредитованное агентство."
            ),
            included=[
                "Визовая поддержка и запись",
                "Перелёт с пересадкой",
                "Отели 4★ в центре",
                "Билеты на скоростной поезд Frecciarossa",
                "Экскурсии с гидом",
            ],
            is_active=True,
        ),
        Tour(
            id="saryagash-sanatorium-10n",
            agency_id=agency_nomad.id,
            agency_name=agency_nomad.name,
            agency_verified=True,
            destination="Сарыагаш, Казахстан",
            title="Оздоровительный тур в Сарыагаш",
            category="Санатории",
            nights="10 ночей",
            duration_nights=10,
            dates="10–20 окт",
            meal="3-разовое",
            meal_type="FB",
            hotel_stars=4,
            beach_line=0,
            departure_city="Шымкент",
            meta="10 ночей · выезд 10 окт · полный пансион",
            rating=4.8,
            reviews_count=115,
            price_from=185000,
            photo_color="0xFF00897B",
            photo_url="https://images.unsplash.com/photo-1540555700478-4be289fbecef",
            description=(
                "Санаторий премиум-класса с минеральными водами Сарыагаш, "
                "комплексом лечебных процедур, бассейном и физиотерапией."
            ),
            included=[
                "3-разовое диетическое питание",
                "Консультация врача и курс процедур",
                "Бассейн, сауна, фитобар",
                "Трансфер от вокзала/аэропорта Шымкента",
            ],
            is_active=True,
        ),
        Tour(
            id="mediterranean-cruise-7n",
            agency_id=agency_voyage.id,
            agency_name=agency_voyage.name,
            agency_verified=True,
            destination="Барселона — Рим — Марсель",
            title="Круиз по Средиземному морю",
            category="Круизы",
            nights="7 ночей",
            duration_nights=7,
            dates="15–22 ноя",
            meal="Всё вкл.",
            meal_type="UAI",
            hotel_stars=5,
            beach_line=1,
            departure_city="Алматы",
            meta="7 ночей · вылет 15 ноя · лайнер 5★",
            rating=4.9,
            reviews_count=42,
            price_from=670000,
            photo_color="0xFF1E88E5",
            photo_url="https://images.unsplash.com/photo-1548574505-5e239809ee19",
            description=(
                "Путешествие на флагманском круизном лайнере MSC с посещением "
                "Испании, Франции и Италии. Бассейны, бродвейские шоу и рестораны мирового уровня."
            ),
            included=[
                "Авиаперелёт до Барселоны и обратно",
                "Каюта с балконом на лайнере",
                "Питание «Ультра всё включено»",
                "Портовые сборы и чаевые",
            ],
            is_active=True,
        ),
    ]

    db.add_all(tours)
    db.flush()

    # 5. Reviews
    rev1 = Review(
        tour_id="antalya-7n",
        user_id=client_user.id,
        author_name="Айгерим С.",
        rating=5.0,
        comment="Прекрасный отдых с семьей! Отель отличный, трансфер пунктуальный. Спасибо Turan Travel!",
    )
    rev2 = Review(
        tour_id="dubai-5n",
        user_id=client_user.id,
        author_name="Данияр М.",
        rating=5.0,
        comment="Отель превзошел ожидания, вид на Бурдж-Халифа завораживает. Быстрое бронирование.",
    )
    db.add_all([rev1, rev2])

    # 6. Sample Initial Booking
    sample_booking = Booking(
        id="BK-SAPAR01",
        tour_id="antalya-7n",
        agency_id=agency_turan.id,
        user_id=client_user.id,
        customer_name="Айгерим Сериковна",
        customer_phone="+7 701 234 56 78",
        customer_email="aigerim@mail.kz",
        guests_count=2,
        payment_method="Kaspi Pay",
        tour_price=245000,
        service_fee=9800,
        total_price=499800,
        status="paid",
    )
    db.add(sample_booking)

    db.commit()
    apply_demo_marketing(db)
    apply_demo_catalog(db)
    apply_demo_hotels(db)
    cache.delete_pattern("sapar:cache:tours:*")
    logger.info("Successfully seeded Sapar database!")
    seed_referrals(db)


def seed_referrals(db: Session) -> None:
    """Сидирование реферальных кампаний для блогеров."""
    if db.query(ReferralPartner).first():
        return

    client_user = db.query(User).filter(User.email == "aigerim@mail.kz").first()
    if not client_user:
        return

    logger.info("Seeding initial referral campaigns for blogger...")
    partner1 = ReferralPartner(
        id="ref-partner-1",
        user_id=client_user.id,
        code="TRAVEL_KZ",
        campaign_name="Instagram Stories (@aigerim_travel)",
        commission_rate=3.0,
        fixed_reward=0,
        clicks_count=142,
        bookings_count=6,
        total_earned=44100,
        balance=44100,
        is_active=True,
    )
    partner2 = ReferralPartner(
        id="ref-partner-2",
        user_id=client_user.id,
        code="SAPAR_SPECIAL",
        campaign_name="TikTok / Reels",
        commission_rate=3.0,
        fixed_reward=0,
        clicks_count=85,
        bookings_count=3,
        total_earned=22050,
        balance=22050,
        is_active=True,
    )
    db.add_all([partner1, partner2])
    db.commit()
    seed_crm_calls(db)


def seed_crm_calls(db: Session) -> None:
    """Сидирование логов обзвона и очереди мини-CRM."""
    if db.query(CallLog).first():
        return

    admin_user = db.query(User).filter(User.role == "admin").first()
    manager_id = admin_user.id if admin_user else None

    booking = db.query(Booking).first()
    agency = db.query(Agency).first()

    now = datetime.now(timezone.utc)

    calls = [
        CallLog(
            id="CALL-0001",
            direction="outbound",
            target_type="customer",
            target_name=booking.customer_name if booking else "Айгерим Касымова",
            target_phone=booking.customer_phone if booking else "+7 701 555 12 34",
            booking_id=booking.id if booking else None,
            user_id=booking.user_id if booking else None,
            agency_id=booking.agency_id if booking else None,
            manager_id=manager_id,
            status="successful",
            duration_seconds=138,
            notes="Подтвердили даты вылета и визовые анкеты. Клиентка попросила отель с детским клубом.",
            telephony_provider="mango",
            recording_url="https://storage.sapar.travel/recordings/call-0001.mp3",
            external_call_id="MANGO-90812",
            created_at=now - timedelta(hours=3),
        ),
        CallLog(
            id="CALL-0002",
            direction="outbound",
            target_type="customer",
            target_name="Арман Жумабеков",
            target_phone="+7 777 444 88 99",
            booking_id=booking.id if booking else None,
            manager_id=manager_id,
            status="callback_needed",
            duration_seconds=42,
            notes="На совещании. Попросил перезвонить в 18:30 для согласования медицинского страхования.",
            scheduled_callback_at=now + timedelta(hours=2),
            telephony_provider="manual",
            created_at=now - timedelta(hours=1),
        ),
        CallLog(
            id="CALL-0003",
            direction="outbound",
            target_type="agency",
            target_name=agency.name if agency else "Sapar Travel Almaty",
            target_phone=agency.phone if agency and agency.phone else "+7 727 300 11 22",
            agency_id=agency.id if agency else None,
            manager_id=manager_id,
            status="successful",
            duration_seconds=210,
            notes="Согласовали блок мест на чартер в Шарм-эль-Шейх и агентскую комиссию 12%.",
            telephony_provider="zadarma",
            recording_url="https://storage.sapar.travel/recordings/call-0003.mp3",
            external_call_id="ZADARMA-44102",
            created_at=now - timedelta(minutes=40),
        ),
        CallLog(
            id="CALL-0004",
            direction="outbound",
            target_type="customer",
            target_name="Динара Серикова",
            target_phone="+7 702 333 77 11",
            manager_id=manager_id,
            status="no_answer",
            duration_seconds=0,
            notes="Гудки идут, трубку не взяли. Поставлена задача на повторный звонок через час.",
            telephony_provider="simulator",
            created_at=now - timedelta(minutes=15),
        ),
    ]
    db.add_all(calls)
    db.commit()
    logger.info("Successfully seeded CRM call logs!")


if __name__ == "__main__":
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_data(db)
    finally:
        db.close()
