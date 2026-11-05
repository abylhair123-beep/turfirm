from datetime import datetime
import io
import openpyxl
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter


def generate_tourists_manifest_xlsx(agency_name: str, bookings: list) -> bytes:
    """Генерирует Excel-файл (.xlsx) с манифестом пассажиров/туристов для авиакомпаний и отелей."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Манифест туристов"

    # Стили
    title_font = Font(name="Calibri", size=16, bold=True, color="0F172A")
    meta_font = Font(name="Calibri", size=10, italic=True, color="64748B")
    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    data_font = Font(name="Calibri", size=10, color="0F172A")
    total_font = Font(name="Calibri", size=11, bold=True, color="0F172A")

    header_fill = PatternFill(start_color="0284C7", end_color="0284C7", fill_type="solid")
    alt_fill = PatternFill(start_color="F8FAFC", end_color="F8FAFC", fill_type="solid")
    total_fill = PatternFill(start_color="E2E8F0", end_color="E2E8F0", fill_type="solid")

    thin_border = Border(
        left=Side(style="thin", color="CBD5E1"),
        right=Side(style="thin", color="CBD5E1"),
        top=Side(style="thin", color="CBD5E1"),
        bottom=Side(style="thin", color="CBD5E1"),
    )

    # Заголовок документа
    ws.append(["SAPAR TRAVEL · МАНИФЕСТ ПАССАЖИРОВ И СПИСОК ТУРИСТОВ"])
    ws.append([f"Турагентство: {agency_name} | Дата выгрузки: {datetime.now().strftime('%d.%m.%Y %H:%M')}"])
    ws.append([])  # Пустая строка

    ws.cell(row=1, column=1).font = title_font
    ws.cell(row=2, column=1).font = meta_font

    # Заголовки колонок
    headers = [
        "№",
        "Код брони",
        "Тур / Программа",
        "Направление",
        "Город вылета",
        "Даты тура",
        "ФИО главного туриста",
        "Телефон",
        "Email",
        "Пассажиров",
        "Стоимость (₸)",
        "Способ оплаты",
        "Статус заявки",
        "Дата брони",
    ]
    ws.append(headers)

    header_row_idx = 4
    for col_idx in range(1, len(headers) + 1):
        cell = ws.cell(row=header_row_idx, column=col_idx)
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = thin_border
    ws.row_dimensions[header_row_idx].height = 28

    status_labels = {
        "paid": "Оплачена (Новая)",
        "new": "Новая",
        "confirmed": "Подтверждена",
        "voucher_issued": "Выдан ваучер",
        "completed": "Завершена",
        "cancelled": "Отменена",
    }

    # Заполнение данными
    total_guests = 0
    total_revenue = 0

    for idx, b in enumerate(bookings, start=1):
        tour = getattr(b, "tour", None)
        tour_title = tour.title if tour else "—"
        destination = tour.destination if tour else "—"
        departure = tour.departure_city if tour else "—"
        dates = tour.dates if tour else "—"

        status_text = status_labels.get(b.status, b.status)
        created_str = b.created_at.strftime("%d.%m.%Y %H:%M") if hasattr(b, "created_at") and b.created_at else "—"

        row = [
            idx,
            b.id,
            tour_title,
            destination,
            departure,
            dates,
            b.customer_name,
            b.customer_phone,
            b.customer_email,
            b.guests_count,
            b.total_price,
            b.payment_method,
            status_text,
            created_str,
        ]
        ws.append(row)

        curr_row = header_row_idx + idx
        total_guests += (b.guests_count or 1)
        total_revenue += (b.total_price or 0)

        for col_idx in range(1, len(headers) + 1):
            cell = ws.cell(row=curr_row, column=col_idx)
            cell.font = data_font
            cell.border = thin_border
            if idx % 2 == 0:
                cell.fill = alt_fill

            # Центрирование для числовых и статусных колонок
            if col_idx in (1, 2, 5, 10, 13, 14):
                cell.alignment = Alignment(horizontal="center", vertical="center")
            elif col_idx == 11:
                cell.alignment = Alignment(horizontal="right", vertical="center")
                cell.number_format = "#,##0"
            else:
                cell.alignment = Alignment(horizontal="left", vertical="center")

        ws.row_dimensions[curr_row].height = 20

    # Строка ИТОГО
    total_row_idx = header_row_idx + len(bookings) + 1
    total_row = [
        "ИТОГО",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        f"Заявок: {len(bookings)}",
        total_guests,
        total_revenue,
        "",
        "",
        "",
    ]
    ws.append(total_row)
    ws.merge_cells(start_row=total_row_idx, start_column=1, end_row=total_row_idx, end_column=8)

    for col_idx in range(1, len(headers) + 1):
        cell = ws.cell(row=total_row_idx, column=col_idx)
        cell.font = total_font
        cell.fill = total_fill
        cell.border = thin_border
        if col_idx == 1:
            cell.alignment = Alignment(horizontal="right", vertical="center")
        elif col_idx in (9, 10):
            cell.alignment = Alignment(horizontal="center", vertical="center")
        elif col_idx == 11:
            cell.alignment = Alignment(horizontal="right", vertical="center")
            cell.number_format = "#,##0"

    ws.row_dimensions[total_row_idx].height = 24

    # Автоподбор ширины колонок
    for col in ws.columns:
        max_len = 0
        col_letter = get_column_letter(col[0].column)
        for cell in col:
            # Игнорируем объединенный заголовок первой строки
            if cell.row in (1, 2, total_row_idx):
                continue
            val_str = str(cell.value or "")
            if len(val_str) > max_len:
                max_len = len(val_str)
        ws.column_dimensions[col_letter].width = max(max_len + 4, 12)

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()
