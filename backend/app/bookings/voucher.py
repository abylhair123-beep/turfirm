from datetime import datetime, timezone
import io
import os
from pathlib import Path
from typing import Optional

import qrcode
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm, mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    HRFlowable,
    Image,
    KeepTogether,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

# Регистрация Unicode шрифтов для корректного отображения кириллицы
_FONT_REGULAR = "Helvetica"
_FONT_BOLD = "Helvetica-Bold"

# Попытка подключить DejaVuSans / LiberationSans из системы
_CANDIDATE_FONTS = [
    ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
    ("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"),
]

for reg_path, bold_path in _CANDIDATE_FONTS:
    if os.path.exists(reg_path) and os.path.exists(bold_path):
        try:
            pdfmetrics.registerFont(TTFont("AppSans", reg_path))
            pdfmetrics.registerFont(TTFont("AppSans-Bold", bold_path))
            _FONT_REGULAR = "AppSans"
            _FONT_BOLD = "AppSans-Bold"
            break
        except Exception:
            pass


def _create_qr_image(data: str, size_mm: float = 32.0) -> Image:
    """Генерация PNG QR-кода и возврат flowable Image для ReportLab."""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=4,
        border=1,
    )
    qr.add_data(data)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#1E293B", back_color="white")

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)

    size_pt = size_mm * mm
    return Image(buf, width=size_pt, height=size_pt)


def build_travel_voucher_pdf(booking, tour, agency) -> bytes:
    """Формирует профессиональный туристический ваучер в формате PDF с QR-кодом."""
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=14 * mm,
        rightMargin=14 * mm,
        topMargin=12 * mm,
        bottomMargin=12 * mm,
    )

    styles = getSampleStyleSheet()

    # Стили типографики
    title_style = ParagraphStyle(
        "VoucherTitle",
        fontName=_FONT_BOLD,
        fontSize=18,
        leading=22,
        textColor=colors.HexColor("#0F172A"),
    )
    subtitle_style = ParagraphStyle(
        "VoucherSub",
        fontName=_FONT_REGULAR,
        fontSize=9,
        leading=12,
        textColor=colors.HexColor("#64748B"),
    )
    section_title_style = ParagraphStyle(
        "SectionHeader",
        fontName=_FONT_BOLD,
        fontSize=11,
        leading=14,
        textColor=colors.HexColor("#0284C7"),
    )
    label_style = ParagraphStyle(
        "CellLabel",
        fontName=_FONT_BOLD,
        fontSize=8.5,
        leading=11,
        textColor=colors.HexColor("#475569"),
    )
    value_style = ParagraphStyle(
        "CellValue",
        fontName=_FONT_REGULAR,
        fontSize=8.5,
        leading=11,
        textColor=colors.HexColor("#0F172A"),
    )
    badge_style = ParagraphStyle(
        "BadgeText",
        fontName=_FONT_BOLD,
        fontSize=9,
        leading=11,
        textColor=colors.HexColor("#065F46"),
        alignment=1,  # Center
    )
    legal_style = ParagraphStyle(
        "LegalNotice",
        fontName=_FONT_REGULAR,
        fontSize=7,
        leading=9.5,
        textColor=colors.HexColor("#64748B"),
    )

    story = []

    # 1. Шапка документа: Логотип/Бренд и QR-код проверки
    verify_url = f"https://sapar.kz/verify/{booking.id}"
    qr_flowable = _create_qr_image(verify_url, size_mm=28.0)

    brand_header = [
        [
            Paragraph("<b>SAPAR TRAVEL</b> · ТУРИСТИЧЕСКИЙ ВАУЧЕР", title_style),
            qr_flowable,
        ],
        [
            Paragraph(
                f"Электронный ваучер поездки № <b>{booking.id}</b><br/>"
                f"Дата оформления: {booking.created_at.strftime('%d.%m.%Y %H:%M') if hasattr(booking, 'created_at') and booking.created_at else datetime.now().strftime('%d.%m.%Y')} · "
                f"Статус: <b>ПОДТВЕРЖДЕНО И ОПЛАЧЕНО</b>",
                subtitle_style,
            ),
            Paragraph(f"<font size=6.5 color='#64748B'>Отсканируйте QR-код для<br/>проверки подлинности</font>", subtitle_style),
        ]
    ]

    header_table = Table(brand_header, colWidths=[130 * mm, 50 * mm])
    header_table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("ALIGN", (1, 0), (1, -1), "CENTER"),
        ("SPAN", (1, 0), (1, 0)),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 1),
        ("TOPPADDING", (0, 0), (-1, -1), 1),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 4 * mm))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#0284C7"), spaceAfter=4 * mm))

    # 2. Блок 1: Данные туриста и Турагентства
    tourist_agency_data = [
        [
            Paragraph("1. ГЛАВНЫЙ ТУРИСТ (LEAD GUEST)", section_title_style),
            Paragraph("2. ТУРАГЕНТСТВО (BOOKING AGENCY)", section_title_style),
        ],
        [
            Paragraph("ФИО туриста:", label_style),
            Paragraph(f"<b>{booking.customer_name}</b>", value_style),
            Paragraph("Агентство:", label_style),
            Paragraph(f"<b>{agency.name if agency else 'Sapar Partner Agency'}</b>", value_style),
        ],
        [
            Paragraph("Телефон:", label_style),
            Paragraph(str(booking.customer_phone), value_style),
            Paragraph("Телефон агентства:", label_style),
            Paragraph(str(agency.phone if agency and agency.phone else "+7 (727) 300-40-50"), value_style),
        ],
        [
            Paragraph("Email:", label_style),
            Paragraph(str(booking.customer_email), value_style),
            Paragraph("Email агентства:", label_style),
            Paragraph(str(agency.email if agency and agency.email else "support@sapar.kz"), value_style),
        ],
        [
            Paragraph("Количество гостей:", label_style),
            Paragraph(f"<b>{booking.guests_count} чел.</b>", value_style),
            Paragraph("Лицензия / Статус:", label_style),
            Paragraph("Сертифицированное турагентство Sapar", value_style),
        ],
    ]

    ta_table = Table(
        [
            [tourist_agency_data[0][0], "", tourist_agency_data[0][1], ""],
            tourist_agency_data[1],
            tourist_agency_data[2],
            tourist_agency_data[3],
            tourist_agency_data[4],
        ],
        colWidths=[36 * mm, 54 * mm, 36 * mm, 54 * mm],
    )
    ta_table.setStyle(TableStyle([
        ("SPAN", (0, 0), (1, 0)),
        ("SPAN", (2, 0), (3, 0)),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#F1F5F9")),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ]))
    story.append(ta_table)
    story.append(Spacer(1, 4 * mm))

    # 3. Блок 2: Детали тура и Проживание в отеле
    destination_str = tour.destination if tour else "Зарубежный тур"
    title_str = tour.title if tour else "Турпакет"
    dates_str = tour.dates if tour else "По расписанию рейса"
    nights_str = str(tour.nights) if tour else "7 ночей"
    meal_str = tour.meal if tour else "All Inclusive"
    departure_city = tour.departure_city if tour else "Алматы"

    hotel_table_data = [
        [Paragraph("3. ПРОГРАММА ТУРА И ПРОЖИВАНИЕ В ОТЕЛЕ", section_title_style), ""],
        [
            Paragraph("Направление:", label_style),
            Paragraph(f"<b>{destination_str}</b>", value_style),
        ],
        [
            Paragraph("Отель / Программа:", label_style),
            Paragraph(f"<b>{title_str}</b>", value_style),
        ],
        [
            Paragraph("Даты поездки:", label_style),
            Paragraph(f"{dates_str} ({nights_str})", value_style),
        ],
        [
            Paragraph("Город вылета:", label_style),
            Paragraph(f"{departure_city} (прямой чартерный/регулярный рейс)", value_style),
        ],
        [
            Paragraph("Тип питания:", label_style),
            Paragraph(f"<b>{meal_str}</b>", value_style),
        ],
        [
            Paragraph("Адрес и контакты отеля:", label_style),
            Paragraph(f"{destination_str}, Resort Area. Телефон стойки: +90 (242) 710-20-00 (Check-in: 14:00, Check-out: 12:00)", value_style),
        ],
    ]
    hotel_table = Table(hotel_table_data, colWidths=[45 * mm, 135 * mm])
    hotel_table.setStyle(TableStyle([
        ("SPAN", (0, 0), (1, 0)),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#F1F5F9")),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ]))
    story.append(hotel_table)
    story.append(Spacer(1, 4 * mm))

    # 4. Блок 3: Трансфер и Медицинская страховка (Требование ТЗ!)
    logistics_data = [
        [
            Paragraph("4. ТРАНСФЕР И ВСТРЕЧА", section_title_style),
            Paragraph("5. МЕДИЦИНСКАЯ СТРАХОВКА", section_title_style),
        ],
        [
            Paragraph("Тип трансфера:", label_style),
            Paragraph("Групповой Аэропорт - Отель - Аэропорт", value_style),
            Paragraph("Страховая компания:", label_style),
            Paragraph("АО «СК Nomad Insurance»", value_style),
        ],
        [
            Paragraph("Место встречи:", label_style),
            Paragraph("Зал прилета, стойка принимающей стороны 'SAPAR / ODEON'", value_style),
            Paragraph("Номер полиса:", label_style),
            Paragraph(f"KZ-TR-{booking.id}", value_style),
        ],
        [
            Paragraph("Время обратного трансфера:", label_style),
            Paragraph("За 3.5 часа до вылета рейса (стойка ресепшн отеля)", value_style),
            Paragraph("Круглосуточный ассистанс:", label_style),
            Paragraph("<b>+7 (727) 355-11-22</b> (24/7 Hotline / WhatsApp)", value_style),
        ],
    ]

    log_table = Table(
        [
            [logistics_data[0][0], "", logistics_data[0][1], ""],
            logistics_data[1],
            logistics_data[2],
            logistics_data[3],
        ],
        colWidths=[36 * mm, 54 * mm, 36 * mm, 54 * mm],
    )
    log_table.setStyle(TableStyle([
        ("SPAN", (0, 0), (1, 0)),
        ("SPAN", (2, 0), (3, 0)),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#F1F5F9")),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ]))
    story.append(log_table)
    story.append(Spacer(1, 4 * mm))

    # 5. Блок 4: Финансовый расчет и штамп оплаты
    tour_price = f"{booking.tour_price:,}".replace(",", " ")
    service_fee = f"{booking.service_fee:,}".replace(",", " ")
    total_price = f"{booking.total_price:,}".replace(",", " ")

    fin_data = [
        [
            Paragraph("6. ФИНАНСОВЫЙ РАСЧЕТ И ОПЛАТА", section_title_style),
            "",
            Paragraph("ОТМЕТКА ОБ ОПЛАТЕ", section_title_style),
        ],
        [
            Paragraph(f"Стоимость турпакета: <b>{tour_price} ₸</b><br/>"
                      f"Сервисный сбор платформы: <b>{service_fee} ₸</b><br/>"
                      f"Способ оплаты: <b>{booking.payment_method}</b>", value_style),
            Paragraph(f"<font size=12 color='#0284C7'>ИТОГО ОПЛАЧЕНО:</font><br/>"
                      f"<font size=14 color='#0F172A'><b>{total_price} ₸</b></font>", title_style),
            Paragraph("<b>✓ ОПЛАЧЕНО ПОЛНОСТЬЮ</b><br/>"
                      "Платеж подтвержден Kaspi Pay / Эквайринг<br/>"
                      f"Транзакция: TXN-{booking.id}", badge_style),
        ],
    ]
    fin_table = Table(fin_data, colWidths=[70 * mm, 60 * mm, 50 * mm])
    fin_table.setStyle(TableStyle([
        ("SPAN", (0, 0), (1, 0)),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F8FAFC")),
        ("BACKGROUND", (0, 1), (1, 1), colors.HexColor("#F0F9FF")),
        ("BACKGROUND", (2, 1), (2, 1), colors.HexColor("#D1FAE5")),
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
        ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.append(fin_table)
    story.append(Spacer(1, 4 * mm))

    # 6. Блок 5: Памятка туристу и юридическая информация
    notice_text = (
        "<b>Важная информация для туриста:</b><br/>"
        "1. Данный ваучер является официальным документом, подтверждающим бронирование отеля, трансфера и страховки.<br/>"
        "2. При заселении в отель предъявите распечатанный или электронный ваучер администратору вместе с заграничными паспортами.<br/>"
        "3. Время выезда на трансфер в аэропорт уточняйте на стойке информации отеля за 24 часа до вылета.<br/>"
        "4. При возникновении экстренных ситуаций незамедлительно свяжитесь со службой поддержки SAPAR: <b>support@sapar.kz</b> или по телефону <b>+7 (727) 300-40-50</b>."
    )
    story.append(Paragraph(notice_text, legal_style))

    # Сборка документа
    doc.build(story)
    return buffer.getvalue()
