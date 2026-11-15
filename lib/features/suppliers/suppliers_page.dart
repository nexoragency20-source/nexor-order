import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../products/product_catalog.dart';
import '../purchases/purchase_catalog.dart';
import '../purchases/purchase_models.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final _catalog = PurchaseCatalog.instance;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _catalog.load(force: true);
    ProductCatalog.instance.load();
  }

  List<SupplierModel> get _filteredSuppliers {
    final query = _searchController.text.trim().toLowerCase();
    return _catalog.suppliers.where((supplier) {
      return supplier.isActive &&
          (query.isEmpty ||
              supplier.name.toLowerCase().contains(query) ||
              supplier.phone.toLowerCase().contains(query) ||
              supplier.id.toLowerCase().contains(query));
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AnimatedBuilder(
        animation: Listenable.merge([_catalog, ProductCatalog.instance]),
        builder: (context, _) {
          final suppliers = _filteredSuppliers;
          final rate = ProductCatalog.instance.exchangeRateSypPerUsd;
          final totalBalance = _catalog.totalSupplierBalancesUsd;
          if (_catalog.isLoading && !_catalog.hasLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_catalog.errorMessage != null && !_catalog.hasLoaded) {
            return _loadErrorState(context);
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: SingleChildScrollView(
              key: const ValueKey('suppliers-content'),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _SupplierStat(
                        title: 'عدد الموردين',
                        value: '${_catalog.supplierCount}',
                        icon: Icons.business_outlined,
                        color: const Color(0xFF6C63FF),
                      ),
                      _SupplierStat(
                        title: 'إجمالي فواتير الشراء',
                        value: '${_catalog.invoiceCount}',
                        icon: Icons.receipt_long_outlined,
                        color: const Color(0xFF2196F3),
                      ),
                      _SupplierStat(
                        title: 'إجمالي المستحقات',
                        value: '${_money(totalBalance)} USD',
                        subtitle: '${_money(totalBalance * rate)} ل.س',
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFFFFA726),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildSearch(context),
                  const SizedBox(height: 16),
                  if (_catalog.errorMessage != null) _inlineError(context),
                  if (suppliers.isEmpty)
                    _emptyState(context)
                  else
                    _buildSupplierList(context, suppliers, rate),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.of(context).size.width < 620;
    final actionWidgets = Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        IconButton.filledTonal(
          tooltip: 'تحديث البيانات',
          onPressed: _catalog.isLoading
              ? null
              : () => _catalog.load(force: true),
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFFD8D3FF),
            backgroundColor: Colors.white.withValues(alpha: .09),
          ),
          icon: const Icon(Icons.refresh_rounded),
        ),
        FilledButton.icon(
          onPressed: _openSupplierForm,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
          label: const Text('إضافة مورد'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF766BFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF211D3B), Color(0xFF151722), Color(0xFF11131B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF9187FF).withValues(alpha: .28),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF756BFF).withValues(alpha: .10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -12,
            top: -28,
            child: IgnorePointer(
              child: Container(
                width: 145,
                height: 145,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF786DFF).withValues(alpha: .09),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF958BFF), Color(0xFF6255E8)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF786DFF).withValues(alpha: .28),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEXOR PROCUREMENT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFB8B1FF),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'إدارة الموردين',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .10),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFB8B1FF),
                            size: 15,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'SUPPLIER CENTER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                'كل بيانات الموردين وأرصدتهم وكشوف حساباتهم ضمن مساحة عمل واحدة.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: .68),
                ),
              ),
              const SizedBox(height: 15),
              actionWidgets,
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadErrorState(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: .22),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: Color(0xFFEF7777),
            ),
            const SizedBox(height: 12),
            const Text(
              'تعذر تحميل الموردين',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              _catalog.errorMessage ?? 'تحقق من اتصال الخادم.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _catalog.load(force: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _inlineError(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEF4444).withValues(alpha: .07),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      _catalog.errorMessage!,
      style: const TextStyle(color: Color(0xFFDC5757)),
    ),
  );

  Widget _buildSearch(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width < 420 ? double.infinity : 360,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'ابحث باسم المورد أو الهاتف',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.dividerColor.withValues(alpha: .4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierList(
    BuildContext context,
    List<SupplierModel> suppliers,
    double rate,
  ) {
    final isNarrow = MediaQuery.of(context).size.width < 850;
    if (isNarrow) {
      return Column(
        children: suppliers
            .map(
              (supplier) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SupplierCard(
                  supplier: supplier,
                  balanceUsd: _catalog.supplierBalanceUsd(supplier.id),
                  balanceSyp: _catalog.supplierBalanceSyp(supplier.id),
                  onAccount: () => _showSupplierAccount(supplier),
                  onPayment: () => _openPaymentForm(supplier),
                  onEdit: () => _openSupplierForm(supplier: supplier),
                  onDelete: () => _deleteSupplier(supplier),
                ),
              ),
            )
            .toList(),
      );
    }

    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: .35)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 58,
          dataRowMinHeight: 68,
          dataRowMaxHeight: 76,
          columnSpacing: 30,
          horizontalMargin: 22,
          columns: const [
            DataColumn(label: Text('رمز المورد')),
            DataColumn(label: Text('اسم المورد')),
            DataColumn(label: Text('رقم الهاتف')),
            DataColumn(label: Text('العنوان')),
            DataColumn(label: Text('الرصيد بالدولار')),
            DataColumn(label: Text('الرصيد بالسوري')),
            DataColumn(label: Text('الإجراءات')),
          ],
          rows: suppliers.map((supplier) {
            final balanceUsd = _catalog.supplierBalanceUsd(supplier.id);
            final balanceSyp = balanceUsd * rate;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    supplier.id,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(
                  Text(
                    supplier.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(Text(supplier.phone.isEmpty ? '—' : supplier.phone)),
                DataCell(
                  Text(supplier.address.isEmpty ? '—' : supplier.address),
                ),
                DataCell(
                  Text(
                    '${_money(balanceUsd)} USD',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: balanceUsd > 0
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
                DataCell(Text('${_money(balanceSyp)} ل.س')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'كشف الحساب',
                        onPressed: () => _showSupplierAccount(supplier),
                        icon: const Icon(Icons.account_balance_outlined),
                      ),
                      IconButton(
                        tooltip: 'تسجيل دفعة',
                        onPressed: () => _openPaymentForm(supplier),
                        icon: const Icon(Icons.payments_outlined),
                      ),
                      IconButton(
                        tooltip: 'تعديل',
                        onPressed: () => _openSupplierForm(supplier: supplier),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'أرشفة المورد',
                        onPressed: () => _deleteSupplier(supplier),
                        icon: const Icon(
                          Icons.archive_outlined,
                          color: Color(0xFFF57C00),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.business_outlined,
            size: 52,
            color: theme.colorScheme.onSurface.withValues(alpha: .3),
          ),
          const SizedBox(height: 14),
          const Text(
            'لا يوجد موردون',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'أضف بيانات أول مورد للبدء بتسجيل المشتريات.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: .55),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupplierForm({SupplierModel? supplier}) async {
    final result = await showDialog<_SupplierDraft>(
      context: context,
      builder: (_) => _SupplierFormDialog(supplier: supplier),
    );
    if (result == null || !mounted) return;
    try {
      if (supplier == null) {
        await _catalog.addSupplier(
          name: result.name,
          phone: result.phone,
          email: result.email,
          address: result.address,
          note: result.note,
        );
      } else {
        await _catalog.updateSupplier(
          supplier.copyWith(
            name: result.name,
            phone: result.phone,
            email: result.email,
            address: result.address,
            note: result.note,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            supplier == null ? 'تمت إضافة المورد' : 'تم تعديل بيانات المورد',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openPaymentForm(SupplierModel supplier) async {
    final draft = await showDialog<_PaymentDraft>(
      context: context,
      builder: (_) => _SupplierPaymentDialog(supplierId: supplier.id),
    );
    if (draft == null || !mounted) return;
    try {
      await _catalog.recordPayment(
        supplierId: supplier.id,
        purchaseId: draft.purchaseId,
        amount: draft.amount,
        currencyCode: draft.currencyCode,
        exchangeRateSypPerUsd: ProductCatalog.instance.exchangeRateSypPerUsd,
        note: draft.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الدفعة وتحديث رصيد المورد'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showSupplierAccount(SupplierModel supplier) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final purchases = _catalog.purchasesForSupplier(supplier.id);
        final payments = _catalog.paymentsForSupplier(supplier.id);
        final balanceUsd = _catalog.supplierBalanceUsd(supplier.id);
        final rate = ProductCatalog.instance.exchangeRateSypPerUsd;
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text('كشف حساب ${supplier.name}'),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccountSummary(
                      balanceUsd: balanceUsd,
                      balanceSyp: balanceUsd * rate,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'فواتير الشراء',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (purchases.isEmpty)
                      const Text('لا توجد فواتير مسجلة لهذا المورد.')
                    else
                      ...purchases.map(
                        (purchase) => _LedgerRow(
                          icon: Icons.receipt_long_outlined,
                          title: 'فاتورة ${purchase.invoiceNumber}',
                          subtitle: DateFormat(
                            'yyyy/MM/dd',
                          ).format(purchase.createdAt),
                          amount: '${_money(purchase.totalUsd)} USD',
                          color: const Color(0xFF6C63FF),
                        ),
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      'الدفعات',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (payments.isEmpty)
                      const Text('لا توجد دفعات مسجلة.')
                    else
                      ...payments.map(
                        (payment) => _LedgerRow(
                          icon: Icons.payments_outlined,
                          title: payment.purchaseId == null
                              ? 'دفعة على حساب المورد'
                              : 'دفعة لفاتورة ${payment.purchaseInvoiceNumber ?? ''}',
                          subtitle:
                              '${DateFormat('yyyy/MM/dd').format(payment.createdAt)} • ${payment.note}',
                          amount:
                              '${_money(payment.amount)} ${payment.currencyCode}',
                          color: const Color(0xFF10B981),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openPaymentForm(supplier);
                },
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('تسجيل دفعة'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteSupplier(SupplierModel supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('تأكيد أرشفة المورد'),
          content: Text(
            'هل تريد أرشفة المورد ${supplier.name}؟ سيبقى سجل فواتيره ودفعاته محفوظاً، ولن يظهر ضمن الموردين النشطين.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('أرشفة'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _catalog.removeSupplier(supplier.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت أرشفة المورد')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _SupplierDraft {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String note;
  const _SupplierDraft({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.note,
  });
}

class _SupplierFormDialog extends StatefulWidget {
  final SupplierModel? supplier;
  const _SupplierFormDialog({this.supplier});

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    _name = TextEditingController(text: supplier?.name ?? '');
    _phone = TextEditingController(text: supplier?.phone ?? '');
    _email = TextEditingController(text: supplier?.email ?? '');
    _address = TextEditingController(text: supplier?.address ?? '');
    _note = TextEditingController(text: supplier?.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: ui.TextDirection.rtl,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        widget.supplier == null ? 'إضافة مورد جديد' : 'تعديل بيانات المورد',
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  _name,
                  'اسم المورد',
                  Icons.business_outlined,
                  requiredField: true,
                ),
                const SizedBox(height: 10),
                _field(
                  _phone,
                  'رقم الهاتف',
                  Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _field(
                  _email,
                  'البريد الإلكتروني',
                  Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                _field(_address, 'العنوان', Icons.location_on_outlined),
                const SizedBox(height: 10),
                _field(_note, 'ملاحظات', Icons.notes_outlined, maxLines: 2),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _save, child: const Text('حفظ')),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      if (!requiredField) return null;
      if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
      if (value.trim().length < 2) return 'أدخل اسماً من حرفين على الأقل';
      return null;
    },
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SupplierDraft(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }
}

class _PaymentDraft {
  final double amount;
  final String currencyCode;
  final String note;
  final String? purchaseId;
  const _PaymentDraft({
    required this.amount,
    required this.currencyCode,
    required this.note,
    this.purchaseId,
  });
}

class _SupplierPaymentDialog extends StatefulWidget {
  final String supplierId;
  const _SupplierPaymentDialog({required this.supplierId});
  @override
  State<_SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends State<_SupplierPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _currency = 'USD';
  String? _purchaseId;

  List<PurchaseModel> get _openPurchases => PurchaseCatalog.instance
      .purchasesForSupplier(widget.supplierId)
      .where(
        (purchase) =>
            PurchaseCatalog.instance.outstandingForPurchaseUsd(purchase) >
            0.000001,
      )
      .toList();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rate = ProductCatalog.instance.exchangeRateSypPerUsd;
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('تسجيل دفعة للمورد'),
        content: SizedBox(
          width: 430,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'مبلغ الدفعة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    return amount == null || !amount.isFinite || amount <= 0
                        ? 'أدخل مبلغاً صحيحاً أكبر من صفر'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(
                    labelText: 'العملة',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'USD',
                      child: Text('دولار أمريكي USD'),
                    ),
                    DropdownMenuItem(
                      value: 'SYP',
                      child: Text('ليرة سورية SYP'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _currency = value ?? 'USD'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'سعر الصرف المعتمد: 1 USD = ${_money(rate)} ل.س',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _purchaseId,
                  decoration: const InputDecoration(
                    labelText: 'ربط الدفعة بفاتورة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('دفعة عامة على حساب المورد'),
                    ),
                    ..._openPurchases.map(
                      (purchase) => DropdownMenuItem<String?>(
                        value: purchase.id,
                        child: Text(
                          '${purchase.invoiceNumber} • متبقي ${_money(PurchaseCatalog.instance.outstandingForPurchaseUsd(purchase))} USD',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _purchaseId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'بيان الدفعة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(onPressed: _save, child: const Text('تسجيل الدفعة')),
        ],
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _PaymentDraft(
        amount: double.parse(_amount.text.trim()),
        currencyCode: _currency,
        note: _note.text.trim(),
        purchaseId: _purchaseId,
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final double balanceUsd;
  final double balanceSyp;
  final VoidCallback onAccount;
  final VoidCallback onPayment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.balanceUsd,
    required this.balanceSyp,
    required this.onAccount,
    required this.onPayment,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(
        color: Theme.of(context).dividerColor.withValues(alpha: .35),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  supplier.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                supplier.id,
                style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SupplierInfoLine(
            label: 'الهاتف',
            value: supplier.phone.isEmpty ? '—' : supplier.phone,
          ),
          _SupplierInfoLine(
            label: 'العنوان',
            value: supplier.address.isEmpty ? '—' : supplier.address,
          ),
          _SupplierInfoLine(
            label: 'الرصيد',
            value: '${_money(balanceUsd)} USD  •  ${_money(balanceSyp)} ل.س',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onAccount,
                icon: const Icon(Icons.account_balance_outlined, size: 18),
                label: const Text('كشف الحساب'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'تسجيل دفعة',
                onPressed: onPayment,
                icon: const Icon(Icons.payments_outlined),
              ),
              IconButton(
                tooltip: 'تعديل',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'أرشفة المورد',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.archive_outlined,
                  color: Color(0xFFF57C00),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SupplierInfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _SupplierInfoLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .55),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _SupplierStat extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  const _SupplierStat({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 225,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .6),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: .5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  final double balanceUsd;
  final double balanceSyp;
  const _AccountSummary({required this.balanceUsd, required this.balanceSyp});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF6C63FF).withValues(alpha: .08),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الرصيد الحالي على المورد',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                '${_money(balanceUsd)} USD',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6C63FF),
                ),
              ),
              Text(
                '${_money(balanceSyp)} ل.س',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .6),
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.account_balance_wallet_outlined,
          size: 30,
          color: Color(0xFF6C63FF),
        ),
      ],
    ),
  );
}

class _LedgerRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final Color color;
  const _LedgerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(fontWeight: FontWeight.w800, color: color),
        ),
      ],
    ),
  );
}

String _money(num value) => NumberFormat('#,##0.##').format(value);
