import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/locale_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _masterEnabled = true;
  bool _bookingAlerts = true;
  bool _flightReminders = true;
  bool _promoAlerts = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _masterEnabled = prefs.getBool('notif_master') ?? true;
        _bookingAlerts = prefs.getBool('notif_bookings') ?? true;
        _flightReminders = prefs.getBool('notif_flights') ?? true;
        _promoAlerts = prefs.getBool('notif_promos') ?? true;
        _soundEnabled = prefs.getBool('notif_sound') ?? true;
        _vibrationEnabled = prefs.getBool('notif_vibration') ?? true;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePref(String key, bool val, void Function() apply) async {
    setState(apply);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (_) {}
  }

  void _sendTestPush() {
    NotificationService.simulateBookingConfirmed(destination: 'Анталия, Турция 5★ All Inclusive');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('🔔 Тестовое Push-уведомление успешно отправлено!'),
              ),
            ],
          ),
          backgroundColor: AppColors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          LocaleService.tr('notifications_title'),
          style: AppText.sora(size: 18, weight: FontWeight.w700, color: AppColors.ink),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Тестовый Push',
            icon: const Icon(Icons.send_rounded, color: AppColors.teal, size: 22),
            onPressed: _sendTestPush,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                // Главный переключатель
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _masterEnabled ? AppColors.teal.withValues(alpha: 0.3) : AppColors.border,
                      width: _masterEnabled ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _masterEnabled
                              ? AppColors.teal.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _masterEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                          color: _masterEnabled ? AppColors.teal : AppColors.muted,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Push-уведомления',
                              style: AppText.sora(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _masterEnabled ? 'Включены для этого устройства' : 'Отключены',
                              style: AppText.work(
                                size: 12.5,
                                color: _masterEnabled ? AppColors.teal : AppColors.muted,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _masterEnabled,
                        activeColor: AppColors.teal,
                        onChanged: (val) => _updatePref('notif_master', val, () => _masterEnabled = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Категории уведомлений
                Text('Категории оповещений', style: AppText.sora(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 12),
                _switchCard(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Статусы броней и билеты',
                  subtitle: 'Готовность ваучеров, билетов и подтверждение оплаты',
                  value: _masterEnabled && _bookingAlerts,
                  enabled: _masterEnabled,
                  onChanged: (val) => _updatePref('notif_bookings', val, () => _bookingAlerts = val),
                ),
                const SizedBox(height: 10),
                _switchCard(
                  icon: Icons.flight_takeoff_rounded,
                  title: 'Напоминания о рейсе',
                  subtitle: 'Уведомления за 24 ч и 3 ч до вылета, терминалы и гейты',
                  value: _masterEnabled && _flightReminders,
                  enabled: _masterEnabled,
                  onChanged: (val) => _updatePref('notif_flights', val, () => _flightReminders = val),
                ),
                const SizedBox(height: 10),
                _switchCard(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Горящие туры и спеццены',
                  subtitle: 'Скидки до 50% и персональные рекомендации',
                  value: _masterEnabled && _promoAlerts,
                  enabled: _masterEnabled,
                  onChanged: (val) => _updatePref('notif_promos', val, () => _promoAlerts = val),
                ),
                const SizedBox(height: 24),

                // Звук и вибрация
                Text('Сигналы и поведение', style: AppText.sora(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 12),
                _switchCard(
                  icon: Icons.volume_up_outlined,
                  title: 'Звуковые сигналы',
                  subtitle: 'Воспроизводить фирменный звук Sapar при пуше',
                  value: _masterEnabled && _soundEnabled,
                  enabled: _masterEnabled,
                  onChanged: (val) => _updatePref('notif_sound', val, () => _soundEnabled = val),
                ),
                const SizedBox(height: 10),
                _switchCard(
                  icon: Icons.vibration_rounded,
                  title: 'Вибрация',
                  subtitle: 'Тактильный отклик при получении важного уведомления',
                  value: _masterEnabled && _vibrationEnabled,
                  enabled: _masterEnabled,
                  onChanged: (val) => _updatePref('notif_vibration', val, () => _vibrationEnabled = val),
                ),
                const SizedBox(height: 24),

                // Кнопка тестового пуша
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _sendTestPush,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Отправить тестовый Push сейчас',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // История уведомлений
                ValueListenableBuilder<List<AppNotification>>(
                  valueListenable: NotificationService.notificationsNotifier,
                  builder: (context, notifs, _) {
                    if (notifs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 36, color: AppColors.muted.withValues(alpha: 0.6)),
                            const SizedBox(height: 8),
                            Text(
                              'История уведомлений пуста',
                              style: AppText.sora(size: 14, weight: FontWeight.w600, color: AppColors.muted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Нажмите кнопку выше, чтобы отправить тестовый Push',
                              textAlign: TextAlign.center,
                              style: AppText.work(size: 12, color: AppColors.mutedLight),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'История уведомлений (${notifs.length})',
                              style: AppText.sora(size: 15, weight: FontWeight.w700),
                            ),
                            TextButton.icon(
                              onPressed: () => NotificationService.notificationsNotifier.value = [],
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.muted),
                              label: const Text('Очистить', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final notif in notifs.take(5))
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.teal.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.notifications_active_rounded, color: AppColors.teal, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(notif.title, style: AppText.sora(size: 13, weight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(notif.body, style: AppText.work(size: 12, color: AppColors.muted)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Только что',
                                        style: AppText.work(size: 10.5, color: AppColors.mutedLight),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _switchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? AppColors.teal.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: enabled ? AppColors.teal : Colors.grey, size: 20),
        ),
        title: Text(
          title,
          style: AppText.sora(size: 13.5, weight: FontWeight.w600, color: enabled ? AppColors.ink : Colors.grey),
        ),
        subtitle: Text(
          subtitle,
          style: AppText.work(size: 11.5, color: AppColors.muted),
        ),
        trailing: Switch.adaptive(
          value: value,
          activeColor: AppColors.teal,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
