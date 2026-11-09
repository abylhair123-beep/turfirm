import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });

  final String text;
  final bool isUser;
  final String time;
}

class SupportCareScreen extends StatefulWidget {
  const SupportCareScreen({super.key});

  @override
  State<SupportCareScreen> createState() => _SupportCareScreenState();
}

class _SupportCareScreenState extends State<SupportCareScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final TextEditingController _chatInputCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Здравствуйте! Я дежурный специалист службы заботы SAPAR 24/7. Чем могу помочь вам с туром, билетами или отелем?',
      isUser: false,
      time: '12:00',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _chatInputCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String urlString, {required String fallbackText}) async {
    try {
      final uri = Uri.parse(urlString);
      bool launched = false;
      if (kIsWeb) {
        launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      } else {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: fallbackText));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Контакт скопирован в буфер: $fallbackText'),
              backgroundColor: AppColors.teal,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: fallbackText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Контакт скопирован в буфер: $fallbackText'),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _sendMessage([String? presetText]) {
    final text = presetText ?? _chatInputCtrl.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, time: timeStr));
      if (presetText == null) _chatInputCtrl.clear();
    });

    _scrollChatToBottom();

    // Симуляция ответа оператора
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      String reply = 'Спасибо за обращение! Наш менеджер уже проверяет детали вашей поездки. Мы на связи круглосуточно.';
      final lower = text.toLowerCase();
      if (lower.contains('билет') || lower.contains('ваучер')) {
        reply = 'Электронные билеты и маршрутные квитанции доступны во вкладке «Брони» сразу после подтверждения оплаты. Также дубликат выслан на ваш Email.';
      } else if (lower.contains('отмен') || lower.contains('возврат')) {
        reply = 'Для оформления возврата билета или тура перейдите в «Брони» → выберите заказ → «Оформить возврат», либо наш оператор свяжется с вами по телефону.';
      } else if (lower.contains('рейс') || lower.contains('вылет') || lower.contains('перенос')) {
        reply = 'Актуальное расписание и терминалы вылета синхронизируются с авиакомпаниями в реальном времени. В случае задержки рейса мы отправим вам Push-уведомление.';
      } else if (lower.contains('живой') || lower.contains('человек') || lower.contains('оператор')) {
        reply = 'Оператор Айдана подключилась к диалогу: «Добрый день! Я на связи. Пожалуйста, укажите номер бронирования или рейса.»';
      }

      setState(() {
        _messages.add(_ChatMessage(text: reply, isUser: false, time: timeStr));
      });
      _scrollChatToBottom();
    });
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Служба заботы 24/7', style: AppText.sora(size: 17, weight: FontWeight.w700, color: AppColors.ink)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('Операторы онлайн • ответ 1 мин', style: AppText.work(size: 11, color: AppColors.muted)),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.teal,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.muted,
          labelStyle: AppText.sora(size: 13.5, weight: FontWeight.w700),
          tabs: const [
            Tab(text: '💬 Онлайн-чат'),
            Tab(text: '📞 Каналы связи & FAQ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Вкладка 1: Онлайн-чат
          _buildChatTab(),

          // Вкладка 2: Контакты и FAQ
          _buildContactsAndFaqTab(),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        // Быстрые подсказки-вопросы
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickChip('🎟️ Где мой билет?', () => _sendMessage('Где мой электронный билет и ваучер?')),
                const SizedBox(width: 8),
                _quickChip('✈️ Перенос вылета', () => _sendMessage('Как перенести дату вылета?')),
                const SizedBox(width: 8),
                _quickChip('💳 Условия возврата', () => _sendMessage('Какие условия возврата тура?')),
                const SizedBox(width: 8),
                _quickChip('👤 Живой оператор', () => _sendMessage('Соедините с живым оператором')),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // Сообщения чата
        Expanded(
          child: ListView.builder(
            controller: _chatScrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return _buildChatBubble(msg);
            },
          ),
        ),

        // Поле ввода сообщения
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputCtrl,
                  decoration: InputDecoration(
                    hintText: 'Задайте любой вопрос по поездке...',
                    hintStyle: AppText.work(size: 13, color: AppColors.muted),
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: () => _sendMessage(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildChatBubble(_ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.isUser ? AppColors.teal : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          border: msg.isUser ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: AppText.work(
                size: 13.5,
                color: msg.isUser ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg.time,
              style: TextStyle(
                fontSize: 10.5,
                color: msg.isUser ? Colors.white70 : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsAndFaqTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        Text('Прямая связь с оператором', style: AppText.sora(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 12),

        _contactCard(
          icon: Icons.chat_rounded,
          iconColor: const Color(0xFF25D366),
          title: 'Написать в WhatsApp',
          subtitle: '+7 701 555 01 99 • Ответ за 1 минуту',
          actionLabel: 'Открыть чат',
          onTap: () => _openUrl(
            'https://wa.me/77015550199?text=${Uri.encodeComponent('Здравствуйте! Мне нужна помощь по бронированию в SAPAR.')}',
            fallbackText: '+7 701 555 01 99',
          ),
        ),
        const SizedBox(height: 10),

        _contactCard(
          icon: Icons.send_rounded,
          iconColor: const Color(0xFF0088CC),
          title: 'Telegram-консультант',
          subtitle: '@sapar_support_bot • Бот и живые менеджеры',
          actionLabel: 'Написать',
          onTap: () => _openUrl(
            'https://t.me/sapar_support_bot',
            fallbackText: '@sapar_support_bot',
          ),
        ),
        const SizedBox(height: 10),

        _contactCard(
          icon: Icons.phone_in_talk_rounded,
          iconColor: AppColors.teal,
          title: 'Круглосуточный телефон',
          subtitle: '+7 (727) 300-11-22 (Бесплатно по Казахстану)',
          actionLabel: 'Позвонить',
          onTap: () => _openUrl(
            'tel:+77273001122',
            fallbackText: '+7 (727) 300-11-22',
          ),
        ),
        const SizedBox(height: 10),

        _contactCard(
          icon: Icons.mail_outline_rounded,
          iconColor: const Color(0xFFE65100),
          title: 'Email службы заботы',
          subtitle: 'support@sapar.travel • Официальные запросы и ваучеры',
          actionLabel: 'Написать',
          onTap: () => _openUrl(
            'mailto:support@sapar.travel?subject=${Uri.encodeComponent('Запрос в службу заботы SAPAR')}',
            fallbackText: 'support@sapar.travel',
          ),
        ),

        const SizedBox(height: 28),

        // Частые вопросы
        Text('Часто задаваемые вопросы (FAQ)', style: AppText.sora(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 12),

        _faqAccordion(
          question: 'Где найти электронный билет и ваучер?',
          answer: 'Все ваши оформленные билеты на самолет/поезд и ваучеры на проживание в отеле доступны в разделе «Брони» главного меню. Вы можете скачать PDF или предъявить QR-код при посадке прямо с экрана телефона.',
        ),
        _faqAccordion(
          question: 'Что делать, если рейс задержали или отменили?',
          answer: 'Наша служба заботы отслеживает статус рейсов. В случае изменений мы отправим уведомление. Для перебронирования или оформления справки свяжитесь с нами через WhatsApp или звонок — мы решим вопрос с авиакомпанией.',
        ),
        _faqAccordion(
          question: 'Как вернуть или обменять тур / билет?',
          answer: 'Возврат зависит от тарифа авиакомпании и отеля. Перейдите в детальный экран вашей брони и нажмите «Оформить возврат» либо напишите в онлайн-чат службы заботы. Средства возвращаются на ту же карту, с которой была оплата.',
        ),
        _faqAccordion(
          question: 'Как получить поддержку, находясь за границей?',
          answer: 'Наш WhatsApp (+7 701 555 01 99) и Telegram (@sapar_support_bot) работают 24/7 без перерывов и праздников. Вам нужен только интернет (Wi-Fi в отеле или роуминг).',
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _contactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: AppText.sora(size: 14, weight: FontWeight.w700)),
        subtitle: Text(subtitle, style: AppText.work(size: 12, color: AppColors.muted)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(color: AppColors.teal, fontSize: 11.5, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _faqAccordion({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        title: Text(question, style: AppText.sora(size: 13, weight: FontWeight.w600)),
        leading: const Icon(Icons.help_outline_rounded, color: AppColors.teal, size: 20),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(answer, style: AppText.work(size: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}
