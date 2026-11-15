import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_config.dart';

class PlatformAdminPage extends StatefulWidget {
  final VoidCallback onBack;
  const PlatformAdminPage({super.key, required this.onBack});

  @override
  State<PlatformAdminPage> createState() => _PlatformAdminPageState();
}

class _PlatformAdminPageState extends State<PlatformAdminPage> {
  static const _tokenKey = 'nexor.platform_admin_token';
  static const _accent = Color(0xFF8175FF);
  final _storage = const FlutterSecureStorage();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final Dio _dio;

  String? _token;
  Map<String, dynamic> _admin = {};
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _logs = [];
  bool _busy = false;
  bool _loading = false;
  bool _restoring = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl : '${ApiConfig.baseUrl}/';
    _dio = Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
      headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));
    _restoreAdmin();
  }

  Future<void> _restoreAdmin() async {
    try {
      final savedToken = await _storage.read(key: _tokenKey);
      if (savedToken != null && savedToken.isNotEmpty) {
        final response = await _dio.get('platform/auth/me', options: Options(headers: {'Authorization': 'Bearer $savedToken'}));
        if (!mounted) return;
        _token = savedToken;
        _admin = _map(response.data);
        await _load();
      }
    } catch (_) {
      await _storage.delete(key: _tokenKey);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return {};
  }

  List<Map<String, dynamic>> _list(dynamic value) => value is List ? value.map(_map).toList() : [];
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token'});

  String _errorText(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        final message = data['message'];
        return message is List ? message.join('\n') : message.toString();
      }
      if (error.type == DioExceptionType.connectionError) return 'تعذر الاتصال بالخادم. تأكد أن Backend يعمل.';
      if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) return 'انتهت مهلة الاتصال. حاول مجدداً.';
    }
    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'أدخل البريد الإلكتروني وكلمة المرور.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final response = await _dio.post('platform/auth/login', data: {'email': _email.text.trim(), 'password': _password.text});
      final data = _map(response.data);
      final token = data['accessToken']?.toString();
      if (token == null || token.isEmpty) throw Exception('لم يتم استلام رمز الجلسة.');
      _token = token;
      _admin = _map(data['admin']);
      await _storage.write(key: _tokenKey, value: token);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    if (_token == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final responses = await Future.wait([
        _dio.get('platform/dashboard', options: _authOptions),
        _dio.get('platform/stores', options: _authOptions),
        _dio.get('platform/audit-logs', options: _authOptions),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = _map(responses[0].data);
        _stores = _list(responses[1].data);
        _logs = _list(responses[2].data);
      });
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _storage.delete(key: _tokenKey);
    if (!mounted) return;
    setState(() { _token = null; _admin = {}; _stats = {}; _stores = []; _logs = []; _password.clear(); });
  }

  Future<void> _createStore() async {
    final name = TextEditingController();
    final contact = TextEditingController();
    final phone = TextEditingController();
    final amount = TextEditingController(text: '0');
    final paid = TextEditingController(text: '0');
    final customDays = TextEditingController(text: '30');
    final notes = TextEditingController();
    var plan = 'MONTHLY';
    var currency = 'SYP';
    var sending = false;

    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      backgroundColor: const Color(0xFF171B27),
      title: const Text('إضافة محل وإصدار كود', style: TextStyle(color: Colors.white)),
      content: SizedBox(width: 470, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _dialogField(name, 'اسم المحل *'),
        _dialogField(contact, 'اسم صاحب المحل'),
        _dialogField(phone, 'رقم الهاتف', keyboard: TextInputType.phone),
        _dropdown<String>('مدة الاشتراك', plan, const {
          'MONTHLY': 'شهري – شهر واحد', 'THREE_MONTHS': '3 أشهر', 'SIX_MONTHS': '6 أشهر', 'YEARLY': 'سنوي – 12 شهراً', 'CUSTOM': 'مدة مخصصة بالأيام',
        }, (v) => setDialogState(() => plan = v)),
        if (plan == 'CUSTOM') _dialogField(customDays, 'عدد الأيام', keyboard: TextInputType.number),
        Row(children: [Expanded(child: _dialogField(amount, 'قيمة الاشتراك', keyboard: const TextInputType.numberWithOptions(decimal: true))), const SizedBox(width: 9), Expanded(child: _dialogField(paid, 'المبلغ المدفوع', keyboard: const TextInputType.numberWithOptions(decimal: true)))]),
        _dropdown<String>('العملة', currency, const {'SYP': 'ليرة سورية', 'USD': 'دولار أمريكي'}, (v) => setDialogState(() => currency = v)),
        _dialogField(notes, 'ملاحظات', maxLines: 2),
      ]))),
      actions: [
        TextButton(onPressed: sending ? null : () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: sending ? null : () async {
            final a = double.tryParse(amount.text.trim()) ?? 0;
            final p = double.tryParse(paid.text.trim()) ?? 0;
            final days = int.tryParse(customDays.text.trim()) ?? 0;
            if (name.text.trim().length < 2 || p > a || (plan == 'CUSTOM' && (days < 1 || days > 1095))) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('تحقق من اسم المحل والمدة والمبالغ.')));
              return;
            }
            setDialogState(() => sending = true);
            try {
              final response = await _dio.post('platform/stores', options: _authOptions, data: {
                'storeName': name.text.trim(), 'contactName': contact.text.trim(), 'contactPhone': phone.text.trim(),
                'plan': plan, if (plan == 'CUSTOM') 'durationDays': days, 'amount': a, 'paidAmount': p, 'currency': currency, 'notes': notes.text.trim(),
              });
              final data = _map(response.data);
              final storeName = _map(data['store'])['name']?.toString() ?? name.text.trim();
              final code = data['activationCode']?.toString() ?? '';
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) await _showCode(code, storeName);
              await _load();
            } catch (e) {
              if (dialogContext.mounted) {
                setDialogState(() => sending = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(_errorText(e))));
              }
            }
          },
          icon: sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.vpn_key_rounded),
          label: const Text('إنشاء المحل والكود'),
        ),
      ],
    )));
    name.dispose(); contact.dispose(); phone.dispose(); amount.dispose(); paid.dispose(); customDays.dispose(); notes.dispose();
  }

  Future<void> _showCode(String code, String storeName) async {
    if (code.isEmpty || !mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF171B27),
      title: const Text('تم إنشاء المحل بنجاح', style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('كود التفعيل الخاص بـ $storeName', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 18),
        SelectableText(code, style: const TextStyle(color: Color(0xFFB8B0FF), fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 1.4), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        const Text('انسخ الكود وأرسله لصاحب المحل. لن يظهر كاملاً مرة أخرى.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        FilledButton.icon(onPressed: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (dialogContext.mounted) Navigator.pop(dialogContext);
          if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('تم نسخ كود التفعيل.')));
        }, icon: const Icon(Icons.copy_rounded), label: const Text('نسخ الكود')),
      ],
    ));
  }

  Future<void> _reissueCode(Map<String, dynamic> store) async {
    final id = store['id'].toString();
    try {
      final response = await _dio.post('platform/stores/$id/reissue-code', options: _authOptions);
      final data = _map(response.data);
      await _showCode(data['activationCode']?.toString() ?? '', store['name']?.toString() ?? 'المحل');
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(e))));
    }
  }

  Future<void> _renew(Map<String, dynamic> store, {bool enroll = false}) async {
    final amount = TextEditingController(text: '0');
    final paid = TextEditingController(text: '0');
    final days = TextEditingController(text: '30');
    final notes = TextEditingController();
    var plan = 'MONTHLY';
    var currency = 'SYP';
    var sending = false;
    final id = store['id'].toString();
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      backgroundColor: const Color(0xFF171B27),
      title: Text('${enroll ? 'تفعيل نظام الاشتراك' : 'تجديد اشتراك'} ${store['name']}', style: const TextStyle(color: Colors.white)),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _dropdown<String>('مدة التجديد', plan, const {'MONTHLY':'شهري','THREE_MONTHS':'3 أشهر','SIX_MONTHS':'6 أشهر','YEARLY':'سنوي','CUSTOM':'مخصص'}, (v) => setDialogState(() => plan = v)),
        if (plan == 'CUSTOM') _dialogField(days, 'عدد الأيام', keyboard: TextInputType.number),
        Row(children: [Expanded(child: _dialogField(amount, 'قيمة الاشتراك', keyboard: const TextInputType.numberWithOptions(decimal: true))), const SizedBox(width: 9), Expanded(child: _dialogField(paid, 'المدفوع', keyboard: const TextInputType.numberWithOptions(decimal: true)))]),
        _dropdown<String>('العملة', currency, const {'SYP':'ليرة سورية','USD':'دولار أمريكي'}, (v) => setDialogState(() => currency = v)),
        _dialogField(notes, 'ملاحظات'),
      ]))),
      actions: [
        TextButton(onPressed: sending ? null : () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
        FilledButton(onPressed: sending ? null : () async {
          final a = double.tryParse(amount.text.trim()) ?? 0;
          final p = double.tryParse(paid.text.trim()) ?? 0;
          final d = int.tryParse(days.text.trim()) ?? 0;
          if (p > a || (plan == 'CUSTOM' && (d < 1 || d > 1095))) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('تحقق من المبالغ والمدة.')));
            return;
          }
          setDialogState(() => sending = true);
          try {
            await _dio.post('platform/stores/$id/${enroll ? 'enroll' : 'renew'}', options: _authOptions, data: {'plan':plan, if (plan=='CUSTOM') 'durationDays':d, 'amount':a, 'paidAmount':p, 'currency':currency, 'notes':notes.text.trim()});
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            await _load();
          } catch (e) {
            if (dialogContext.mounted) { setDialogState(() => sending = false); ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(_errorText(e)))); }
          }
        }, child: Text(enroll ? 'تفعيل الاشتراك' : 'تأكيد التجديد')),
      ],
    )));
    amount.dispose(); paid.dispose(); days.dispose(); notes.dispose();
  }

  Future<void> _toggleSuspension(Map<String, dynamic> store) async {
    final id = store['id'].toString();
    final next = store['isSuspended'] != true;
    try {
      await _dio.patch('platform/stores/$id/suspension', options: _authOptions, data: {'isSuspended': next});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B0D12),
    body: SafeArea(child: _restoring ? const Center(child: CircularProgressIndicator()) : (_token == null ? _loginView() : _dashboardView())),
  );

  Widget _loginView() => Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 440),
    child: _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(alignment: Alignment.centerRight, child: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70))),
      const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFB8B0FF), size: 44),
      const SizedBox(height: 12),
      const Text('NEXOR OWNER', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      const SizedBox(height: 6),
      const Text('لوحة إدارة المحلات والاشتراكات', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 28),
      _loginField(_email, 'البريد الإلكتروني', Icons.alternate_email_rounded),
      const SizedBox(height: 13),
      _loginField(_password, 'كلمة المرور', Icons.lock_outline_rounded, obscure: true),
      if (_error != null) _errorBox(_error!),
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : _login, style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 17)), child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('دخول لوحة المالك', style: TextStyle(fontWeight: FontWeight.w900))),
      TextButton(onPressed: widget.onBack, child: const Text('العودة إلى تسجيل دخول المحل')),
    ])),
  )));

  Widget _dashboardView() => RefreshIndicator(
    onRefresh: _load,
    color: _accent,
    child: CustomScrollView(slivers: [
      SliverPadding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 10), sliver: SliverToBoxAdapter(child: _header())),
      if (_error != null) SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 22), sliver: SliverToBoxAdapter(child: _errorBox(_error!))),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10), sliver: SliverToBoxAdapter(child: _statsGrid())),
      SliverPadding(padding: const EdgeInsets.fromLTRB(22, 15, 22, 9), sliver: SliverToBoxAdapter(child: Row(children: [const Expanded(child: Text('المحلات والاشتراكات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))), FilledButton.icon(onPressed: _createStore, icon: const Icon(Icons.add_business_rounded), label: const Text('إضافة محل'))]))),
      if (_loading && _stores.isEmpty) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
      else if (_stores.isEmpty) SliverPadding(padding: const EdgeInsets.all(22), sliver: SliverToBoxAdapter(child: _empty('لم تتم إضافة أي محل بعد.')))
      else SliverPadding(padding: const EdgeInsets.fromLTRB(22, 4, 22, 18), sliver: SliverList.separated(itemCount: _stores.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (_, i) => _storeCard(_stores[i]))),
      SliverPadding(padding: const EdgeInsets.fromLTRB(22, 12, 22, 8), sliver: SliverToBoxAdapter(child: const Text('سجل العمليات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)))),
      SliverPadding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 28), sliver: SliverToBoxAdapter(child: _logsCard())),
    ]),
  );

  Widget _header() => _panel(Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 12, children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('NEXOR OWNER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 23, letterSpacing: 1.2)), const SizedBox(height: 5), Text('مرحباً ${_admin['fullName'] ?? 'مدير NEXOR'} — إدارة الاشتراكات', style: const TextStyle(color: Colors.white70))]),
    Wrap(spacing: 8, children: [OutlinedButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), label: const Text('تحديث')), OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout_rounded), label: const Text('خروج'))]),
  ]), gradient: true);

  Widget _statsGrid() {
    final data = [
      ('إجمالي المحلات', _stats['totalStores'] ?? 0, Icons.storefront_rounded, const Color(0xFF9A91FF)),
      ('اشتراكات فعالة', _stats['activeStores'] ?? 0, Icons.verified_rounded, const Color(0xFF4DD4A3)),
      ('اشتراكات منتهية', _stats['expiredStores'] ?? 0, Icons.timer_off_rounded, const Color(0xFFFF7777)),
      ('بانتظار التفعيل', _stats['awaitingActivation'] ?? 0, Icons.vpn_key_rounded, const Color(0xFFFFC66D)),
      ('تنتهي خلال 7 أيام', _stats['expiringSoon'] ?? 0, Icons.notifications_active_rounded, const Color(0xFFFFA45C)),
      ('محلات قديمة بلا اشتراك', _stats['legacyStores'] ?? 0, Icons.history_rounded, const Color(0xFFB0B7C8)),
      ('محلات موقوفة', _stats['suspendedStores'] ?? 0, Icons.pause_circle_outline_rounded, const Color(0xFFFF7777)),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 850 ? 3 : 2;
      return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: data.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.25), itemBuilder: (_, index) {
        final item = data[index];
        return _panel(Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: item.$4.withValues(alpha: .13), borderRadius: BorderRadius.circular(13)), child: Icon(item.$3, color: item.$4)), const SizedBox(width: 12), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item.$2}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)), Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11))]))]));
      });
    });
  }

  Widget _storeCard(Map<String, dynamic> store) {
    final status = store['status']?.toString() ?? 'EXPIRED';
    final sub = _map(store['currentSubscription'] ?? store['latestSubscription']);
    final code = _map(store['latestActivationCode']);
    final color = _statusColor(status);
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 8, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: _accent.withValues(alpha: .13), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.storefront_rounded, color: Color(0xFFB8B0FF))), const SizedBox(width: 11), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store['name']?.toString() ?? 'محل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)), Text(store['ownerName']?.toString() ?? store['contactName']?.toString() ?? 'بانتظار إنشاء الحساب', style: const TextStyle(color: Colors.white60, fontSize: 11))])]),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(30)), child: Text(_statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11))),
      ]),
      const SizedBox(height: 13),
      Wrap(spacing: 18, runSpacing: 9, children: [
        _detail(Icons.email_outlined, store['ownerEmail']?.toString() ?? '—'),
        _detail(Icons.phone_outlined, store['contactPhone']?.toString() ?? '—'),
        _detail(Icons.card_membership_rounded, sub['planName']?.toString() ?? 'لا يوجد اشتراك'),
        _detail(Icons.event_available_rounded, _date(sub['startsAt'])),
        _detail(Icons.event_busy_rounded, _date(sub['endsAt'])),
      ]),
      if (code.isNotEmpty) ...[const SizedBox(height: 11), Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .035), borderRadius: BorderRadius.circular(11)), child: Row(children: [const Icon(Icons.key_rounded, size: 15, color: Color(0xFFB8B0FF)), const SizedBox(width: 7), Text('الكود ${code['codeHint'] ?? '—'}', style: const TextStyle(color: Colors.white70, fontSize: 12)), const Spacer(), Text(_codeStatus(code['status']?.toString()), style: const TextStyle(color: Colors.white54, fontSize: 11))]))],
      const SizedBox(height: 13),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (status == 'LEGACY') FilledButton.tonalIcon(onPressed: () => _renew(store, enroll: true), icon: const Icon(Icons.verified_user_rounded, size: 17), label: const Text('إدخال بنظام الاشتراك')),
        if (status == 'AWAITING_ACTIVATION') OutlinedButton.icon(onPressed: () => _reissueCode(store), icon: const Icon(Icons.key_rounded, size: 17), label: const Text('إعادة إصدار الكود')),
        if (store['subscriptionRequired'] == true) FilledButton.tonalIcon(onPressed: () => _renew(store), icon: const Icon(Icons.autorenew_rounded, size: 17), label: const Text('تجديد الاشتراك')),
        OutlinedButton.icon(onPressed: () => _toggleSuspension(store), icon: Icon(store['isSuspended'] == true ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 17), label: Text(store['isSuspended'] == true ? 'إلغاء الإيقاف' : 'إيقاف المحل')),
      ]),
    ]));
  }

  Widget _logsCard() {
    if (_logs.isEmpty) return _empty('لا توجد عمليات مسجلة بعد.');
    return _panel(Column(children: _logs.take(12).map((log) {
      final store = _map(log['store']);
      return ListTile(dense: true, leading: const Icon(Icons.history_rounded, color: Color(0xFFAAA1FF)), title: Text(_actionLabel(log['action']?.toString()), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)), subtitle: Text('${store['name'] ?? '—'} • ${_date(log['createdAt'])}', style: const TextStyle(color: Colors.white54, fontSize: 11)));
    }).toList()));
  }

  Widget _empty(String text) => _panel(Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, style: const TextStyle(color: Colors.white60)))));
  Widget _panel(Widget child, {bool gradient = false}) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: gradient ? null : const Color(0xFF151923), gradient: gradient ? const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF29264D), Color(0xFF171B2A), Color(0xFF141923)]) : null, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .07))), child: child);
  Widget _detail(IconData icon, String value) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: Colors.white38), const SizedBox(width: 6), Text(value, style: const TextStyle(color: Colors.white60, fontSize: 11))]);
  Widget _loginField(TextEditingController c, String label, IconData icon, {bool obscure = false}) => TextField(controller: c, obscureText: obscure, keyboardType: obscure ? TextInputType.visiblePassword : TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white60), prefixIcon: Icon(icon, color: Colors.white54), filled: true, fillColor: Colors.white.withValues(alpha: .04), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: Colors.white.withValues(alpha: .1)))));
  Widget _dialogField(TextEditingController c, String label, {TextInputType? keyboard, int maxLines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, keyboardType: keyboard, maxLines: maxLines, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: Colors.white.withValues(alpha: .13))))));
  Widget _dropdown<T>(String label, T value, Map<T, String> items, ValueChanged<T> onChanged) => Padding(padding: const EdgeInsets.only(bottom: 10), child: DropdownButtonFormField<T>(value: value, decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(11))), dropdownColor: const Color(0xFF222738), style: const TextStyle(color: Colors.white), items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) { if (v != null) onChanged(v); }));
  Widget _errorBox(String value) => Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFF6666).withValues(alpha: .10), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFFF6666).withValues(alpha: .25))), child: Text(value, style: const TextStyle(color: Color(0xFFFFA4A4), fontSize: 12)));

  Color _statusColor(String value) => switch (value) {'ACTIVE' => const Color(0xFF4DD4A3), 'AWAITING_ACTIVATION' => const Color(0xFFFFC66D), 'SCHEDULED' => const Color(0xFF79B8FF), 'SUSPENDED' => const Color(0xFFFF7777), 'LEGACY' => const Color(0xFFB0B7C8), _ => const Color(0xFFFF7777)};
  String _statusLabel(String value) => switch (value) {'ACTIVE' => 'فعال', 'AWAITING_ACTIVATION' => 'بانتظار التفعيل', 'SCHEDULED' => 'مجدول', 'SUSPENDED' => 'موقوف', 'LEGACY' => 'حساب قديم - بلا اشتراك', _ => 'منتهي'};
  String _codeStatus(String? value) => switch (value) {'AVAILABLE' => 'غير مستخدم', 'USED' => 'مستخدم', 'REVOKED' => 'ملغى', 'EXPIRED' => 'منتهي', _ => '—'};
  String _actionLabel(String? value) => switch (value) {'STORE_CREATED_WITH_ACTIVATION_CODE' => 'إنشاء محل وكود تفعيل', 'LEGACY_STORE_ENROLLED' => 'إدخال محل قديم بنظام الاشتراك', 'ACTIVATION_CODE_REISSUED' => 'إعادة إصدار كود تفعيل', 'ACTIVATION_CODE_REDEEMED' => 'تفعيل حساب المحل', 'SUBSCRIPTION_RENEWED' => 'تجديد اشتراك', 'STORE_SUSPENDED' => 'إيقاف محل', 'STORE_REACTIVATED' => 'إعادة تفعيل محل', _ => value ?? 'عملية'};
  String _date(dynamic value) { if (value == null) return '—'; final d = DateTime.tryParse(value.toString()); if (d == null) return '—'; return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}'; }
}
