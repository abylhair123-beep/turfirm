# Sapar — маркетплейс туров от турагентств 🌍

Проект включает в себя:
1. **Клиентское мобильное приложение** на Flutter (`lib/`, `pubspec.yaml`)
2. **Полнофункциональный REST API бэкенд** на FastAPI + SQLAlchemy (`backend/`)

---

## 1. Запуск бэкенда (FastAPI)

Бэкенд находится в папке `backend/`. При первом запуске база данных SQLite автоматически создается и наполняется начальными данными (туры, агентства, категории, тестовые пользователи).

```bash
cd backend
pip install -r requirements.txt
python run.py
```

После старта сервер доступен по адресу:
- API: [http://localhost:8000/api/v1](http://localhost:8000/api/v1)
- Swagger документация: [http://localhost:8000/docs](http://localhost:8000/docs)
- ReDoc: [http://localhost:8000/redoc](http://localhost:8000/redoc)

Тесты бэкенда:
```bash
cd backend
python -m pytest tests -v
```

---

## 2. Запуск клиентского приложения (Flutter)

```bash
flutter pub get
flutter run          # или flutter run -d chrome для Web
```

> **Примечание:** В приложении реализован сервис `ApiService` (`lib/services/api_service.dart`). При запуске на Android эмуляторе он автоматически обращается к `10.0.2.2:8000`, на Web/iOS/Desktop — к `localhost:8000`. При отсутствии связи с сервером приложение плавно переключается на встроенные офлайн-данные.

---

## Структура репозитория

```
turfirm/
├── backend/                  # FastAPI бэкенд
│   ├── app/
│   │   ├── main.py           # Точка входа FastAPI, CORS, middleware
│   │   ├── database.py       # Engine, SessionLocal, Base
│   │   ├── dependencies.py   # JWT авторизация, зависимости
│   │   ├── seed.py           # Начальное заполнение данными
│   │   ├── core/             # Конфигурация, JWT, пароли
│   │   ├── auth/             # Модели, схемы и роуты авторизации
│   │   ├── agencies/         # Модели, схемы и роуты турагентств
│   │   ├── tours/            # Модели, схемы, фильтрация и CRUD туров
│   │   ├── bookings/         # Оформление и управление бронированиями
│   │   └── reviews/          # Отзывы и пересчет рейтинга
│   ├── tests/                # Автотесты (pytest)
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── requirements.txt
│
└── lib/                      # Flutter клиентское приложение
    ├── main.dart             # Точка входа Flutter
    ├── models/
    │   ├── tour.dart         # Модель Tour (fromJson / toJson)
    │   └── booking.dart      # Модели BookingRequest / BookingResult
    ├── services/
    │   └── api_service.dart  # Клиент для связи с бэкендом
    ├── theme/                # Стили, цвета, типографика (Sora + Work Sans)
    ├── widgets/              # UI компоненты (кнопки, карточки туров, иконки)
    └── screens/
        ├── onboarding_screen.dart
        ├── home_screen.dart       # Каталог с поиском и категориями из API
        ├── tour_detail_screen.dart # Детальный экран тура
        ├── booking_screen.dart     # Интерактивное оформление брони в API
        └── success_screen.dart     # Экран успешной оплаты
```

---

## Тестовые аккаунты

| Email | Пароль | Роль | Описание |
|---|---|---|---|
| `admin@sapar.kz` | `Admin123!` | `admin` | Администратор платформы |
| `turan@sapar.kz` | `Agency123!` | `agency` | Агентство «Turan Travel» |
| `voyage@sapar.kz` | `Agency123!` | `agency` | Агентство «Voyage Asia» |
| `aigerim@mail.kz` | `User123!` | `client` | Клиент Айгерим Сериковна |
