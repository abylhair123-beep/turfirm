# 📋 Дорожная карта и статус задач проекта Sapar

> **Проект:** Sapar — маркетплейс туров от турагентств Казахстана  
> **Расположение проекта на компьютере:** `/home/aboka/Desktop/project/sapar` (Рабочий стол -> `project` -> `sapar`)  
> **Стек:** Flutter (клиентское приложение) + FastAPI & SQLAlchemy 2.0 (REST API бэкенд) + SQLite / PostgreSQL  

---

## 🟢 1. ВЫПОЛНЕНО (Наша часть — 100% готово в коде)

| Задача | Статус | Реализация и файлы |
|---|:---:|---|
| **Авторизация и сессия** | ✅ Готово | Экран входа и регистрации ([`lib/screens/auth_screen.dart`](file:///home/aboka/Desktop/project/sapar/lib/screens/auth_screen.dart)), сохранение JWT в `shared_preferences`, автоматическая подстановка данных пользователя при бронировании ([`lib/screens/booking_screen.dart`](file:///home/aboka/Desktop/project/sapar/lib/screens/booking_screen.dart)). |
| **Экран «Мои бронирования»** | ✅ Готово | Экран списка поездок ([`lib/screens/bookings_list_screen.dart`](file:///home/aboka/Desktop/project/sapar/lib/screens/bookings_list_screen.dart)), получение данных с бэкенда `GET /api/v1/bookings`, бейджи статусов, кнопка отзыва. |
| **Интерактивный Kaspi QR** | ✅ Готово | Модальный боттомшит с QR-кодом ([`lib/widgets/kaspi_qr_sheet.dart`](file:///home/aboka/Desktop/project/sapar/lib/widgets/kaspi_qr_sheet.dart)), генерация QR через `qr_flutter`, диплинк и подтверждение оплаты. |
| **Избранное (Favorites)** | ✅ Готово | Интерактивные сердечки в карточках ([`lib/widgets/tour_card.dart`](file:///home/aboka/Desktop/project/sapar/lib/widgets/tour_card.dart)) и экране тура ([`lib/screens/tour_detail_screen.dart`](file:///home/aboka/Desktop/project/sapar/lib/screens/tour_detail_screen.dart)), отдельный экран списка избранного ([`lib/screens/favorites_screen.dart`](file:///home/aboka/Desktop/project/sapar/lib/screens/favorites_screen.dart)). |
| **Отзывы о турах (Reviews)** | ✅ Готово | Отображение реальных отзывов с бэкенда, форма оценки со звездами (1–5) и текстом (`POST /api/v1/reviews`). |
| **Поиск и фильтрация** | ✅ Готово | Экран поиска ([`lib/screens/search_screen.dart`](file:///home/aboka/Desktop/project/sapar/lib/screens/search_screen.dart)) с фильтрами по городам вылета (Алматы, Астана, Шымкент) и бюджету. |
| **Поддержка сетевых фото** | ✅ Готово | Отображение сетевых фото через `Image.network(tour.photoUrl)` с плавным фоллбеком на брендовый цвет тура. |
| **Сохранение онбординга** | ✅ Готово | Флаг `has_seen_onboarding` в `SharedPreferences` — экран онбординга показывается только 1 раз при первом запуске ([`lib/main.dart`](file:///home/aboka/Desktop/project/sapar/lib/main.dart)). |
| **Кабинет турагентства (B2B)** | ✅ Готово | В профиле для роли `agency` доступна панель управления и экран создания нового тура ([`lib/screens/add_tour_screen.dart`](file:///home/aboka/Desktop/project/sapar/lib/screens/add_tour_screen.dart)) через API `POST /api/v1/tours`. |
| **Нижняя навигация (Табы)** | ✅ Готово | Переключение 4 вкладок: **Главная**, **Поиск**, **Брони**, **Профиль** ([`lib/screens/home_screen.dart`](file:///home/aboka/Desktop/project/sapar/lib/screens/home_screen.dart)). |

---

## 🟡 2. ЗАДАЧИ ВТОРОГО РАЗРАБОТЧИКА (В работе)

1. **🔔 Уведомления:**
   - [ ] Создание Telegram-бота для турагентств (отправка мгновенных оповещений при создании новой брони с контактами туриста и суммой).
   - [ ] Отправка электронного ваучера и билета на Email клиента после оплаты.
2. **🖼️ Хранилище медиа-файлов:**
   - [ ] Эндпоинт `POST /api/v1/tours/{id}/upload-photo` для загрузки изображений отелей (S3 / MinIO / локальный static upload).

---

## 🔵 3. ШАГИ ДЛЯ ВЫХОДА В БОЕВОЙ ПРОДАКШН (Production)

- [ ] Перенос базы данных с SQLite на **PostgreSQL** (шаблон уже готов в [`backend/docker-compose.yml`](file:///home/aboka/Desktop/project/sapar/backend/docker-compose.yml)).
- [ ] Переключение ключей Kaspi Pay с Sandbox на боевые учетные данные (`KASPI_TEST_MODE=false`, `KASPI_API_KEY`, `KASPI_MERCHANT_ID`).
- [ ] Сборка APK для Android (`flutter build apk --release`).

---

## 🚀 Инструкция по запуску из папки `/home/aboka/Desktop/project/sapar`

### 1. Запуск бэкенда (FastAPI):
```bash
cd /home/aboka/Desktop/project/sapar/backend
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
- API & Документация Swagger: **`http://localhost:8000/docs`**

### 2. Запуск фронтенда (Flutter Web):
```bash
cd /home/aboka/Desktop/project/sapar/build/web
python3 serve.py
```
- Доступ с компьютера и телефона по локальной сети: **`http://192.168.10.12:5050`**
