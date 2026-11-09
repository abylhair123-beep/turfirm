import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum LegalDocType {
  offer,
  refund,
  privacy,
}

class LegalDocsScreen extends StatefulWidget {
  final LegalDocType initialDoc;

  const LegalDocsScreen({
    super.key,
    this.initialDoc = LegalDocType.offer,
  });

  @override
  State<LegalDocsScreen> createState() => _LegalDocsScreenState();
}

class _LegalDocsScreenState extends State<LegalDocsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialDoc == LegalDocType.offer
        ? 0
        : (widget.initialDoc == LegalDocType.refund ? 1 : 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Правовая информация',
          style: AppText.sora(size: 17, weight: FontWeight.w700, color: AppColors.ink),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.teal,
          indicatorWeight: 3,
          labelStyle: AppText.work(size: 13, weight: FontWeight.w700),
          unselectedLabelStyle: AppText.work(size: 13, weight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Публичная оферта'),
            Tab(text: 'Возврат & Аннуляция'),
            Tab(text: 'Конфиденциальность'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PublicOfferTab(),
          _RefundPolicyTab(),
          _PrivacyPolicyTab(),
        ],
      ),
    );
  }
}

// ==========================================
// 1. ПУБЛИЧНАЯ ОФЕРТА И ДОГОВОР ТУРУСЛУГ
// ==========================================

class _PublicOfferTab extends StatelessWidget {
  const _PublicOfferTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildComplianceBadge(
          title: 'Официальный публичный договор-оферта',
          subtitle: 'Соответствует ГК РК и Закону РК «О туристской деятельности в Республике Казахстан» № 211-II',
          icon: Icons.verified_user_rounded,
          color: AppColors.teal,
        ),
        const SizedBox(height: 18),
        _buildSectionCard(
          title: '1. Общие положения',
          paragraphs: const [
            '1.1. Настоящий документ является официальным предложением (публичной офертой) ТОО «SAPAR TRAVEL GROUP» (БИН 230940019283), далее именуемого «Исполнитель/Туроператор», и адресован любому физическому или юридическому лицу («Заказчик/Турист»).',
            '1.2. Акцептом настоящей Оферты признается оформление Заказчиком бронирования и/или совершение полной или частичной оплаты туристического продукта через мобильное приложение SAPAR, платежный шлюз Kaspi Pay, Halyk Bank или банковские карты.',
            '1.3. Совершая оплату, Заказчик подтверждает, что ознакомлен и полностью согласен со всеми условиями настоящего Договора, правилами страхования, визовыми требованиями и санитарно-эпидемиологическими нормами страны временного пребывания.',
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: '2. Предмет Договора',
          paragraphs: const [
            '2.1. Исполнитель обязуется по заданию Заказчика сформировать и оказать комплекс туристских услуг (туристский продукт), включающий: бронирование авиаперелета, железнодорожных билетов, проживание в гостиницах, трансфер, медицинское страхование и экскурсионное обслуживание, а Заказчик обязуется оплатить эти услуги.',
            '2.2. Конкретные параметры тура (направление, даты, отель, тип питания, перелет) фиксируются в электронном ваучере и маршрутной квитанции, генерируемых в личном кабинете мобильного приложения SAPAR.',
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: '3. Порядок расчетов и платежные шлюзы',
          paragraphs: const [
            '3.1. Все расчеты производятся в национальной валюте Республики Казахстан — тенге (KZT).',
            '3.2. Оплата принимается через официальные сертифицированные шлюзы интернет-эквайринга: Kaspi Pay (QR, Kaspi Gold, Kaspi Ред, рассрочка 0-0-12), Halyk Bank E-Pay (карты Visa, MasterCard, UnionPay, Apple Pay, Google Pay).',
            '3.3. Безопасность платежей гарантируется протоколами 3D-Secure 2.0 и сертификацией PCI DSS Level 1. Платежные данные карт обрабатываются на стороне процессинга банков и не сохраняются на серверах приложения SAPAR.',
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: '4. Права и обязанности сторон',
          paragraphs: const [
            '4.1. Туроператор обязан предоставить полную и достоверную информацию о потребительских свойствах тура, выдать электронный ваучер и маршрутную квитанцию не позднее 24 часов до вылета.',
            '4.2. Турист обязан своевременно предоставить действительные паспортные данные (срок действия загранпаспорта не менее 6 месяцев на дату выезда), соблюдать законодательство, таможенные и миграционные правила страны пребывания.',
            '4.3. Турист несет личную ответственность за наличие действительных виз, доверенностей на выезд несовершеннолетних детей и медицинских справок.',
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: '5. Реквизиты Исполнителя',
          paragraphs: const [
            'ТОО «SAPAR TRAVEL GROUP»',
            'БИН: 230940019283 | Лицензия туроператора № 021495 от 14.04.2023 г.',
            'Юридический адрес: Казахстан, г. Алматы, пр. Достык 180, офис 402',
            'Банк: АО «Halyk Bank» | ИИК: KZ486010002003891234 | БИК: HSBKKZKX',
            'Служба поддержки: +7 (727) 355-88-00 | support@sapar.kz',
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ==========================================
// 2. ПОЛИТИКА ВОЗВРАТА И АННУЛЯЦИИ (REFUND POLICY)
// ==========================================

class _RefundPolicyTab extends StatelessWidget {
  const _RefundPolicyTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildComplianceBadge(
          title: 'Политика возврата и гарантии туристов',
          subtitle: 'Регламент аннуляции броней и возврата денежных средств через Kaspi Pay и Halyk Bank',
          icon: Icons.assignment_return_rounded,
          color: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 18),

        // Таблица шкалы возврата
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Шкала возврата средств при отказе от тура:', style: AppText.sora(size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 14),
              _buildRefundRow('За 15 и более дней до вылета', '100% возврат', 'Без штрафов и удержаний туроператора', Colors.green),
              const Divider(height: 16),
              _buildRefundRow('От 8 до 14 дней до вылета', '85% возврат', 'Удержание фактических расходов (15%)', Colors.teal),
              const Divider(height: 16),
              _buildRefundRow('От 4 до 7 дней до вылета', '50% возврат', 'Удержание фактических расходов (50%)', Colors.amber.shade800),
              const Divider(height: 16),
              _buildRefundRow('Менее 72 часов до вылета', 'Индивидуально', 'По правилам аннуляции отеля и тарифа авиакомпании', Colors.red),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Сроки и порядок перечисления денежных средств',
          paragraphs: const [
            '1. Заявление на аннуляцию и возврат средств подается через кнопку «Запросить отмену» в разделе бронирования или через Службу заботы 24/7 в приложении SAPAR.',
            '2. При одобрении возврата денежные средства отправляются моментально через банковский API Kaspi Pay или Halyk E-Pay.',
            '3. Срок зачисления на карту или счет клиента:',
            '   • Kaspi Gold / Kaspi Pay: от 15 минут до 24 часов;',
            '   • Halyk Bank / Карты Visa и MasterCard: от 1 до 3 банковских дней (зависит от банка-эмитента карты клиента);',
            '   • Рассрочка Kaspi / Halyk: кредитный договор аннулируется, внесенные платежи возвращаются на карту.',
          ],
        ),

        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'Особенности возврата авиа- и Ж/Д билетов',
          paragraphs: const [
            '• Возврат регулярных авиабилетов (Air Astana, SCAT, FlyArystan) и Ж/Д билетов АО «НК КТЖ» осуществляется строго по правилам применения тарифа соответствующего перевозчика.',
            '• Невозвратные тарифы авиакомпаний возврату не подлежат (за исключением аэропортовых сборов согласно законодательству РК).',
            '• При вынужденном возврате по причине болезни туриста или отмены рейса авиакомпанией возврат производится в полном объеме при предоставлении подтверждающих документов.',
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static Widget _buildRefundRow(String term, String refundRate, String note, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(refundRate, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(term, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(note, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 3. ПОЛИТИКА КОНФИДЕНЦИАЛЬНОСТИ И ПДН
// ==========================================

class _PrivacyPolicyTab extends StatelessWidget {
  const _PrivacyPolicyTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildComplianceBadge(
          title: 'Защита персональных данных',
          subtitle: 'Соответствует Закону Республики Казахстан № 94-V «О персональных данных и их защите»',
          icon: Icons.lock_outline_rounded,
          color: const Color(0xFF7C3AED),
        ),
        const SizedBox(height: 18),
        _buildSectionCard(
          title: '1. Сбор и цели обработки персональных данных',
          paragraphs: const [
            '1.1. Мы собираем только те данные, которые необходимы для бронирования туров, авиабилетов и оформления гостиниц:',
            '   • Фамилия, имя, отчество туриста (латиницей как в загранпаспорте);',
            '   • Номер паспорта, дата рождения, срок действия паспорта, гражданство;',
            '   • Номер мобильного телефона и адрес электронной почты для отправки ваучеров и билетов.',
            '1.2. Данные передаются исключительно аккредитованным партнерам (авиакомпаниям, гостиницам, туроператорам) строго для выписки проездных документов и ваучеров.',
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: '2. Безопасность и хранение данных',
          paragraphs: const [
            '2.1. Все соединения между мобильным приложением и сервером защищены шифрованием TLS 1.3 / HTTPS.',
            '2.2. Сервера баз данных размещены в защищенных сертифицированных дата-центрах на территории Республики Казахстан в полном соответствии с требованиями законодательства РК.',
            '2.3. Пароли пользователей хешируются с использованием стойкого криптографического алгоритма bcrypt с солью.',
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: '3. Право на удаление данных (Right to Deletion)',
          paragraphs: const [
            'Пользователь имеет право в любой момент запросить полное удаление своего аккаунта и персональных данных через раздел «Профиль» -> «Удалить аккаунт» или написав на privacy@sapar.kz. Данные стираются безвозвратно в течение 24 часов.',
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// Вспомогательные виджеты
Widget _buildComplianceBadge({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14.5)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: AppColors.ink, fontSize: 12, height: 1.3)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionCard({
  required String title,
  required List<String> paragraphs,
}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.sora(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 10),
        for (final p in paragraphs) ...[
          Text(p, style: AppText.work(size: 13, color: const Color(0xFF334155)).copyWith(height: 1.5)),
          const SizedBox(height: 8),
        ],
      ],
    ),
  );
}
