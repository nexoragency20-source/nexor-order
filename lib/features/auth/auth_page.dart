import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_controller.dart';

class AuthPage extends StatefulWidget {
  final AuthController controller;
  final VoidCallback onPlatformAdminTap;

  const AuthPage({super.key, required this.controller, required this.onPlatformAdminTap});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _activationCodeController = TextEditingController();

  late final AnimationController _entranceController;
  late final AnimationController _ambientController;
  late final Animation<double> _brandEntry;
  late final Animation<double> _showcaseEntry;
  late final Animation<double> _formEntry;
  late final Animation<double> _tagEntry;
  late final Animation<double> _headlineEntry;
  late final Animation<double> _descriptionEntry;
  late final Animation<double> _featureOneEntry;
  late final Animation<double> _featureTwoEntry;
  late final Animation<double> _featureThreeEntry;
  late final Animation<double> _previewEntry;
  late final Animation<double> _modeEntry;
  late final Animation<double> _emailEntry;
  late final Animation<double> _passwordEntry;
  late final Animation<double> _buttonEntry;
  late final Animation<double> _bottomEntry;

  bool _isRegister = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  static const _accent = Color(0xFF8175FF);
  static const _accentBright = Color(0xFFA69EFF);
  static const _surface = Color(0xFF121520);

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1550),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    )..repeat(reverse: true);

    _brandEntry = _interval(.02, .48);
    _showcaseEntry = _interval(.06, .78);
    _formEntry = _interval(.14, .84);
    _tagEntry = _interval(.23, .58);
    _headlineEntry = _interval(.29, .68);
    _descriptionEntry = _interval(.37, .75);
    _featureOneEntry = _interval(.44, .79);
    _featureTwoEntry = _interval(.49, .84);
    _featureThreeEntry = _interval(.54, .89);
    _previewEntry = _interval(.60, .96);
    _modeEntry = _interval(.43, .76);
    _emailEntry = _interval(.51, .81);
    _passwordEntry = _interval(.59, .88);
    _buttonEntry = _interval(.73, .98);
    _bottomEntry = _interval(.80, 1);

    _entranceController.forward();
  }

  Animation<double> _interval(double start, double end) {
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _activationCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || widget.controller.isBusy) return;

    setState(() => _errorMessage = null);
    bool success;

    if (_isRegister) {
      success = await widget.controller.register(
        activationCode: _activationCodeController.text,
        email: _emailController.text,
        fullName: _nameController.text,
        password: _passwordController.text,
      );
    } else {
      success = await widget.controller.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }

    if (!success && mounted) {
      setState(() => _errorMessage = widget.controller.errorMessage);
    }
  }

  String? _required(String? value, String label, {int minLength = 2}) {
    if (value == null || value.trim().isEmpty) return '$label مطلوب';
    if (value.trim().length < minLength) return '$label قصير جداً';
    return null;
  }

  Widget _entrance(
    Widget child,
    Animation<double> animation, {
    Offset from = const Offset(0, .055),
    bool scale = false,
  }) {
    Widget result = FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: from,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );

    if (scale) {
      result = ScaleTransition(
        scale: Tween<double>(begin: .965, end: 1).animate(animation),
        child: result,
      );
    }
    return result;
  }

  Widget _ambientOrb({required double size, required Color color}) {
    return AnimatedBuilder(
      animation: _ambientController,
      child: _GlowOrb(size: size, color: color),
      builder: (context, child) {
        final wave = math.sin(_ambientController.value * math.pi);
        return Transform.translate(
          offset: Offset(wave * 13, -wave * 17),
          child: Transform.scale(scale: 1 + wave * .035, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 980;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080A10),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF101322),
                      Color(0xFF080A10),
                      Color(0xFF090D17),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -180,
              right: -120,
              child: _ambientOrb(size: 520, color: const Color(0xFF5548D8)),
            ),
            Positioned(
              bottom: -240,
              left: -130,
              child: _ambientOrb(size: 540, color: const Color(0xFF243D82)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, _) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1220),
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _entrance(
                                      _buildShowcase(),
                                      _showcaseEntry,
                                      from: const Offset(-.045, .025),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: _entrance(
                                      _buildFormPanel(),
                                      _formEntry,
                                      from: const Offset(.055, .035),
                                      scale: true,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _entrance(
                                    _buildCompactBrand(),
                                    _brandEntry,
                                    from: const Offset(0, -.08),
                                  ),
                                  const SizedBox(height: 24),
                                  _entrance(
                                    _buildFormPanel(),
                                    _formEntry,
                                    from: const Offset(0, .075),
                                    scale: true,
                                  ),
                                  _entrance(_buildFooter(), _bottomEntry),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 18,
              left: 22,
              child: FadeTransition(
                opacity: _bottomEntry,
                child: _securePill(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _securePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_moon_outlined, color: Color(0xFF9B92FF), size: 14),
          SizedBox(width: 7),
          Text(
            'SECURE ACCESS',
            style: TextStyle(
              color: Color(0xFFC7C2FF),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcase() {
    return Container(
      constraints: const BoxConstraints(minHeight: 690),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF24234A), Color(0xFF141827), Color(0xFF10131C)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: .12),
            blurRadius: 60,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -80,
            top: 160,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .05),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            left: -30,
            top: 210,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .06)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _entrance(_brandMark(), _brandEntry, from: const Offset(0, -.08)),
              const SizedBox(height: 66),
              _entrance(_heroTag(), _tagEntry),
              const SizedBox(height: 24),
              _entrance(
                const Text(
                  'إدارة أذكى.\nتجارة بلا تعقيد.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    height: 1.28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.7,
                  ),
                ),
                _headlineEntry,
                from: const Offset(0, .07),
              ),
              const SizedBox(height: 16),
              _entrance(
                Text(
                  'كل طلباتك وعملاؤك ومنتجاتك في مساحة عمل واحدة،\nبتجربة مصممة لتمنحك رؤية أوضح وتحكماً أكبر.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .64),
                    fontSize: 14,
                    height: 1.9,
                  ),
                ),
                _descriptionEntry,
              ),
              const SizedBox(height: 34),
              _entrance(
                _featureLine(
                  Icons.shopping_bag_outlined,
                  'إدارة الطلبات والمبيعات من مكان واحد',
                ),
                _featureOneEntry,
              ),
              const SizedBox(height: 17),
              _entrance(
                _featureLine(
                  Icons.qr_code_2_rounded,
                  'منتجات ومخزون وباركود منظم',
                ),
                _featureTwoEntry,
              ),
              const SizedBox(height: 17),
              _entrance(
                _featureLine(
                  Icons.auto_awesome_rounded,
                  'مساعد ذكي لتحليل المحادثات والطلبات',
                ),
                _featureThreeEntry,
              ),
              const SizedBox(height: 48),
              _entrance(_miniPreviewCard(), _previewEntry, scale: true),
              const SizedBox(height: 24),
              Text(
                'NEXOR SOFTWARE SOLUTIONS  •  BUILT FOR GROWTH',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .35),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .11)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: _accentBright, size: 15),
          SizedBox(width: 8),
          Text(
            'SMART COMMERCE WORKSPACE',
            style: TextStyle(
              color: Color(0xFFD6D2FF),
              letterSpacing: 1.25,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBrand() {
    return Column(
      children: [
        _brandMark(),
        const SizedBox(height: 18),
        const Text(
          'إدارة أذكى. تجارة بلا تعقيد.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'مساحة عمل متكاملة لإدارة متجرك',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .58),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildFormPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(34, 34, 34, 28),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .24),
            blurRadius: 45,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: _accent.withValues(alpha: .055),
            blurRadius: 38,
            spreadRadius: 1,
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 430),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, .16),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Row(
                  key: ValueKey(_isRegister),
                  children: [
                    Expanded(
                      child: Text(
                        _isRegister ? 'أنشئ حساب محلك' : 'مرحباً بعودتك',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: _accent.withValues(alpha: .23),
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_person_rounded,
                        color: _accentBright,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, .12),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  _isRegister
                      ? 'أدخل كود الاشتراك المرسل من NEXOR لإنشاء حساب محلك.'
                      : 'سجّل الدخول بأمان للمتابعة إلى مساحة عملك.',
                  key: ValueKey('subtitle-$_isRegister'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .55),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _entrance(_authModeSwitch(), _modeEntry),
              const SizedBox(height: 23),
              _registerFields(),
              _entrance(
                _field(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'البريد الإلكتروني مطلوب';
                    final email = value.trim();
                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(email)) {
                      return 'أدخل بريداً إلكترونياً صحيحاً';
                    }
                    return null;
                  },
                ),
                _emailEntry,
              ),
              const SizedBox(height: 13),
              _entrance(
                _field(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  icon: Icons.key_rounded,
                  obscureText: _obscurePassword,
                  action: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white54,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'كلمة المرور مطلوبة';
                    if (_isRegister && value.length < 8) {
                      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                    }
                    if (value.length > 72) return 'كلمة المرور طويلة جداً';
                    return null;
                  },
                ),
                _passwordEntry,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(sizeFactor: animation, child: child),
                ),
                child: !_isRegister
                    ? Align(
                        key: const ValueKey('forgot-password'),
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _showInfo(
                            'استعادة كلمة المرور',
                            'سيتم تفعيل استعادة كلمة المرور من خلال البريد الإلكتروني في مرحلة لاحقة.',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _accentBright,
                          ),
                          child: const Text(
                            'نسيت كلمة المرور؟',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('no-forgot-password'),
                      ),
              ),
              _errorBanner(),
              const SizedBox(height: 15),
              _entrance(
                _submitButton(),
                _buttonEntry,
                from: const Offset(0, .08),
              ),
              const SizedBox(height: 16),
              _entrance(_accountModeRow(), _bottomEntry),
              const SizedBox(height: 8),
              _entrance(_trustLine(), _bottomEntry),
              const SizedBox(height: 9),
              TextButton.icon(
                onPressed: widget.onPlatformAdminTap,
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
                label: const Text('دخول إدارة NEXOR'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFAAA4FF)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _registerFields() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _isRegister
          ? Column(
              key: const ValueKey('register-extra-fields'),
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  controller: _nameController,
                  label: 'الاسم الكامل',
                  icon: Icons.person_outline_rounded,
                  validator: (value) => _required(value, 'الاسم'),
                ),
                const SizedBox(height: 13),
                _field(
                  controller: _activationCodeController,
                  label: 'كود التفعيل الخاص بالمحل',
                  icon: Icons.vpn_key_outlined,
                  validator: (value) => _required(value, 'كود التفعيل', minLength: 8),
                ),
                const SizedBox(height: 13),
              ],
            )
          : const SizedBox.shrink(key: ValueKey('no-register-extra-fields')),
    );
  }

  Widget _errorBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _errorMessage == null
          ? const SizedBox.shrink(key: ValueKey('no-auth-error'))
          : Container(
              key: ValueKey(_errorMessage),
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: .28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFF7777),
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFFF8A8A),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: .25),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: widget.controller.isBusy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _accent.withValues(alpha: .5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: widget.controller.isBusy
                ? const SizedBox(
                    key: ValueKey('auth-loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    key: ValueKey('auth-action-$_isRegister'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRegister ? 'إنشاء الحساب وتفعيل الاشتراك' : 'تسجيل الدخول',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_back_rounded, size: 19),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _accountModeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isRegister ? 'لديك حساب بالفعل؟' : 'ليس لديك حساب؟',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .58),
            fontSize: 12,
          ),
        ),
        TextButton(
          onPressed: widget.controller.isBusy
              ? null
              : () => _changeMode(!_isRegister),
          style: TextButton.styleFrom(foregroundColor: _accentBright),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Text(
              _isRegister ? 'سجّل الدخول' : 'أنشئ حساباً',
              key: ValueKey('mode-link-$_isRegister'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _trustLine() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 14,
          color: Colors.white.withValues(alpha: .38),
        ),
        const SizedBox(width: 7),
        Text(
          'اتصال محمي  •  NEXOR Secure Workspace',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .36),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _authModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeButton(
              'تسجيل الدخول',
              !_isRegister,
              () => _changeMode(false),
            ),
          ),
          Expanded(
            child: _modeButton(
              'إنشاء حساب',
              _isRegister,
              () => _changeMode(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(String title, bool active, VoidCallback onTap) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(colors: [_accent, Color(0xFF685CE5)])
            : null,
        borderRadius: BorderRadius.circular(11),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _accent.withValues(alpha: .20),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextButton(
        onPressed: widget.controller.isBusy ? null : onTap,
        style: TextButton.styleFrom(
          foregroundColor: active ? Colors.white : Colors.white60,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 240),
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            fontSize: 12,
          ),
          child: Text(title),
        ),
      ),
    );
  }

  void _changeMode(bool register) {
    if (_isRegister == register || widget.controller.isBusy) return;
    setState(() {
      _isRegister = register;
      _errorMessage = null;
    });
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: action,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: _accentBright,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: .55),
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, size: 19, color: Colors.white54),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF0B0E16),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .09)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .09)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.3),
        ),
      ),
    );
  }

  Widget _brandMark() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _ambientController,
          builder: (context, child) {
            final wave = math.sin(_ambientController.value * math.pi);
            return Transform.rotate(
              angle: (wave - .5) * .055,
              child: Transform.scale(scale: 1 + wave * .025, child: child),
            );
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_accentBright, _accent, Color(0xFF594ED2)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: .36),
                  blurRadius: 26,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEXOR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: 2,
              ),
            ),
            Text(
              'ORDERS',
              style: TextStyle(
                color: _accentBright,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _featureLine(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Icon(icon, color: _accentBright, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFE3E2F0),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'نظرة سريعة على متجرك',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF39D6A2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'WORKSPACE',
                style: TextStyle(
                  color: Color(0xFFB8B3FF),
                  fontSize: 8,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const Row(
            children: [
              Expanded(
                child: _PreviewMetric(
                  label: 'الطلبات',
                  value: '128',
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _PreviewMetric(
                  label: 'العملاء',
                  value: '1.2K',
                  icon: Icons.groups_2_outlined,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _PreviewMetric(
                  label: 'المبيعات',
                  value: '4.8M',
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        'NEXOR SOFTWARE SOLUTIONS  •  SECURE WORKSPACE',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .35),
          fontSize: 9,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _showInfo(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF171B27),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PreviewMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFADA7FF), size: 16),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: .18),
              color.withValues(alpha: .02),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
