import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _emailController = TextEditingController(text: 'aigerim@mail.kz');
  final _passwordController = TextEditingController(text: 'User123!');
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _agencyNameController = TextEditingController();
  String _selectedRole = 'client';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _agencyNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        final user = await ApiService.login(
          _emailController.text,
          _passwordController.text,
        );
        if (user != null) {
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else if (mounted) {
            Navigator.of(context).pop();
          }
        } else {
          setState(() => _errorMessage = 'Неверный email или пароль');
        }
      } else {
        if (_nameController.text.trim().isEmpty) {
          setState(() => _errorMessage = 'Укажите ваше имя');
          return;
        }
        final user = await ApiService.register(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _nameController.text,
          phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
          role: _selectedRole,
          agencyName: _selectedRole == 'agency' ? _agencyNameController.text : null,
        );
        if (user != null) {
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else if (mounted) {
            Navigator.of(context).pop();
          }
        } else {
          setState(() => _errorMessage = 'Ошибка регистрации (возможно email уже занят)');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _fillDemoAccount(String email, String pass, String role) {
    setState(() {
      _isLogin = true;
      _emailController.text = email;
      _passwordController.text = pass;
    });
    _handleSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isLogin ? 'Вход в аккаунт' : 'Регистрация',
          style: AppText.h3.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            // Переключатель Режима (Вход / Регистрация)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLogin = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isLogin ? AppColors.teal : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Вход',
                          textAlign: TextAlign.center,
                          style: AppText.work(
                            size: 14,
                            weight: FontWeight.w600,
                            color: _isLogin ? Colors.white : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLogin = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isLogin ? AppColors.teal : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Регистрация',
                          textAlign: TextAlign.center,
                          style: AppText.work(
                            size: 14,
                            weight: FontWeight.w600,
                            color: !_isLogin ? Colors.white : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (!_isLogin) ...[
              // Выбор роли
              Row(
                children: [
                  Expanded(
                    child: _roleOption(
                      title: 'Турист',
                      icon: Icons.person_rounded,
                      selected: _selectedRole == 'client',
                      onTap: () => setState(() => _selectedRole = 'client'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _roleOption(
                      title: 'Турагентство',
                      icon: Icons.business_rounded,
                      selected: _selectedRole == 'agency',
                      onTap: () => setState(() => _selectedRole = 'agency'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _inputField(
                controller: _nameController,
                label: 'ФИО',
                hint: 'Айгерим Сериковна',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),
              _inputField(
                controller: _phoneController,
                label: 'Номер телефона',
                hint: '+7 701 234 56 78',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              if (_selectedRole == 'agency') ...[
                _inputField(
                  controller: _agencyNameController,
                  label: 'Название турагентства',
                  hint: 'Turan Travel',
                  icon: Icons.domain_rounded,
                ),
                const SizedBox(height: 14),
              ],
            ],

            _inputField(
              controller: _emailController,
              label: 'Email',
              hint: 'user@mail.kz',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _passwordController,
              label: 'Пароль',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
            ),
            const SizedBox(height: 10),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE8E6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: AppText.work(size: 13, color: const Color(0xFFD32F2F)),
                ),
              ),
            const SizedBox(height: 20),

            PrimaryButton(
              title: _isLogin ? 'Войти в Sapar' : 'Зарегистрироваться',
              isLoading: _isLoading,
              onTap: _handleSubmit,
            ),
            const SizedBox(height: 28),

            // Блок быстрых демо-аккаунтов
            Text(
              'БЫСТРЫЙ ДЕМО-ВХОД:',
              textAlign: TextAlign.center,
              style: AppText.work(size: 11, weight: FontWeight.w600, color: AppColors.mutedLight),
            ),
            const SizedBox(height: 12),
            _demoButton(
              title: 'Айгерим (Турист)',
              email: 'aigerim@mail.kz',
              onTap: () => _fillDemoAccount('aigerim@mail.kz', 'User123!', 'client'),
            ),
            const SizedBox(height: 8),
            _demoButton(
              title: 'Turan Travel (Турагентство)',
              email: 'turan@sapar.kz',
              onTap: () => _fillDemoAccount('turan@sapar.kz', 'Agency123!', 'agency'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleOption({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.teal : AppColors.muted, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppText.work(
                size: 13,
                weight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.teal : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.work(size: 13, weight: FontWeight.w500, color: AppColors.ink),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.muted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: isPassword,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppText.work(size: 14, color: AppColors.mutedLight),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: AppText.work(size: 14.5, color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _demoButton({
    required String title,
    required String email,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.flash_on_rounded, color: Color(0xFFF39C12), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppText.work(size: 13, weight: FontWeight.w600, color: AppColors.ink),
              ),
            ),
            Text(
              email,
              style: AppText.work(size: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
