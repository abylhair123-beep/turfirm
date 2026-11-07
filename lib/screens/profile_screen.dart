import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/locale_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';
import 'agency_dashboard_screen.dart';
import 'auth_screen.dart';
import 'bookings_list_screen.dart';
import 'create_tour_screen.dart';
import 'favorites_screen.dart';

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
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

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
          trailing: const Icon(Icons.send_rounded, size: 18, color: AppColors.teal),
          onTap: () {
            NotificationService.simulateBookingConfirmed(destination: 'Анталия, Турция 5★');
          },
        ),
        const SizedBox(height: 10),
        _menuTile(
          icon: Icons.credit_card_rounded,
          title: 'Способы оплаты',
          subtitle: 'Kaspi Pay, Visa, Mastercard, Halyk',
          onTap: () {},
        ),
        const SizedBox(height: 10),
        _menuTile(
          icon: Icons.support_agent_rounded,
          title: 'Служба заботы 24/7',
          subtitle: 'Помощь с бронированием и авиабилетами',
          onTap: () {},
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
