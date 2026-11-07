import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/locale_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';
import 'admin_finance_screen.dart';
import 'agency_dashboard_screen.dart';
import 'auth_screen.dart';
import 'bookings_list_screen.dart';
import 'create_tour_screen.dart';
import 'crm_calls_screen.dart';
import 'favorites_screen.dart';
import 'partner_dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ApiService.userNotifier,
      builder: (context, user, _) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: user == null ? const _UnauthenticatedView() : _AuthenticatedView(user: user),
          ),
        );
      },
    );
  }
}

void _showLanguageSelector(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              LocaleService.tr('select_language'),
              style: AppText.sora(size: 17, weight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            for (final lang in AppLanguage.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(lang.flag, style: const TextStyle(fontSize: 26)),
                title: Text(lang.name, style: AppText.work(size: 15, weight: FontWeight.w600)),
                trailing: LocaleService.currentLanguage == lang
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 22)
                    : null,
                onTap: () {
                  LocaleService.setLanguage(lang);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      );
    },
  );
}

void _confirmDeleteAccount(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Удаление аккаунта'),
      content: const Text(
        'Вы уверены, что хотите удалить аккаунт SAPAR? Все ваши бронирования, избранное и персональные данные будут удалены безвозвратно.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            final ok = await ApiService.deleteAccount();
            if (context.mounted && ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ваш аккаунт был успешно удален.')),
              );
            }
          },
          child: const Text('Удалить', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

Future<void> _launchSupportUrl(
  BuildContext context,
  String urlString, {
  required String fallbackText,
}) async {
  try {
    final uri = Uri.parse(urlString);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await Clipboard.setData(ClipboardData(text: fallbackText));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Контакт скопирован в буфер: $fallbackText'),
          backgroundColor: AppColors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: fallbackText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Контакт скопирован в буфер: $fallbackText'),
        backgroundColor: AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

void _showNotificationsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: AppColors.teal, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Push-уведомления', style: AppText.sora(size: 17, weight: FontWeight.w700, color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text('Настройка важных оповещений о поездках', style: AppText.work(size: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _notificationSwitchTile(
              icon: Icons.confirmation_number_outlined,
              title: 'Статусы броней и билеты',
              subtitle: 'Готовность ваучеров, билетов и подтверждение оплаты',
            ),
            const SizedBox(height: 10),
            _notificationSwitchTile(
              icon: Icons.flight_takeoff_rounded,
              title: 'Напоминания о рейсе',
              subtitle: 'Уведомления за 24 ч и 3 ч до вылета, терминалы и гейты',
            ),
            const SizedBox(height: 10),
            _notificationSwitchTile(
              icon: Icons.local_fire_department_outlined,
              title: 'Горящие туры и спеццены',
              subtitle: 'Скидки до 50% и персональные рекомендации',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  NotificationService.simulateBookingConfirmed(destination: 'Анталия, Турция 5★');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Expanded(child: Text('🔔 Тестовое Push-уведомление отправлено!')),
                          ],
                        ),
                        backgroundColor: AppColors.teal,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Отправить тестовый Push сейчас', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showPaymentMethodsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.credit_card_rounded, color: AppColors.teal, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Способы оплаты', style: AppText.sora(size: 17, weight: FontWeight.w700, color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text('Безопасные онлайн-платежи в тенге (₸)', style: AppText.work(size: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _paymentMethodCard(
                iconWidget: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF14635),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('K', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                ),
                title: 'Kaspi Pay & QR',
                subtitle: '0% комиссии • Оплата в приложении Kaspi.kz • Kaspi Red, Gold, Kredit',
                badgeText: 'Активно',
                badgeColor: const Color(0xFF0F766E),
              ),
              const SizedBox(height: 10),
              _paymentMethodCard(
                iconWidget: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 20),
                ),
                title: 'Банковские карты',
                subtitle: 'Visa, Mastercard, Halyk, Forte, Freedom, зарубежные карты',
                badgeText: '3D-Secure 2.0',
                badgeColor: const Color(0xFF2563EB),
              ),
              const SizedBox(height: 10),
              _paymentMethodCard(
                iconWidget: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007A33),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                ),
                title: 'Halyk Bank & QR',
                subtitle: 'Homebank QR, карты Halyk и мгновенное списание со счета',
                badgeText: 'Активно',
                badgeColor: const Color(0xFF007A33),
              ),
              const SizedBox(height: 10),
              _paymentMethodCard(
                iconWidget: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.percent_rounded, color: Colors.white, size: 20),
                ),
                title: 'Рассрочка и кредит 0-0-12',
                subtitle: 'Без переплат и первого взноса от банков-партнёров',
                badgeText: '0% переплаты',
                badgeColor: const Color(0xFF7C3AED),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.teal, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Гарантия безопасности PCI-DSS', style: AppText.sora(size: 13, weight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(
                            'Все платежи проходят по защищённому протоколу TLS 1.3 с подтверждением через 3D-Secure. Данные ваших карт не сохраняются на серверах сервиса.',
                            style: AppText.work(size: 11.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  title: 'Понятно',
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showSupportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: AppColors.teal, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Служба заботы Sapar 24/7', style: AppText.sora(size: 17, weight: FontWeight.w700, color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text('Помощь с бронированием, вылетами и отелями', style: AppText.work(size: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _supportActionCard(
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF25D366),
                title: 'Написать в WhatsApp',
                subtitle: 'Быстрый ответ оператора за 1-2 минуты',
                actionLabel: 'Открыть',
                onTap: () => _launchSupportUrl(
                  context,
                  'https://wa.me/77015550199?text=${Uri.encodeComponent('Здравствуйте! Мне нужна помощь по приложению Sapar.')}',
                  fallbackText: '+7 701 555 01 99',
                ),
              ),
              const SizedBox(height: 10),
              _supportActionCard(
                icon: Icons.send_rounded,
                iconColor: const Color(0xFF0088CC),
                title: 'Telegram-консультант',
                subtitle: '@sapar_support_bot — бот и онлайн-поддержка',
                actionLabel: 'Открыть',
                onTap: () => _launchSupportUrl(
                  context,
                  'https://t.me/sapar_support_bot',
                  fallbackText: '@sapar_support_bot',
                ),
              ),
              const SizedBox(height: 10),
              _supportActionCard(
                icon: Icons.phone_in_talk_rounded,
                iconColor: AppColors.teal,
                title: 'Круглосуточный телефон',
                subtitle: '+7 (727) 300-11-22 (Бесплатно по Казахстану)',
                actionLabel: 'Позвонить',
                onTap: () => _launchSupportUrl(
                  context,
                  'tel:+77273001122',
                  fallbackText: '+7 (727) 300-11-22',
                ),
              ),
              const SizedBox(height: 10),
              _supportActionCard(
                icon: Icons.mail_outline_rounded,
                iconColor: const Color(0xFFE65100),
                title: 'Email службы заботы',
                subtitle: 'support@sapar.travel — для официальных писем и документов',
                actionLabel: 'Написать',
                onTap: () => _launchSupportUrl(
                  context,
                  'mailto:support@sapar.travel?subject=${Uri.encodeComponent('Запрос в службу заботы Sapar')}',
                  fallbackText: 'support@sapar.travel',
                ),
              ),
              const SizedBox(height: 18),
              Text('Частые вопросы', style: AppText.sora(size: 14, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              _faqItem(
                question: 'Где найти ваучер и авиабилеты?',
                answer: 'Маршрутные квитанции, ваучер на проживание и страховка доступны во вкладке «Брони» за 24–48 ч до вылета.',
              ),
              const SizedBox(height: 8),
              _faqItem(
                question: 'Что делать при задержке рейса?',
                answer: 'Служба заботы круглосуточно отслеживает рейсы. Если рейс задержан, мы автоматически оповестим трансфер и отель.',
              ),
              const SizedBox(height: 8),
              _faqItem(
                question: 'Как изменить или отменить бронь?',
                answer: 'Напишите в WhatsApp со своим номером бронирования — менеджер оперативно согласует все детали с туроператором.',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  title: 'Закрыть',
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _paymentMethodCard({
  required Widget iconWidget,
  required String title,
  required String subtitle,
  required String badgeText,
  required Color badgeColor,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        iconWidget,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: AppText.sora(size: 13.5, weight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: AppText.work(size: 11.5, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _supportActionCard({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required String actionLabel,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.sora(size: 13.5, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.work(size: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(actionLabel, style: const TextStyle(color: AppColors.teal, fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}

Widget _faqItem({required String question, required String answer}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.sand,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.help_outline_rounded, size: 16, color: AppColors.teal),
            const SizedBox(width: 6),
            Expanded(child: Text(question, style: AppText.sora(size: 12.5, weight: FontWeight.w600))),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Text(answer, style: AppText.work(size: 11.5, color: AppColors.muted)),
        ),
      ],
    ),
  );
}

Widget _notificationSwitchTile({
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.teal, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.sora(size: 13, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppText.work(size: 11, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 22),
      ],
    ),
  );
}

class _UnauthenticatedView extends StatelessWidget {
  const _UnauthenticatedView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded, size: 48, color: AppColors.teal),
          ),
          const SizedBox(height: 20),
          Text(
            LocaleService.tr('login_title'),
            style: AppText.h2.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            LocaleService.tr('login_desc'),
            textAlign: TextAlign.center,
            style: AppText.work(size: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            title: LocaleService.tr('login_btn'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          // Быстрая смена языка
          OutlinedButton.icon(
            onPressed: () => _showLanguageSelector(context),
            icon: Text(LocaleService.currentLanguage.flag, style: const TextStyle(fontSize: 18)),
            label: Text(
              '${LocaleService.tr('language_title')}: ${LocaleService.currentLanguage.name}',
              style: AppText.work(size: 13.5, color: AppColors.ink),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPaymentMethodsSheet(context),
                  icon: const Icon(Icons.credit_card_rounded, size: 16, color: AppColors.ink),
                  label: const Text('Оплата', style: TextStyle(color: AppColors.ink, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showSupportSheet(context),
                  icon: const Icon(Icons.support_agent_rounded, size: 16, color: AppColors.teal),
                  label: const Text('Забота 24/7', style: TextStyle(color: AppColors.teal, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthenticatedView extends StatelessWidget {
  const _AuthenticatedView({required this.user});

  final dynamic user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Text(LocaleService.tr('profile_header'), style: AppText.h3.copyWith(fontSize: 20)),
        const SizedBox(height: 18),

        // Карточка пользователя
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.teal,
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: AppText.sora(size: 16, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(user.email, style: AppText.work(size: 13, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: user.isAdmin == true
                                ? const Color(0xFF7B1FA2).withValues(alpha: 0.12)
                                : user.isAgency == true
                                    ? AppColors.coral.withValues(alpha: 0.12)
                                    : AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.isAdmin == true
                                ? 'Администратор'
                                : user.isAgency == true
                                    ? 'Турагентство'
                                    : 'Турист',
                            style: AppText.work(
                              size: 11,
                              weight: FontWeight.bold,
                              color: user.isAdmin == true
                                  ? const Color(0xFF7B1FA2)
                                  : user.isAgency == true
                                      ? AppColors.coral
                                      : AppColors.teal,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: user.isEmailVerified == true
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.isEmailVerified == true
                                ? '✓ Email подтвержден'
                                : '⚠ Email не подтвержден',
                            style: AppText.work(
                              size: 11,
                              weight: FontWeight.w600,
                              color: user.isEmailVerified == true
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Админ-панель: Финансовый баланс платформы
        if (user.isAdmin == true) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A148C).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminFinanceScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Баланс платформы',
                                  style: AppText.sora(size: 15, weight: FontWeight.w700, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('ADMIN', style: TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Приход, расход, выплаты агентствам и чистая прибыль',
                              style: AppText.work(size: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        // Панель B2B и управления
        if (user.isAgency == true || user.isAdmin == true) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.teal, AppColors.tealDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business_center_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          LocaleService.tr('agency_cabinet'),
                          style: AppText.sora(size: 15, weight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('B2B PRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Аналитика продаж, Канбан туристов, экспорт в Excel и управление турами',
                  style: AppText.work(size: 12.5, color: const Color(0xFFBFEAE4)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AgencyDashboardScreen()),
                          );
                        },
                        icon: const Icon(Icons.dashboard_rounded, color: Color(0xFF0E7C77), size: 18),
                        label: const Text(
                          'Панель B2B',
                          style: TextStyle(color: Color(0xFF0E7C77), fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateTourScreen()),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      label: Text(
                        LocaleService.tr('add_new_tour'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white54),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CrmCallsScreen()),
                      );
                    },
                    icon: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Мини-CRM & Обзвон клиентов',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white54),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Баннер партнёрской программы для блогеров
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PartnerDashboardScreen()),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Кабинет блогера',
                                style: AppText.sora(size: 15, weight: FontWeight.w700, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('3%', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Реферальные ссылки, статистика и вывод бонусов',
                            style: AppText.work(size: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Навигационные пункты
        _menuTile(
          icon: Icons.confirmation_number_outlined,
          title: LocaleService.tr('nav_bookings'),
          subtitle: 'История поездок и активные билеты',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BookingsListScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _menuTile(
          icon: Icons.favorite_border_rounded,
          title: LocaleService.tr('my_favorites'),
          subtitle: 'Сохраненные варианты для отпуска',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        // Переключатель языка
        _menuTile(
          icon: Icons.language_rounded,
          title: LocaleService.tr('language_title'),
          subtitle: '${LocaleService.currentLanguage.flag} ${LocaleService.currentLanguage.name}',
          trailing: const Icon(Icons.keyboard_arrow_right_rounded, color: AppColors.muted),
          onTap: () => _showLanguageSelector(context),
        ),
        const SizedBox(height: 10),
        // Push-уведомления (тест)
        _menuTile(
          icon: Icons.notifications_active_outlined,
          title: LocaleService.tr('notifications_title'),
          subtitle: LocaleService.tr('test_notification'),
          trailing: IconButton(
            icon: const Icon(Icons.send_rounded, size: 18, color: AppColors.teal),
            tooltip: 'Отправить тест',
            onPressed: () {
              NotificationService.simulateBookingConfirmed(destination: 'Анталия, Турция 5★');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('🔔 Тестовое Push-уведомление отправлено!')),
                    ],
                  ),
                  backgroundColor: AppColors.teal,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
          onTap: () => _showNotificationsSheet(context),
        ),
        const SizedBox(height: 10),
        _menuTile(
          icon: Icons.credit_card_rounded,
          title: 'Способы оплаты',
          subtitle: 'Kaspi Pay, Visa, Mastercard, Halyk',
          onTap: () => _showPaymentMethodsSheet(context),
        ),
        const SizedBox(height: 10),
        _menuTile(
          icon: Icons.support_agent_rounded,
          title: 'Служба заботы 24/7',
          subtitle: 'Помощь с бронированием и авиабилетами',
          onTap: () => _showSupportSheet(context),
        ),
        const SizedBox(height: 28),

        // Выход
        OutlinedButton.icon(
          onPressed: () => ApiService.logout(),
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 18),
          label: Text(LocaleService.tr('logout_btn'), style: const TextStyle(color: Color(0xFFE53935))),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFFFFCDD2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        // Удаление аккаунта (Apple App Store Guideline 5.1.1(v))
        TextButton(
          onPressed: () => _confirmDeleteAccount(context),
          child: const Text(
            'Удалить аккаунт',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.teal, size: 20),
        ),
        title: Text(title, style: AppText.sora(size: 14, weight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppText.work(size: 12, color: AppColors.muted)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight),
      ),
    );
  }
}
