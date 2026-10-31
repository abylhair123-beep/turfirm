import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';
import 'add_tour_screen.dart';
import 'auth_screen.dart';
import 'bookings_list_screen.dart';
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
            child: user == null ? _UnauthenticatedView() : _AuthenticatedView(user: user),
          ),
        );
      },
    );
  }
}

class _UnauthenticatedView extends StatelessWidget {
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
            'Войдите в профиль',
            style: AppText.h2.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Чтобы сохранять любимые туры в Избранное, просматривать билеты и историю бронирований',
            textAlign: TextAlign.center,
            style: AppText.work(size: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            title: 'Войти / Зарегистрироваться',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
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
        Text('Профиль', style: AppText.h3.copyWith(fontSize: 20)),
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
                  style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: AppText.sora(size: 16, weight: FontWeight.w600, color: AppColors.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: AppText.work(size: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: user.isAgency
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.isAgency ? 'Турагентство' : 'Турист Sapar',
                        style: AppText.work(
                          size: 11,
                          weight: FontWeight.w600,
                          color: user.isAgency ? const Color(0xFF2E7D32) : AppColors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (user.isAgency) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E7C77), Color(0xFF0B3D3D)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.business_center_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Панель турагентства',
                      style: AppText.sora(size: 15, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Публикуйте авторские и пакетные туры для тысяч туристов на Sapar',
                  style: AppText.work(size: 12.5, color: const Color(0xFFBFEAE4)),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddTourScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF0E7C77), size: 18),
                  label: const Text('Добавить новый тур', style: TextStyle(color: Color(0xFF0E7C77), fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Навигационные пункты
        _menuTile(
          icon: Icons.confirmation_number_outlined,
          title: 'Мои бронирования',
          subtitle: 'История поездок и активные брони',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BookingsListScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _menuTile(
          icon: Icons.favorite_border_rounded,
          title: 'Избранные туры',
          subtitle: 'Сохраненные варианты для отпуска',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            );
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
        const SizedBox(height: 32),

        // Выход
        OutlinedButton.icon(
          onPressed: () => ApiService.logout(),
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 18),
          label: const Text('Выйти из аккаунта', style: TextStyle(color: Color(0xFFE53935))),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFFFFCDD2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.teal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.sora(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.work(size: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight),
          ],
        ),
      ),
    );
  }
}
