import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../products/product_catalog.dart';
import '../products/product_model.dart';
import 'purchase_catalog.dart';
import 'purchase_models.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  final _searchController = TextEditingController();
  final _horizontalController = ScrollController();
  final _catalog = PurchaseCatalog.instance;

  @override
  void initState() {
    super.initState();
    _catalog.load(force: true);
    ProductCatalog.instance.load();
  }

  List<PurchaseModel> get _filteredPurchases {
    final query = _searchController.text.trim().toLowerCase();
    return _catalog.purchases.where((purchase) {
      return query.isEmpty ||
          purchase.invoiceNumber.toLowerCase().contains(query) ||
          purchase.supplierNameSnapshot.toLowerCase().contains(query) ||
          purchase.id.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AnimatedBuilder(
        animation: Listenable.merge([_catalog, ProductCatalog.instance]),
        builder: (context, _) {
          final purchases = _filteredPurchases;
          final rate = ProductCatalog.instance.exchangeRateSypPerUsd;
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
              key: const ValueKey('purchases-content'),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 22),
                  _buildStats(rate),
                  const SizedBox(height: 22),
                  _buildToolbar(context),
                  const SizedBox(height: 16),
                  if (_catalog.errorMessage != null) _inlineError(context),
                  if (purchases.isEmpty)
                    _emptyState(context)
                  else if (MediaQuery.of(context).size.width < 850)
                    _buildCards(context, purchases)
                  else
                    _buildTable(context, purchases),
                  const SizedBox(height: 16),
                  Text(
                    'عدد فواتير الشراء: ${_catalog.purchases.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .55),
                    ),
                  ),
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
    final canCreate =
        _catalog.suppliers.any((item) => item.isActive) &&
        ProductCatalog.instance.products.any((item) => item.isActive);
    final actions = Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        IconButton.filledTonal(
          tooltip: 'تحديث البيانات',
          onPressed: _catalog.isLoading
              ? null
              : () async {
                  await _catalog.load(force: true);
                  await ProductCatalog.instance.load(force: true);
                },
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFFD8D3FF),
            backgroundColor: Colors.white.withValues(alpha: .09),
          ),
          icon: const Icon(Icons.refresh_rounded),
        ),
        FilledButton.icon(
          onPressed: canCreate ? _openPurchaseForm : _showSetupHint,
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 19),
          label: const Text('فاتورة شراء جديدة'),
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
                      Icons.shopping_bag_rounded,
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
                          'إدارة المشتريات',
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
                            'PURCHASE CONTROL',
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
                'سجّل فواتير الشراء واستلام البضاعة والدفعات مع تحديث المخزون تلقائياً.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: .68),
                ),
              ),
              const SizedBox(height: 15),
              actions,
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
              'تعذر تحميل المشتريات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              _catalog.errorMessage ?? 'تحقق من اتصال الخادم.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await _catalog.load(force: true);
                await ProductCatalog.instance.load(force: true);
              },
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

  Widget _buildCards(BuildContext context, List<PurchaseModel> purchases) {
    return Column(
      children: purchases.map((purchase) {
        final paid = _catalog.paidForPurchaseUsd(purchase.id);
        final outstanding = _catalog.outstandingForPurchaseUsd(purchase);
        final isPaid = outstanding <= 0.000001;
        final partial = paid > 0 && !isPaid;
        final statusColor = isPaid
            ? const Color(0xFF10B981)
            : partial
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: .32),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF17152B).withValues(alpha: .035),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      purchase.invoiceNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPaid
                          ? 'مدفوعة'
                          : partial
                          ? 'مدفوعة جزئياً'
                          : 'غير مدفوعة',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                purchase.supplierNameSnapshot,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .62),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PurchaseMiniValue(
                    label: 'الكمية',
                    value: '${purchase.totalQuantity} قطعة',
                  ),
                  _PurchaseMiniValue(
                    label: 'الإجمالي',
                    value: '${_money(purchase.totalUsd)} USD',
                  ),
                  _PurchaseMiniValue(
                    label: 'بالسوري',
                    value: '${_money(purchase.totalSyp)} ل.س',
                  ),
                  _PurchaseMiniValue(
                    label: 'المتبقي',
                    value: '${_money(outstanding)} USD',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('yyyy/MM/dd').format(purchase.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showPurchaseDetails(purchase),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('التفاصيل'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStats(double rate) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _PurchaseStat(
          title: 'فواتير الشراء',
          value: '${_catalog.invoiceCount}',
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFF6C63FF),
        ),
        _PurchaseStat(
          title: 'الموردون',
          value: '${_catalog.supplierCount}',
          icon: Icons.business_outlined,
          color: const Color(0xFF2196F3),
        ),
        _PurchaseStat(
          title: 'إجمالي المشتريات',
          value: '${_money(_catalog.totalPurchasesUsd)} USD',
          subtitle: '${_money(_catalog.totalPurchasesUsd * rate)} ل.س',
          icon: Icons.shopping_cart_checkout_outlined,
          color: const Color(0xFF26A69A),
        ),
        _PurchaseStat(
          title: 'مستحقات الموردين',
          value: '${_money(_catalog.totalSupplierBalancesUsd)} USD',
          subtitle: '${_money(_catalog.totalSupplierBalancesUsd * rate)} ل.س',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFFFFA726),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width < 420 ? double.infinity : 360,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'ابحث برقم الفاتورة أو اسم المورد',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
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

  Widget _buildTable(BuildContext context, List<PurchaseModel> purchases) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 8,
            radius: const Radius.circular(8),
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 58,
                dataRowMinHeight: 66,
                dataRowMaxHeight: 76,
                columnSpacing: 30,
                horizontalMargin: 22,
                columns: const [
                  DataColumn(label: Text('رقم الفاتورة')),
                  DataColumn(label: Text('المورد')),
                  DataColumn(label: Text('عدد القطع')),
                  DataColumn(label: Text('الإجمالي بالدولار')),
                  DataColumn(label: Text('الإجمالي بالسوري')),
                  DataColumn(label: Text('المتبقي')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('التفاصيل')),
                ],
                rows: purchases.map((purchase) {
                  final paid = _catalog.paidForPurchaseUsd(purchase.id);
                  final outstanding = _catalog.outstandingForPurchaseUsd(
                    purchase,
                  );
                  final isPaid = outstanding <= 0.000001;
                  final isPartial = paid > 0 && !isPaid;
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          purchase.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _showPurchaseDetails(purchase),
                      ),
                      DataCell(Text(purchase.supplierNameSnapshot)),
                      DataCell(Text('${purchase.totalQuantity}')),
                      DataCell(Text('${_money(purchase.totalUsd)} USD')),
                      DataCell(Text('${_money(purchase.totalSyp)} ل.س')),
                      DataCell(
                        Text(
                          '${_money(outstanding)} USD',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: outstanding > 0
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                      DataCell(
                        _PaymentStatusBadge(
                          label: isPaid
                              ? 'مدفوعة'
                              : isPartial
                              ? 'مدفوعة جزئياً'
                              : 'غير مدفوعة',
                          color: isPaid
                              ? const Color(0xFF10B981)
                              : isPartial
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                      DataCell(
                        Text(
                          DateFormat('yyyy/MM/dd').format(purchase.createdAt),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: 'تفاصيل الفاتورة',
                          onPressed: () => _showPurchaseDetails(purchase),
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            alignment: Alignment.centerRight,
            child: Text(
              'اسحب شريط التمرير أسفل الجدول لعرض بقية الأعمدة',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: .5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 58, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 52,
            color: theme.colorScheme.onSurface.withValues(alpha: .3),
          ),
          const SizedBox(height: 14),
          const Text(
            'لا توجد فواتير شراء حتى الآن',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'أنشئ أول فاتورة شراء لتسجيل استلام البضاعة وتحديث المخزون.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: .55),
            ),
          ),
        ],
      ),
    );
  }

  void _showSetupHint() {
    final hasSuppliers = _catalog.suppliers.any((item) => item.isActive);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasSuppliers
              ? 'أضف منتجات إلى الكتالوج أولاً.'
              : 'أضف مورداً ومنتجاً قبل إنشاء فاتورة شراء.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPurchaseForm() async {
    final result = await showDialog<_PurchaseDraftResult>(
      context: context,
      builder: (_) => const _PurchaseFormDialog(),
    );
    if (result == null || !mounted) return;

    try {
      final purchase = await _catalog.createPurchase(
        supplierId: result.supplierId,
        invoiceNumber: result.invoiceNumber,
        items: result.items,
        exchangeRateSypPerUsd: result.exchangeRate,
        note: result.note,
        initialPaymentAmount: result.initialPaymentAmount,
        initialPaymentCurrency: result.initialPaymentCurrency,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تسجيل الفاتورة ${purchase.invoiceNumber} وتحديث المخزون.',
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

  Future<void> _showPurchaseDetails(PurchaseModel purchase) async {
    final paid = _catalog.paidForPurchaseUsd(purchase.id);
    final outstanding = _catalog.outstandingForPurchaseUsd(purchase);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text('فاتورة ${purchase.invoiceNumber}'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoLine(
                    label: 'المورد',
                    value: purchase.supplierNameSnapshot,
                  ),
                  _InfoLine(
                    label: 'تاريخ الفاتورة',
                    value: DateFormat(
                      'yyyy/MM/dd HH:mm',
                    ).format(purchase.createdAt),
                  ),
                  _InfoLine(
                    label: 'سعر الصرف وقت الفاتورة',
                    value:
                        '1 USD = ${_money(purchase.exchangeRateSypPerUsd)} ل.س',
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'بنود الفاتورة',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ...purchase.items.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'الكمية: ${item.quantity}  •  باركود: ${item.barcode}',
                          ),
                          Text(
                            'سعر القطعة: ${_money(item.unitPriceUsd)} USD  /  ${_money(item.unitPriceSyp)} ل.س',
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'الإجمالي: ${_money(item.totalUsd)} USD',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 26),
                  _InfoLine(
                    label: 'الإجمالي',
                    value:
                        '${_money(purchase.totalUsd)} USD  •  ${_money(purchase.totalSyp)} ل.س',
                  ),
                  _InfoLine(label: 'المدفوع', value: '${_money(paid)} USD'),
                  _InfoLine(
                    label: 'المتبقي',
                    value: '${_money(outstanding)} USD',
                  ),
                  if (purchase.note.isNotEmpty)
                    _InfoLine(label: 'ملاحظات', value: purchase.note),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseDraftResult {
  final String supplierId;
  final String invoiceNumber;
  final List<PurchaseItemModel> items;
  final double exchangeRate;
  final String note;
  final double initialPaymentAmount;
  final String initialPaymentCurrency;

  const _PurchaseDraftResult({
    required this.supplierId,
    required this.invoiceNumber,
    required this.items,
    required this.exchangeRate,
    required this.note,
    required this.initialPaymentAmount,
    required this.initialPaymentCurrency,
  });
}

class _PurchaseLineDraft {
  String? productId;
  final quantityController = TextEditingController(text: '1');
  final usdController = TextEditingController();
  final sypController = TextEditingController();

  void dispose() {
    quantityController.dispose();
    usdController.dispose();
    sypController.dispose();
  }
}

class _PurchaseFormDialog extends StatefulWidget {
  const _PurchaseFormDialog();

  @override
  State<_PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<_PurchaseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceController = TextEditingController();
  final _noteController = TextEditingController();
  final _initialPaymentController = TextEditingController(text: '0');
  final _catalog = PurchaseCatalog.instance;
  final _productCatalog = ProductCatalog.instance;
  final List<_PurchaseLineDraft> _lines = [];
  String? _supplierId;
  String _paymentCurrency = 'USD';
  bool _syncing = false;

  double get _rate => _productCatalog.exchangeRateSypPerUsd;

  @override
  void initState() {
    super.initState();
    final activeSuppliers = _catalog.suppliers
        .where((item) => item.isActive)
        .toList();
    _supplierId = activeSuppliers.isEmpty ? null : activeSuppliers.first.id;
    _addLine();
    _invoiceController.text =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _noteController.dispose();
    _initialPaymentController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    final line = _PurchaseLineDraft();
    final activeProducts = _productCatalog.products
        .where((item) => item.isActive)
        .toList();
    if (activeProducts.isNotEmpty) {
      final product = activeProducts.first;
      line.productId = product.id;
      line.usdController.text = _compactNumber(product.purchasePriceUsd);
      line.sypController.text = _compactNumber(
        (product.purchasePriceUsd * _rate).round(),
      );
    }
    _lines.add(line);
  }

  void _selectProduct(_PurchaseLineDraft line, String? id) {
    final product = id == null ? null : _productCatalog.findById(id);
    setState(() {
      line.productId = id;
      if (product != null) {
        line.usdController.text = _compactNumber(product.purchasePriceUsd);
        line.sypController.text = _compactNumber(
          (product.purchasePriceUsd * _rate).round(),
        );
      }
    });
  }

  Future<void> _openQuickProductDialog() async {
    final product = await showDialog<ProductModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuickProductDialog(exchangeRate: _rate),
    );
    if (!mounted || product == null) return;

    final line = _PurchaseLineDraft()
      ..productId = product.id
      ..usdController.text = _compactNumber(product.purchasePriceUsd)
      ..sypController.text = _compactNumber(product.purchasePriceSyp);

    final emptyLineIndex = _lines.indexWhere((item) => item.productId == null);
    setState(() {
      if (emptyLineIndex >= 0) {
        _lines[emptyLineIndex].dispose();
        _lines[emptyLineIndex] = line;
      } else {
        _lines.add(line);
      }
    });
  }

  void _syncPrice(
    _PurchaseLineDraft line, {
    required bool fromUsd,
    required String value,
  }) {
    if (_syncing) return;
    final parsed = double.tryParse(value.replaceAll(',', '').trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) return;
    _syncing = true;
    if (fromUsd) {
      line.sypController.text = (parsed * _rate).toStringAsFixed(0);
    } else {
      line.usdController.text = _compactNumber(parsed / _rate);
    }
    _syncing = false;
  }

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;

  double get _draftTotalUsd => _lines.fold(0, (sum, line) {
    final quantity = int.tryParse(line.quantityController.text) ?? 0;
    return sum + quantity * _number(line.usdController);
  });

  @override
  Widget build(BuildContext context) {
    final products = _productCatalog.products
        .where((item) => item.isActive)
        .toList();
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 820),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFF211D3B), Color(0xFF151722)],
                      ),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFFB8B1FF),
                          size: 26,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NEXOR PROCUREMENT',
                                style: TextStyle(
                                  color: Color(0xFFB8B1FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'إنشاء فاتورة شراء',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _supplierId,
                          decoration: const InputDecoration(
                            labelText: 'المورد',
                            border: OutlineInputBorder(),
                          ),
                          items: _catalog.suppliers
                              .where((item) => item.isActive)
                              .map(
                                (supplier) => DropdownMenuItem(
                                  value: supplier.id,
                                  child: Text(supplier.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _supplierId = value),
                          validator: (value) =>
                              value == null ? 'اختر المورد' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _invoiceController,
                          decoration: const InputDecoration(
                            labelText: 'رقم فاتورة المورد',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'رقم الفاتورة مطلوب'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'أصناف الفاتورة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openQuickProductDialog,
                        icon: const Icon(Icons.add_box_rounded, size: 18),
                        label: const Text('صنف جديد'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8B84FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'سعر الصرف: ${_money(_rate)} ل.س / USD',
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'لا توجد أصناف بعد. اضغط «صنف جديد» لإضافة أول صنف مباشرةً إلى الفاتورة.',
                      ),
                    )
                  else
                    ..._lines.asMap().entries.map(
                      (entry) => _buildLine(entry.key, entry.value, products),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: products.isEmpty
                          ? null
                          : () => setState(_addLine),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة صنف آخر'),
                    ),
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'إجمالي الفاتورة التقريبي',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${_money(_draftTotalUsd)} USD',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'الدفعة عند تسجيل الفاتورة (اختياري)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _initialPaymentController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'المبلغ المدفوع',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final amount = double.tryParse(value ?? '0') ?? 0;
                            if (!amount.isFinite || amount < 0)
                              return 'المبلغ غير صحيح';
                            final usd = _paymentCurrency == 'USD'
                                ? amount
                                : amount / _rate;
                            if (usd > _draftTotalUsd + 0.000001)
                              return 'الدفعة أكبر من الإجمالي';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _paymentCurrency,
                          decoration: const InputDecoration(
                            labelText: 'عملة الدفع',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'USD',
                              child: Text('دولار USD'),
                            ),
                            DropdownMenuItem(
                              value: 'SYP',
                              child: Text('ليرة سورية'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _paymentCurrency = value ?? 'USD'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الفاتورة (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: products.isEmpty ? null : _save,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('حفظ الفاتورة واستلام البضاعة'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLine(
    int index,
    _PurchaseLineDraft line,
    List<ProductModel> products,
  ) {
    ProductModel? selected;
    for (final product in products) {
      if (product.id == line.productId) {
        selected = product;
        break;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: selected?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المنتج',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: products
                      .map(
                        (product) => DropdownMenuItem(
                          value: product.id,
                          child: Text(
                            '${product.name} • ${product.barcode}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => _selectProduct(line, value),
                  validator: (value) => value == null ? 'اختر منتجاً' : null,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 105,
                child: TextFormField(
                  controller: line.quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final quantity = int.tryParse(value ?? '');
                    return quantity == null || quantity <= 0
                        ? 'كمية غير صحيحة'
                        : null;
                  },
                ),
              ),
              IconButton(
                tooltip: 'حذف الصنف',
                onPressed: _lines.length == 1
                    ? null
                    : () => setState(() {
                        _lines.removeAt(index).dispose();
                      }),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.usdController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'سعر القطعة بالدولار',
                    suffixText: 'USD',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    _syncPrice(line, fromUsd: true, value: value);
                    setState(() {});
                  },
                  validator: (value) => (double.tryParse(value ?? '') ?? -1) < 0
                      ? 'سعر غير صحيح'
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: line.sypController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'سعر القطعة بالسوري',
                    suffixText: 'ل.س',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    _syncPrice(line, fromUsd: false, value: value);
                    setState(() {});
                  },
                  validator: (value) => (double.tryParse(value ?? '') ?? -1) < 0
                      ? 'سعر غير صحيح'
                      : null,
                ),
              ),
            ],
          ),
          if (selected != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'المتاح حالياً: ${selected.stockQuantity} قطعة',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .55),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final items = <PurchaseItemModel>[];
    for (final line in _lines) {
      final productId = line.productId;
      final product = productId == null
          ? null
          : _productCatalog.findById(productId);
      if (product == null) {
        return;
      }
      items.add(
        PurchaseItemModel(
          productId: product.id,
          productName: product.name,
          barcode: product.barcode,
          quantity: int.parse(line.quantityController.text.trim()),
          unitPriceUsd: _number(line.usdController),
          unitPriceSyp: _number(line.sypController),
        ),
      );
    }
    Navigator.pop(
      context,
      _PurchaseDraftResult(
        supplierId: _supplierId!,
        invoiceNumber: _invoiceController.text.trim(),
        items: items,
        exchangeRate: _rate,
        note: _noteController.text.trim(),
        initialPaymentAmount: _number(_initialPaymentController),
        initialPaymentCurrency: _paymentCurrency,
      ),
    );
  }
}

class _QuickProductDialog extends StatefulWidget {
  final double exchangeRate;

  const _QuickProductDialog({required this.exchangeRate});

  @override
  State<_QuickProductDialog> createState() => _QuickProductDialogState();
}

class _QuickProductDialogState extends State<_QuickProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _purchaseUsdController = TextEditingController(text: '0');
  final _purchaseSypController = TextEditingController(text: '0');
  final _sellingUsdController = TextEditingController(text: '0');
  final _sellingSypController = TextEditingController(text: '0');
  final _minimumStockController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();

  bool _syncingPrices = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _purchaseUsdController.dispose();
    _purchaseSypController.dispose();
    _sellingUsdController.dispose();
    _sellingSypController.dispose();
    _minimumStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double _number(TextEditingController controller) {
    return double.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;
  }

  String? _validateMoney(String? value) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '').trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return 'أدخل قيمة صحيحة';
    }
    return null;
  }

  void _syncPrice({
    required bool purchase,
    required bool fromUsd,
    required String value,
  }) {
    if (_syncingPrices) return;
    final parsed = double.tryParse(value.replaceAll(',', '').trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) return;

    final usdController = purchase
        ? _purchaseUsdController
        : _sellingUsdController;
    final sypController = purchase
        ? _purchaseSypController
        : _sellingSypController;
    _syncingPrices = true;
    if (fromUsd) {
      sypController.text = _compactNumber(
        (parsed * widget.exchangeRate).round(),
      );
    } else {
      usdController.text = _compactNumber(parsed / widget.exchangeRate);
    }
    _syncingPrices = false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final purchaseUsd = _number(_purchaseUsdController);
    final sellingUsd = _number(_sellingUsdController);
    final product = ProductModel(
      id: '',
      name: _nameController.text.trim(),
      barcode: _barcodeController.text.trim(),
      category: _categoryController.text.trim(),
      purchasePriceUsd: purchaseUsd,
      purchasePriceSyp: _number(_purchaseSypController),
      sellingPriceUsd: sellingUsd,
      sellingPriceSyp: _number(_sellingSypController),
      exchangeRateSypPerUsd: widget.exchangeRate,
      // The invoice will add the received quantity on the server exactly once.
      stockQuantity: 0,
      minimumStock: int.tryParse(_minimumStockController.text.trim()) ?? 0,
      description: _descriptionController.text.trim(),
      isActive: true,
      createdAt: DateTime.now(),
    );

    try {
      final saved = await ProductCatalog.instance.add(product);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.toString();
      });
    }
  }

  Widget _priceField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required bool purchase,
    required bool fromUsd,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (value) =>
          _syncPrice(purchase: purchase, fromUsd: fromUsd, value: value),
      validator: _validateMoney,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFF211D3B), Color(0xFF151722)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.add_box_rounded,
                          color: Color(0xFFB8B1FF),
                          size: 25,
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NEXOR • QUICK PRODUCT',
                                style: TextStyle(
                                  color: Color(0xFFB8B1FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .7,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'إضافة صنف جديد للفاتورة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'اسم الصنف *',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value ?? '').trim().length < 2
                        ? 'اسم الصنف يجب أن يتكون من حرفين على الأقل'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'التصنيف (اختياري)',
                            prefixIcon: Icon(Icons.category_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الباركود (اختياري)',
                            prefixIcon: Icon(Icons.qr_code_2_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final barcode = (value ?? '').trim();
                            if (barcode.isEmpty) return null;
                            return RegExp(r'^[0-9]{8,14}$').hasMatch(barcode)
                                ? null
                                : 'الباركود من 8 إلى 14 رقماً';
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'تكلفة شراء القطعة',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _priceField(
                          controller: _purchaseUsdController,
                          label: 'التكلفة بالدولار',
                          suffix: 'USD',
                          purchase: true,
                          fromUsd: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _priceField(
                          controller: _purchaseSypController,
                          label: 'التكلفة بالسوري',
                          suffix: 'ل.س',
                          purchase: true,
                          fromUsd: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'سعر البيع',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _priceField(
                          controller: _sellingUsdController,
                          label: 'البيع بالدولار',
                          suffix: 'USD',
                          purchase: false,
                          fromUsd: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _priceField(
                          controller: _sellingSypController,
                          label: 'البيع بالسوري',
                          suffix: 'ل.س',
                          purchase: false,
                          fromUsd: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minimumStockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'حد التنبيه للمخزون',
                            prefixIcon: Icon(
                              Icons.notifications_active_outlined,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final parsed = int.tryParse((value ?? '').trim());
                            return parsed == null || parsed < 0
                                ? 'أدخل كمية صحيحة'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'سعر الصرف: ${_money(widget.exchangeRate)} ل.س / USD',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF8B84FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'وصف أو ملاحظات الصنف (اختياري)',
                      prefixIcon: Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: .25),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            _isSaving ? 'جارٍ الحفظ...' : 'حفظ الصنف واختياره',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseMiniValue extends StatelessWidget {
  final String label;
  final String value;
  const _PurchaseMiniValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: .42),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .18),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .55),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ],
    ),
  );
}

class _PurchaseStat extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _PurchaseStat({
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _PaymentStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PaymentStatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
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

String _money(num value) => NumberFormat('#,##0.##').format(value);

String _compactNumber(num value) =>
    NumberFormat('0.########', 'en_US').format(value);
