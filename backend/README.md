# Sapar Backend API 🚀

REST API бэкенд для маркетплейса турагентств **Sapar** (Казахстан).

## Стек технологий
- **FastAPI**: современный асинхронный фреймворк для API
- **SQLAlchemy 2.0**: ORM для работы с базой данных
- **SQLite / PostgreSQL**: поддержка локальной SQLite базы "из коробки" без внешних зависимостей, с возможностью переключения на PostgreSQL
- **Pydantic v2**: валидация и сериализация схем данных
- **JWT (python-jose + passlib)**: безопасная аутентификация и авторизация (роли: `client`, `agency`, `admin`)
- **Pytest + TestClient**: автоматические тесты API

---

## Быстрый старт

### 1. Установка зависимостей
```bash
cd backend
pip install -r requirements.txt
```

### 2. Запуск сервера разработки
```bash
python run.py
```
или через uvicorn:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

> **Примечание:** База данных SQLite (`sapar.db`) создается автоматически при первом запуске и наполняется начальными данными (туры, турагентства, категории, тестовые учетные записи).

### 3. Интерактивная документация Swagger
После запуска перейдите по адресу:
- Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)
- ReDoc: [http://localhost:8000/redoc](http://localhost:8000/redoc)

---

## Тестовые учетные записи (Seed Data)

| Email | Пароль | Роль | Описание |
|---|---|---|---|
| `admin@sapar.kz` | `Admin123!` | `admin` | Администратор платформы |
| `turan@sapar.kz` | `Agency123!` | `agency` | Агентство «Turan Travel» |
| `voyage@sapar.kz` | `Agency123!` | `agency` | Агентство «Voyage Asia» |
| `aigerim@mail.kz` | `User123!` | `client` | Клиент Айгерим Сериковна |

---

## Основные эндпоинты

### 🏖️ Туры (`/api/v1/tours`)
- `GET /api/v1/tours` — получение каталога туров с фильтрацией:
  - `category` (например, `Пляжный отдых`, `Горы`, `Визовые туры`, `Санатории`, `Круизы`)
  - `search` (поиск по названию, направлению, описанию или агентству)
  - `departureCity` (город вылета, например `Алматы`)
  - `minPrice` / `maxPrice`
- `GET /api/v1/tours/categories` — список категорий с количеством активных туров
- `GET /api/v1/tours/{id}` — детальная информация о туре
- `POST /api/v1/tours` — добавление нового тура (для агентств и админов)
- `PUT /api/v1/tours/{id}` — обновление тура
- `DELETE /api/v1/tours/{id}` — деактивация/удаление тура

### 📋 Бронирования (`/api/v1/bookings`)
- `POST /api/v1/bookings` — создание бронирования (с расчетом цены, сервисного сбора 9 800 ₸ и общей суммы)
- `GET /api/v1/bookings` — список бронирований (с фильтрацией по email/телефону или текущему пользователю/агентству)
- `GET /api/v1/bookings/{id}` — детали бронирования
- `PATCH /api/v1/bookings/{id}/status` — обновление статуса (`pending`, `confirmed`, `paid`, `cancelled`)

### 🏢 Турагентства (`/api/v1/agencies`)
- `GET /api/v1/agencies` — список проверенных агентств
- `GET /api/v1/agencies/{id}` — профиль агентства
- `PATCH /api/v1/agencies/{id}` — редактирование данных агентства

### ⭐ Отзывы (`/api/v1/reviews`)
- `GET /api/v1/reviews/tours/{tour_id}` — отзывы к туру
- `POST /api/v1/reviews/tours/{tour_id}` — добавление отзыва с пересчетом рейтинга

### 🔐 Авторизация (`/api/v1/auth`)
- `POST /api/v1/auth/register` — регистрация клиента или турагентства
- `POST /api/v1/auth/login` — вход по email и паролю (возвращает JWT Bearer token)
- `GET /api/v1/auth/me` — профиль текущего пользователя

---

## Запуск тестов
```bash
python -m pytest tests -v
```

## Запуск через Docker
```bash
docker compose up --build
```
