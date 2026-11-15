import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/platform_admin/platform_admin_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NEXOROrdersApp());
}

class NEXOROrdersApp extends StatefulWidget {
  const NEXOROrdersApp({super.key});

  @override
  State<NEXOROrdersApp> createState() => _NEXOROrdersAppState();
}

class _NEXOROrdersAppState extends State<NEXOROrdersApp> {
  late final AuthController _authController;
  ThemeMode themeMode = ThemeMode.dark;
  bool _showPlatformAdmin = false;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _authController.restoreSession();
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _authController.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NEXOR Orders',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AnimatedBuilder(
        animation: _authController,
        builder: (context, _) {
          if (_authController.status == AuthStatus.restoring) {
            return const _AppLoadingScreen();
          }

          final session = _authController.session;
          if (_authController.isAuthenticated && session != null) {
            return DashboardPage(
              onToggleTheme: () {
                setState(() {
                  themeMode = themeMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                });
              },
              onLogout: _confirmLogout,
              storeName: session.store.name,
              userName: session.user.fullName,
            );
          }

          if (_showPlatformAdmin) {
            return PlatformAdminPage(
              onBack: () => setState(() => _showPlatformAdmin = false),
            );
          }

          return AuthPage(
            controller: _authController,
            onPlatformAdminTap: () => setState(() => _showPlatformAdmin = true),
          );
        },
      ),
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                color: Color(0xFF6C63FF),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 18),
            Text('جارٍ استعادة جلسة NEXOR...'),
          ],
        ),
      ),
    );
  }
}
