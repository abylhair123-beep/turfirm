import logging
from sqlalchemy.orm import Session

from app.agencies.models import Agency
from app.auth.models import User
from app.bookings.models import Booking
from app.core.security import get_password_hash
from app.database import Base, SessionLocal, engine
from app.reviews.models import Review
from app.tours.models import Tour

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def seed_data(db: Session) -> None:
    # 1. Check if already seeded
    if db.query(Tour).first():
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
            dates="12–19 окт",
            meal="Всё вкл.",
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
            dates="18–23 окт",
            meal="Завтраки",
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
            dates="24–28 окт",
            meal="Завтраки",
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
            dates="05–12 ноя",
            meal="Завтраки",
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
            dates="10–20 окт",
            meal="3-разовое",
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
            dates="15–22 ноя",
            meal="Всё вкл.",
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
    logger.info("Successfully seeded Sapar database!")


if __name__ == "__main__":
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_data(db)
    finally:
        db.close()
