import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../products/product_catalog.dart';

class SettingsPage extends StatefulWidget {
  final String storeName;
  final String userName;
  final ValueChanged<String>? onStoreNameChanged;
  final VoidCallback? onToggleTheme;

  const SettingsPage({
    super.key,
    required this.storeName,
    required this.userName,
    this.onStoreNameChanged,
    this.onToggleTheme,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient.instance;
  late final TextEditingController _storeController;
  late final TextEditingController _exchangeController;

  String _currency = 'SYP';
  bool _notifyNewOrders = true;
  bool _notifyLowStock = true;
  bool _notifyReturns = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _rateHistory = [];

  String _savedStoreName = '';
  String _savedRate = '15000';
  String _savedCurrency = 'SYP';
  bool _savedNotifyNewOrders = true;
  bool _savedNotifyLowStock = true;
  bool _savedNotifyReturns = true;

  @override
  void initState() {
    super.initState();
    _storeController = TextEditingController(text: widget.storeName);
    _exchangeController = TextEditingController(text: '15000');
    _loadSettings();
  }

  @override
  void dispose() {
    _storeController.dispose();
    _exchangeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await _api.get<dynamic>('settings/store');
      final data = _asMap(response.data);
      _applySettings(data);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
      if (mounted) widget.onStoreNameChanged?.call(_savedStoreName);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر قراءة إعدادات المتجر من الخادم.';
      });
    }
  }

  void _applySettings(Map<String, dynamic> data) {
    final store = _asMap(data['store']);
    final preferences = _asMap(data['preferences']);
    final name = _stringValue(store['name'], widget.storeName);
    final rate = _numberValue(store['exchangeRateSypPerUsd'], 15000);
    final currency = _stringValue(store['defaultCurrency'], 'SYP');

    _storeController.text = name;
    _exchangeController.text = _plainNumber(rate);
    _currency = currency == 'USD' ? 'USD' : 'SYP';
    _notifyNewOrders = preferences['notifyNewOrders'] is bool
        ? preferences['notifyNewOrders'] as bool
        : true;
    _notifyLowStock = preferences['notifyLowStock'] is bool
        ? preferences['notifyLowStock'] as bool
        : true;
    _notifyReturns = preferences['notifyReturns'] is bool
        ? preferences['notifyReturns'] as bool
        : true;

    final history = data['exchangeRateHistory'];
    _rateHistory = history is List
        ? history.whereType<Map>().map(_asMap).toList(growable: false)
        : <Map<String, dynamic>>[];

    _savedStoreName = name;
    _savedRate = _plainNumber(rate);
    _savedCurrency = _currency;
    _savedNotifyNewOrders = _notifyNewOrders;
    _savedNotifyLowStock = _notifyLowStock;
    _savedNotifyReturns = _notifyReturns;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    final rate = double.tryParse(_exchangeController.text.trim());
    if (rate == null || !rate.isFinite || rate <= 0) {
      _showMessage('سعر الصرف يجب أن يكون رقماً أكبر من صفر.', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await _api.patch<dynamic>(
        'settings/store',
        data: {
          'name': _storeController.text.trim(),
          'defaultCurrency': _currency,
          'exchangeRateSypPerUsd': _roundRate(rate),
          'notifyNewOrders': _notifyNewOrders,
          'notifyLowStock': _notifyLowStock,
          'notifyReturns': _notifyReturns,
        },
      );

      final data = _asMap(response.data);
      _applySettings(data);

      // Reload the product catalog so new forms use the saved central rate.
      // Historical product and order snapshots are not edited by this refresh.
      await ProductCatalog.instance.load(force: true);
      widget.onStoreNameChanged?.call(_savedStoreName);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _successMessage = 'تم حفظ إعدادات المتجر على قاعدة البيانات بنجاح.';
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = _friendlyError(error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.redAccent : const Color(0xFF20B990),
        ),
      );
  }

  void _discardChanges() {
    setState(() {
      _storeController.text = _savedStoreName;
      _exchangeController.text = _savedRate;
      _currency = _savedCurrency;
      _notifyNewOrders = _savedNotifyNewOrders;
      _notifyLowStock = _savedNotifyLowStock;
      _notifyReturns = _savedNotifyReturns;
      _successMessage = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _loadSettings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 18),
              if (_errorMessage != null) ...[
                _messageBanner(_errorMessage!, isError: true),
                const SizedBox(height: 14),
              ],
              if (_successMessage != null) ...[
                _messageBanner(_successMessage!, isError: false),
                const SizedBox(height: 14),
              ],
              if (_isLoading)
                const SizedBox(
                  height: 340,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null && _savedStoreName.isEmpty)
                _loadErrorState(context)
              else ...[
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final storeCard = _storeCard(context);
                          final currencyCard = _currencyCard(context);
                          if (constraints.maxWidth < 900) {
                            return Column(
                              children: [
                                storeCard,
                                const SizedBox(height: 14),
                                currencyCard,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: storeCard),
                              const SizedBox(width: 14),
                              Expanded(child: currencyCard),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _notificationsCard(context),
                      const SizedBox(height: 14),
                      _appearanceCard(context),
                      const SizedBox(height: 14),
                      _accountCard(context),
                      if (_rateHistory.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _rateHistoryCard(context),
                      ],
                      const SizedBox(height: 20),
                      _buildSaveBar(context),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'NEXOR Orders • إعدادات محفوظة على مستوى المتجر',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .38),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF292443), Color(0xFF171923)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B84FF).withValues(alpha: .23),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: .10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B84FF).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Color(0xFFB2ADFF),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WORKSPACE CONTROL',
                  style: TextStyle(
                    color: Color(0xFFA9A2FF),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'إعدادات المتجر',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إدارة الهوية، العملة، سعر الصرف وتفضيلات مساحة العمل.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .66),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'تحديث الإعدادات من الخادم',
            onPressed: _isLoading || _isSaving ? null : _loadSettings,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .08),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
    );
  }

  Widget _storeCard(BuildContext context) {
    return _sectionCard(
      context,
      icon: Icons.storefront_rounded,
      title: 'بيانات المتجر',
      subtitle: 'اسم المتجر الذي يظهر في مساحة العمل والتقارير.',
      children: [
        TextFormField(
          controller: _storeController,
          textInputAction: TextInputAction.next,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'اسم المتجر',
            hintText: 'أدخل اسم المتجر',
            prefixIcon: Icon(Icons.storefront_outlined),
            counterText: '',
          ),
          validator: (value) {
            if ((value ?? '').trim().length < 2)
              return 'اسم المتجر يجب أن يتكون من حرفين على الأقل.';
            return null;
          },
        ),
        const SizedBox(height: 8),
        _infoLine(
          context,
          icon: Icons.cloud_done_outlined,
          label: 'مصدر الإعدادات',
          value: 'قاعدة البيانات السحابية Neon',
          valueColor: const Color(0xFF25B98D),
        ),
      ],
    );
  }

  Widget _currencyCard(BuildContext context) {
    return _sectionCard(
      context,
      icon: Icons.currency_exchange_rounded,
      title: 'العملة وسعر الصرف',
      subtitle: 'السعر المركزي الذي تعتمد عليه العمليات الجديدة.',
      children: [
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: const InputDecoration(
            labelText: 'العملة الافتراضية للمتجر',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'SYP', child: Text('الليرة السورية (SYP)')),
            DropdownMenuItem(
              value: 'USD',
              child: Text('الدولار الأمريكي (USD)'),
            ),
          ],
          onChanged: (value) => setState(() => _currency = value ?? 'SYP'),
        ),
        const SizedBox(height: 8),
        _smallHint(
          context,
          'يتم حفظ العملة الافتراضية ضمن بيانات المتجر؛ توحيد طريقة عرض العملة في جميع الجداول والتقارير سيأتي كتحديث واجهة مستقل.',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _exchangeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'سعر صرف الدولار الواحد',
            prefixIcon: Icon(Icons.swap_horiz_rounded),
            suffixText: 'ل.س / USD',
          ),
          validator: (value) {
            final rate = double.tryParse((value ?? '').trim());
            if (rate == null || !rate.isFinite || rate <= 0)
              return 'أدخل سعراً أكبر من صفر.';
            if (rate > 1000000000000) return 'سعر الصرف المدخل كبير جداً.';
            return null;
          },
        ),
        const SizedBox(height: 9),
        _smallHint(
          context,
          'تغيير السعر لا يعدّل الفواتير والطلبات القديمة؛ يتم حفظ سعر الصرف داخل كل عملية كما كان وقت تسجيلها.',
        ),
      ],
    );
  }

  Widget _notificationsCard(BuildContext context) {
    return _sectionCard(
      context,
      icon: Icons.notifications_active_outlined,
      title: 'تفضيلات التنبيه',
      subtitle: 'احفظ أنواع التنبيهات التي تريد تفعيلها لمساحة عملك.',
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _notifyNewOrders,
          activeThumbColor: const Color(0xFF8175FF),
          onChanged: (value) => setState(() => _notifyNewOrders = value),
          title: const Text(
            'الطلبات الجديدة',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          subtitle: const Text(
            'تنبيه عند وصول طلب جديد.',
            style: TextStyle(fontSize: 10),
          ),
        ),
        const Divider(height: 1),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _notifyLowStock,
          activeThumbColor: const Color(0xFF8175FF),
          onChanged: (value) => setState(() => _notifyLowStock = value),
          title: const Text(
            'انخفاض المخزون',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          subtitle: const Text(
            'تنبيه عند وصول المنتج إلى الحد الأدنى أو أقل.',
            style: TextStyle(fontSize: 10),
          ),
        ),
        const Divider(height: 1),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _notifyReturns,
          activeThumbColor: const Color(0xFF8175FF),
          onChanged: (value) => setState(() => _notifyReturns = value),
          title: const Text(
            'المرتجعات',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          subtitle: const Text(
            'تنبيه عند إنشاء مرتجع أو تأكيد استلامه.',
            style: TextStyle(fontSize: 10),
          ),
        ),
        const SizedBox(height: 8),
        _smallHint(
          context,
          'التفضيلات تُحفظ على المتجر. إرسال إشعارات فورية أو عبر WhatsApp يحتاج تفعيل مركز الإشعارات وربط قناة الإرسال.',
        ),
      ],
    );
  }

  Widget _appearanceCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _sectionCard(
      context,
      icon: Icons.palette_outlined,
      title: 'المظهر واللغة',
      subtitle: 'تفضيلات العرض المتاحة حالياً في التطبيق.',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.dark_mode_outlined,
            color: Color(0xFF958BFF),
          ),
          title: const Text(
            'المظهر',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          subtitle: Text(
            isDark ? 'الوضع الليلي مفعّل' : 'الوضع النهاري مفعّل',
            style: const TextStyle(fontSize: 10),
          ),
          trailing: OutlinedButton(
            onPressed: widget.onToggleTheme,
            child: Text(isDark ? 'تفعيل النهاري' : 'تفعيل الليلي'),
          ),
        ),
        const Divider(height: 1),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.language_rounded, color: Color(0xFF958BFF)),
          title: Text(
            'لغة التطبيق',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          subtitle: Text(
            'العربية — اللغة المتاحة حالياً',
            style: TextStyle(fontSize: 10),
          ),
          trailing: Icon(
            Icons.lock_outline_rounded,
            size: 17,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _accountCard(BuildContext context) {
    return _sectionCard(
      context,
      icon: Icons.admin_panel_settings_outlined,
      title: 'الحساب والصلاحيات',
      subtitle: 'معلومات الحساب المستخدم حالياً في NEXOR Orders.',
      children: [
        _infoLine(
          context,
          icon: Icons.person_outline_rounded,
          label: 'اسم المستخدم',
          value: widget.userName.isEmpty ? 'غير محدد' : widget.userName,
        ),
        const Divider(height: 1),
        _infoLine(
          context,
          icon: Icons.verified_user_outlined,
          label: 'نوع الحساب',
          value: 'حسب صلاحيات تسجيل الدخول',
        ),
        const SizedBox(height: 7),
        _smallHint(
          context,
          'تغيير كلمة المرور وإدارة المستخدمين والصلاحيات تحتاج شاشة أمان وإدارة مستخدمين مستقلة؛ لم يتم عرض أزرار غير مفعّلة هنا.',
        ),
      ],
    );
  }

  Widget _rateHistoryCard(BuildContext context) {
    return _sectionCard(
      context,
      icon: Icons.history_rounded,
      title: 'سجل تغييرات سعر الصرف',
      subtitle: 'آخر التعديلات المسجلة على سعر الصرف المركزي.',
      children: _rateHistory.take(6).map((item) {
        final before = _numberValue(item['oldRateSypPerUsd'], 0);
        final after = _numberValue(item['newRateSypPerUsd'], 0);
        final changedAt = DateTime.tryParse('${item['changedAt'] ?? ''}');
        final date = changedAt == null
            ? 'تاريخ غير معروف'
            : '${changedAt.year}/${changedAt.month.toString().padLeft(2, '0')}/${changedAt.day.toString().padLeft(2, '0')}  ${changedAt.hour.toString().padLeft(2, '0')}:${changedAt.minute.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFF958BFF),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قديم: ${_plainNumber(before)}  •  جديد: ${_plainNumber(after)} ل.س',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      date,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .48),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveBar(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _discardChanges,
          icon: const Icon(Icons.undo_rounded, size: 17),
          label: const Text('تراجع عن التعديلات'),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveSettings,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF786BFA),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات'),
        ),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: .32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8175FF).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF958BFF), size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: .48,
                          ),
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoLine(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.onSurface.withValues(alpha: .5),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color:
                    valueColor ??
                    theme.colorScheme.onSurface.withValues(alpha: .72),
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallHint(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF958BFF),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 10, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBanner(String message, {required bool isError}) {
    final color = isError ? const Color(0xFFE36E77) : const Color(0xFF20B990);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadErrorState(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: Color(0xFFE36E77),
              ),
              const SizedBox(height: 12),
              const Text(
                'تعذر تحميل إعدادات المتجر',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 7),
              Text(
                _errorMessage ?? 'تحقق من اتصال الخادم ثم حاول مجدداً.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 15),
              FilledButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message;
      if (message is List && message.isNotEmpty) return message.join('\n');
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'تعذر الاتصال بالخادم. تأكد أن NestJS يعمل على المنفذ 3000.';
    }
    if (error.response?.statusCode == 401)
      return 'انتهت جلسة الدخول. سجّل الدخول مجدداً.';
    return 'تعذر تنفيذ العملية. حاول مرة أخرى.';
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map)
    return value.map((key, item) => MapEntry(key.toString(), item));
  return <String, dynamic>{};
}

String _stringValue(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double _numberValue(dynamic value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

String _plainNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value
          .toStringAsFixed(6)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

double _roundRate(double value) => (value * 1000000).round() / 1000000;
