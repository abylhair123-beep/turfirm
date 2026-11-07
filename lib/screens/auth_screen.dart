import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';
import 'agency_dashboard_screen.dart';

enum AuthMode {
  login,
  register,
  forgotPassword,
  resetPassword,
  verifyEmail,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.login;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  // Контроллеры
  final _emailController = TextEditingController(text: 'aigerim@mail.kz');
  final _passwordController = TextEditingController(text: 'User123!');
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _agencyNameController = TextEditingController();
  final _resetIdentController = TextEditingController();
  final _resetCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _emailVerifyCodeController = TextEditingController();

  String _selectedRole = 'client';
  String _activeResetIdentifier = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _agencyNameController.dispose();
    _resetIdentController.dispose();
    _resetCodeController.dispose();
    _newPasswordController.dispose();
    _emailVerifyCodeController.dispose();
    super.dispose();
  }

  /// Маршрутизация пользователя в зависимости от его роли:
  /// - agency: перенаправление в B2B кабинет агентства (AgencyDashboardScreen)
  /// - admin: системный доступ и управление платформой
  /// - client: возврат в клиентский интерфейс каталога туров
  void _routeByRole(AppUser user) {
    if (!mounted) return;

    if (user.isAgency) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🏢 Добро пожаловать в B2B кабинет, ${user.fullName}!'),
          backgroundColor: AppColors.teal,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AgencyDashboardScreen()),
      );
    } else if (user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('👑 Вы вошли с правами Администратора SAPAR'),
          backgroundColor: AppColors.teal,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AgencyDashboardScreen()),
      );
    } else {
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  // ==================== ОБРАБОТЧИКИ ====================

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final user = await ApiService.login(
        _emailController.text,
        _passwordController.text,
      );
      if (user != null) {
        _routeByRole(user);
      } else {
        setState(() => _errorMessage = 'Неверный email или пароль');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Укажите ваше имя');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final user = await ApiService.register(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        role: _selectedRole,
        agencyName: _selectedRole == 'agency' ? _agencyNameController.text : null,
      );

      if (user != null) {
        // Переводим на экран верификации email
        setState(() {
          _mode = AuthMode.verifyEmail;
          _infoMessage = 'На адрес ${user.email} отправлен код подтверждения.';
        });
      } else {
        setState(() => _errorMessage = 'Ошибка регистрации (возможно email или телефон уже занят)');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final ident = _resetIdentController.text.trim();
    if (ident.isEmpty) {
      setState(() => _errorMessage = 'Введите email или номер телефона');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final res = await ApiService.forgotPassword(ident);
      if (res['success'] == true) {
        setState(() {
          _activeResetIdentifier = ident;
          _mode = AuthMode.resetPassword;
          final devCode = res['devCode'] != null ? ' (Тестовый код: ${res['devCode']})' : '';
          _infoMessage = '${res['message']}$devCode';
        });
      } else {
        setState(() => _errorMessage = res['message']);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final code = _resetCodeController.text.trim();
    final newPass = _newPasswordController.text;

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Введите проверочный код');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _errorMessage = 'Пароль должен содержать не менее 6 символов');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final user = await ApiService.resetPassword(
        identifier: _activeResetIdentifier,
        code: code,
        newPassword: newPass,
      );

      if (user != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пароль успешно обновлен!'),
              backgroundColor: AppColors.teal,
            ),
          );
        }
        _routeByRole(user);
      } else {
        setState(() => _errorMessage = 'Неверный или просроченный проверочный код');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyEmail() async {
    final code = _emailVerifyCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Введите проверочный код');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ok = await ApiService.verifyEmailCode(
        ApiService.currentUser?.email ?? _emailController.text,
        code,
      );
      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Email успешно подтвержден!'),
              backgroundColor: AppColors.teal,
            ),
          );
        }
        if (ApiService.currentUser != null) {
          _routeByRole(ApiService.currentUser!);
        } else {
          setState(() => _mode = AuthMode.login);
        }
      } else {
        setState(() => _errorMessage = 'Неверный или просроченный код подтверждения');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillDemoAccount(String email, String pass, String role) {
    setState(() {
      _mode = AuthMode.login;
      _emailController.text = email;
      _passwordController.text = pass;
    });
    _handleLogin();
  }

  @override
  Widget build(BuildContext context) {
    String titleText = 'Вход в аккаунт';
    if (_mode == AuthMode.register) titleText = 'Регистрация';
    if (_mode == AuthMode.forgotPassword) titleText = 'Восстановление доступа';
    if (_mode == AuthMode.resetPassword) titleText = 'Новый пароль';
    if (_mode == AuthMode.verifyEmail) titleText = 'Подтверждение Email';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(titleText, style: AppText.h3.copyWith(fontSize: 18)),
        centerTitle: true,
        leading: _mode != AuthMode.login
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _infoMessage = null;
                    _mode = AuthMode.login;
                  });
                },
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            // Информационные и предупреждающие баннеры
            if (_infoMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF2E7D32), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _infoMessage!,
                        style: AppText.work(size: 13, color: const Color(0xFF1B5E20)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE8E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppText.work(size: 13, color: const Color(0xFFD32F2F)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Отображение формы согласно текущему режиму
            if (_mode == AuthMode.login || _mode == AuthMode.register)
              _buildLoginRegisterForm()
            else if (_mode == AuthMode.forgotPassword)
              _buildForgotPasswordForm()
            else if (_mode == AuthMode.resetPassword)
              _buildResetPasswordForm()
            else if (_mode == AuthMode.verifyEmail)
              _buildVerifyEmailForm(),
          ],
        ),
      ),
    );
  }

  // ==================== UI СЕКЦИИ ====================

  Widget _buildLoginRegisterForm() {
    final isLogin = _mode == AuthMode.login;

    return Column(
      children: [
        // Табы переключения Вход / Регистрация
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
                  onTap: () => setState(() {
                    _errorMessage = null;
                    _infoMessage = null;
                    _mode = AuthMode.login;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isLogin ? AppColors.teal : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Вход',
                      textAlign: TextAlign.center,
                      style: AppText.work(
                        size: 14,
                        weight: FontWeight.w600,
                        color: isLogin ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _errorMessage = null;
                    _infoMessage = null;
                    _mode = AuthMode.register;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !isLogin ? AppColors.teal : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Регистрация',
                      textAlign: TextAlign.center,
                      style: AppText.work(
                        size: 14,
                        weight: FontWeight.w600,
                        color: !isLogin ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (!isLogin) ...[
          // Выбор роли (Турист или Турагентство)
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

        // Ссылка «Забыли пароль?»
        if (isLogin) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _infoMessage = null;
                  _resetIdentController.text = _emailController.text;
                  _mode = AuthMode.forgotPassword;
                });
              },
              child: const Text(
                'Забыли пароль?',
                style: TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 16),

        PrimaryButton(
          title: isLogin ? 'Войти в Sapar' : 'Зарегистрироваться',
          isLoading: _isLoading,
          onTap: isLogin ? _handleLogin : _handleRegister,
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
          icon: Icons.person_outline_rounded,
          onTap: () => _fillDemoAccount('aigerim@mail.kz', 'User123!', 'client'),
        ),
        const SizedBox(height: 8),
        _demoButton(
          title: 'Turan Travel (Турагентство)',
          email: 'turan@sapar.kz',
          icon: Icons.business_outlined,
          onTap: () => _fillDemoAccount('turan@sapar.kz', 'Agency123!', 'agency'),
        ),
        const SizedBox(height: 8),
        _demoButton(
          title: 'Администратор платформы',
          email: 'admin@sapar.kz',
          icon: Icons.admin_panel_settings_outlined,
          onTap: () => _fillDemoAccount('admin@sapar.kz', 'Admin123!', 'admin'),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'Забыли пароль?',
          style: AppText.sora(size: 20, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Укажите Email или привязанный номер телефона. Мы отправим вам 6-значный проверочный код для сброса пароля.',
          style: AppText.work(size: 13.5, color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        _inputField(
          controller: _resetIdentController,
          label: 'Email или телефон',
          hint: 'user@mail.kz или +7 701 ...',
          icon: Icons.contact_mail_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          title: 'Отправить проверочный код',
          isLoading: _isLoading,
          onTap: _handleForgotPassword,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _mode = AuthMode.login),
            child: const Text('Вернуться ко входу', style: TextStyle(color: AppColors.muted)),
          ),
        ),
      ],
    );
  }

  Widget _buildResetPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'Установка нового пароля',
          style: AppText.sora(size: 20, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Введите 6-значный код, отправленный на $_activeResetIdentifier, и укажите новый пароль.',
          style: AppText.work(size: 13.5, color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        _inputField(
          controller: _resetCodeController,
          label: '6-значный код из письма/SMS',
          hint: '123456',
          icon: Icons.password_rounded,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _inputField(
          controller: _newPasswordController,
          label: 'Новый пароль',
          hint: 'Минимум 6 символов',
          icon: Icons.lock_reset_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          title: 'Сохранить и войти',
          isLoading: _isLoading,
          onTap: _handleResetPassword,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _mode = AuthMode.login),
            child: const Text('Отмена', style: TextStyle(color: AppColors.muted)),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_outlined, size: 38, color: AppColors.teal),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Подтвердите ваш Email',
          textAlign: TextAlign.center,
          style: AppText.sora(size: 20, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Мы отправили 6-значный код на почту ${_emailController.text}. Введите его ниже, чтобы защитить аккаунт.',
          textAlign: TextAlign.center,
          style: AppText.work(size: 13.5, color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        _inputField(
          controller: _emailVerifyCodeController,
          label: 'Код из письма',
          hint: '123456',
          icon: Icons.key_rounded,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          title: 'Подтвердить Email',
          isLoading: _isLoading,
          onTap: _handleVerifyEmail,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              // Пропустить верификацию прямо сейчас
              if (ApiService.currentUser != null) {
                _routeByRole(ApiService.currentUser!);
              } else {
                setState(() => _mode = AuthMode.login);
              }
            },
            child: const Text('Подтвердить позже', style: TextStyle(color: AppColors.muted)),
          ),
        ),
      ],
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
    required IconData icon,
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
            Icon(icon, color: const Color(0xFFF39C12), size: 18),
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
