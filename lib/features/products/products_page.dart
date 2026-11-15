import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'product_catalog.dart';
import 'product_model.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  final _horizontalController = ScrollController();
  String _selectedCategory = 'الكل';
  bool _showInactive = false;

  ProductCatalog get _catalog => ProductCatalog.instance;

  @override
  void initState() {
    super.initState();
    _catalog.load(force: true);
  }

  List<ProductModel> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    return _catalog.products.where((product) {
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.id.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == 'الكل' || product.category == _selectedCategory;
      final matchesActive = _showInactive || product.isActive;
      return matchesQuery && matchesCategory && matchesActive;
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
        animation: _catalog,
        builder: (context, _) {
          final products = _filteredProducts;
          final isNarrow = MediaQuery.of(context).size.width < 850;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 22),
                _buildStats(),
                const SizedBox(height: 24),
                _buildToolbar(context),
                const SizedBox(height: 16),
                if (_catalog.isLoading && products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 70),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_catalog.errorMessage != null && products.isEmpty)
                  _loadErrorState(context)
                else if (products.isEmpty)
                  _emptyState(context)
                else if (isNarrow)
                  ...products.map(
                    (product) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProductCard(
                        product: product,
                        onEdit: () => _openProductForm(product: product),
                        onDelete: () => _deleteProduct(product),
                        onBarcode: () => _showBarcode(product),
                      ),
                    ),
                  )
                else
                  _buildTable(context, products),
                const SizedBox(height: 18),
                Text(
                  'عرض ${products.length} من أصل ${_catalog.products.length} منتج',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .55),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
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
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: .08),
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
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
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
                      Icons.inventory_2_rounded,
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
                          'إدارة المتجر',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFFB8B1FF),
                            fontWeight: FontWeight.w800,
                            letterSpacing: .7,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المنتجات والمخزون',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (MediaQuery.of(context).size.width >= 620)
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
                            'NEXOR INVENTORY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                'تحكّم بكل تفاصيل منتجاتك: الأسعار، الكميات، التصنيفات والباركود من مساحة واحدة.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: .67),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showExchangeRateDialog,
                    icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                    label: Text(
                      'سعر الصرف: ${_money(_catalog.exchangeRateSypPerUsd)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD5D0FF),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .25),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: .045),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openProductForm(),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('إضافة منتج'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF786BFF),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(
                        0xFF786BFF,
                      ).withValues(alpha: .30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 19,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _ProductStat(
          title: 'إجمالي المنتجات',
          value: '${_catalog.products.length}',
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFF6C63FF),
        ),
        _ProductStat(
          title: 'مخزون منخفض',
          value: '${_catalog.lowStockCount}',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFFFA726),
        ),
        _ProductStat(
          title: 'نفد من المخزون',
          value: '${_catalog.outOfStockCount}',
          icon: Icons.remove_shopping_cart_outlined,
          color: const Color(0xFFEF5350),
        ),
        _ProductStat(
          title: 'قيمة المخزون بالتكلفة',
          value: _money(_catalog.totalStockCost),
          secondaryValue: _usdMoney(_catalog.totalStockCostUsd),
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF26A69A),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ['الكل', ..._catalog.categories];
    if (!categories.contains(_selectedCategory)) _selectedCategory = 'الكل';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: theme.colorScheme.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'بحث وتصفية',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${_filteredProducts.length} نتيجة',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: .55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الباركود أو رقم المنتج',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: .32),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.dividerColor.withValues(alpha: .35),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: .32,
                  ),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: .35),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    borderRadius: BorderRadius.circular(14),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(
                              category == 'الكل' ? 'كل التصنيفات' : category,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value ?? 'الكل'),
                  ),
                ),
              ),
              FilterChip(
                avatar: Icon(
                  _showInactive
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_outlined,
                  size: 17,
                ),
                label: const Text('إظهار المخفية'),
                selected: _showInactive,
                onSelected: (value) => setState(() => _showInactive = value),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _searchController.clear();
                  _selectedCategory = 'الكل';
                  _showInactive = false;
                }),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('إعادة ضبط'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<ProductModel> products) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: .35)),
      ),
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            ui.PointerDeviceKind.touch,
            ui.PointerDeviceKind.mouse,
            ui.PointerDeviceKind.trackpad,
          },
        ),
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          thickness: 9,
          radius: const Radius.circular(20),
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1280),
              child: DataTable(
                headingRowHeight: 60,
                headingRowColor: WidgetStatePropertyAll(
                  theme.colorScheme.primary.withValues(alpha: .10),
                ),
                dataRowColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return theme.colorScheme.primary.withValues(alpha: .045);
                  }
                  return null;
                }),
                dividerThickness: .55,
                headingTextStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
                dataTextStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                dataRowMinHeight: 74,
                dataRowMaxHeight: 82,
                columnSpacing: 26,
                horizontalMargin: 20,
                columns: const [
                  DataColumn(label: Text('المنتج')),
                  DataColumn(label: Text('الباركود')),
                  DataColumn(label: Text('التصنيف')),
                  DataColumn(label: Text('سعر الشراء USD / SYP')),
                  DataColumn(label: Text('سعر البيع USD / SYP')),
                  DataColumn(label: Text('الكمية')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('الإجراءات')),
                ],
                rows: products.map((product) {
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                product.id,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: .5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => _showBarcode(product),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_2_rounded, size: 19),
                              const SizedBox(width: 7),
                              SelectableText(product.barcode),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text(product.category)),
                      DataCell(
                        _DualPriceCell(
                          usd: product.purchasePriceUsd,
                          syp: product.purchasePriceSyp,
                        ),
                      ),
                      DataCell(
                        _DualPriceCell(
                          usd: product.sellingPriceUsd,
                          syp: product.sellingPriceSyp,
                          emphasized: true,
                        ),
                      ),
                      DataCell(_StockCount(product: product)),
                      DataCell(_ProductStatus(product: product)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'عرض الباركود',
                              onPressed: () => _showBarcode(product),
                              icon: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 19,
                              ),
                            ),
                            IconButton(
                              tooltip: 'تعديل',
                              onPressed: () =>
                                  _openProductForm(product: product),
                              icon: const Icon(Icons.edit_outlined, size: 19),
                            ),
                            IconButton(
                              tooltip: 'حذف',
                              onPressed: () => _deleteProduct(product),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                                color: Colors.redAccent,
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
          ),
        ),
      ),
    );
  }

  Widget _loadErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 42,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 12),
          const Text(
            'تعذر تحميل المنتجات من الخادم',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'لا توجد منتجات مطابقة',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 5),
          Text('غيّر البحث أو أضف منتجاً جديداً.'),
        ],
      ),
    );
  }

  Future<void> _openProductForm({ProductModel? product}) async {
    final result = await showDialog<ProductModel>(
      context: context,
      builder: (_) => _ProductFormDialog(product: product),
    );
    if (result == null || !mounted) return;

    try {
      if (product == null) {
        await _catalog.add(result);
      } else {
        await _catalog.update(result);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product == null ? 'تمت إضافة المنتج' : 'تم تعديل المنتج',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'تعذر حفظ المنتج')),
      );
    } on ProductCatalogException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('أرشفة المنتج'),
          content: Text(
            'هل تريد أرشفة المنتج "${product.name}"؟ سيبقى محفوظاً في السجلات السابقة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('أرشفة'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _catalog.remove(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم أرشفة المنتج بنجاح')));
    } on ProductCatalogException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showExchangeRateDialog() async {
    final newRate = await showDialog<double>(
      context: context,
      builder: (_) =>
          _ExchangeRateDialog(currentRate: _catalog.exchangeRateSypPerUsd),
    );

    if (newRate == null || !mounted) return;
    try {
      await _catalog.setExchangeRate(newRate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تحديث سعر الصرف وإعادة احتساب أسعار جميع المنتجات.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ProductCatalogException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showBarcode(ProductModel product) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: Text(product.name),
          content: SizedBox(
            width: 310,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ean13Barcode(value: product.barcode),
                const SizedBox(height: 12),
                Text(
                  product.barcode,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(product.id, style: const TextStyle(color: Colors.grey)),
              ],
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

class _ProductStat extends StatelessWidget {
  final String title;
  final String value;
  final String? secondaryValue;
  final IconData icon;
  final Color color;

  const _ProductStat({
    required this.title,
    required this.value,
    this.secondaryValue,
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
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: .58),
            theme.colorScheme.surface.withValues(alpha: .96),
          ],
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .055),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: .24),
                  color.withValues(alpha: .09),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withValues(alpha: .20)),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.3,
                  ),
                ),
                if (secondaryValue != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    secondaryValue!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: .50),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockCount extends StatelessWidget {
  final ProductModel product;
  const _StockCount({required this.product});

  @override
  Widget build(BuildContext context) {
    final color = product.isOutOfStock
        ? Colors.redAccent
        : product.isLowStock
        ? Colors.orange
        : Colors.green;
    return Text(
      '${product.stockQuantity} قطعة',
      style: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
  }
}

class _ProductStatus extends StatelessWidget {
  final ProductModel product;
  const _ProductStatus({required this.product});

  @override
  Widget build(BuildContext context) {
    final label = !product.isActive
        ? 'مخفي'
        : product.isOutOfStock
        ? 'نفد المخزون'
        : product.isLowStock
        ? 'مخزون منخفض'
        : 'متوفر';
    final color = !product.isActive
        ? Colors.grey
        : product.isOutOfStock
        ? Colors.redAccent
        : product.isLowStock
        ? Colors.orange
        : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBarcode;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onBarcode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: .45),
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _ProductStatus(product: product),
              ],
            ),
            const SizedBox(height: 15),
            _mobileInfoRow(
              context,
              Icons.qr_code_2_rounded,
              'الباركود',
              product.barcode,
            ),
            _mobileInfoRow(
              context,
              Icons.category_outlined,
              'التصنيف',
              product.category,
            ),
            _mobileInfoRow(
              context,
              Icons.shopping_bag_outlined,
              'سعر الشراء',
              _dualMoney(product.purchasePriceUsd, product.purchasePriceSyp),
            ),
            _mobileInfoRow(
              context,
              Icons.sell_outlined,
              'سعر البيع',
              _dualMoney(product.sellingPriceUsd, product.sellingPriceSyp),
            ),
            _mobileInfoRow(
              context,
              Icons.inventory_outlined,
              'المخزون',
              '${product.stockQuantity} قطعة',
            ),
            const SizedBox(height: 12),
            Divider(
              color: theme.dividerColor.withValues(alpha: .35),
              height: 1,
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onBarcode,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('الباركود'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'تعديل المنتج',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'أرشفة المنتج',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.archive_outlined,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: .48),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: .55),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final ProductModel? product;
  const _ProductFormDialog({this.product});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _purchaseUsd;
  late final TextEditingController _purchaseSyp;
  late final TextEditingController _sellingUsd;
  late final TextEditingController _sellingSyp;
  late final TextEditingController _quantity;
  late final TextEditingController _minimum;
  late final TextEditingController _description;
  late bool _isActive;
  bool _syncingPrices = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    final currentRate = ProductCatalog.instance.exchangeRateSypPerUsd;

    _name = TextEditingController(text: product?.name ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _category = TextEditingController(text: product?.category ?? '');
    _purchaseUsd = TextEditingController(
      text: product == null ? '' : _numberText(product.purchasePriceUsd, 6),
    );
    _purchaseSyp = TextEditingController(
      text: product == null
          ? ''
          : _numberText(product.purchasePriceUsd * currentRate, 0),
    );
    _sellingUsd = TextEditingController(
      text: product == null ? '' : _numberText(product.sellingPriceUsd, 6),
    );
    _sellingSyp = TextEditingController(
      text: product == null
          ? ''
          : _numberText(product.sellingPriceUsd * currentRate, 0),
    );
    _quantity = TextEditingController(text: '${product?.stockQuantity ?? 0}');
    _minimum = TextEditingController(text: '${product?.minimumStock ?? 5}');
    _description = TextEditingController(text: product?.description ?? '');
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _category.dispose();
    _purchaseUsd.dispose();
    _purchaseSyp.dispose();
    _sellingUsd.dispose();
    _sellingSyp.dispose();
    _quantity.dispose();
    _minimum.dispose();
    _description.dispose();
    super.dispose();
  }

  void _syncSypFromUsd(TextEditingController usd, TextEditingController syp) {
    if (_syncingPrices) return;
    final value = double.tryParse(usd.text.trim());
    final rate = ProductCatalog.instance.exchangeRateSypPerUsd;
    if (value == null || rate <= 0) {
      if (mounted) setState(() {});
      return;
    }
    _syncingPrices = true;
    syp.text = _numberText(value * rate, 0);
    _syncingPrices = false;
    if (mounted) setState(() {});
  }

  void _syncUsdFromSyp(TextEditingController syp, TextEditingController usd) {
    if (_syncingPrices) return;
    final value = double.tryParse(syp.text.trim());
    final rate = ProductCatalog.instance.exchangeRateSypPerUsd;
    if (value == null || rate <= 0) {
      if (mounted) setState(() {});
      return;
    }
    _syncingPrices = true;
    final convertedUsd = double.parse((value / rate).toStringAsFixed(6));
    usd.text = _numberText(convertedUsd, 6);
    syp.text = _numberText((convertedUsd * rate).roundToDouble(), 0);
    _syncingPrices = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    final theme = Theme.of(context);
    final isCompact = MediaQuery.of(context).size.width < 620;
    final profitUsd =
        (double.tryParse(_sellingUsd.text.trim()) ?? 0) -
        (double.tryParse(_purchaseUsd.text.trim()) ?? 0);
    final profitSyp =
        (double.tryParse(_sellingSyp.text.trim()) ?? 0) -
        (double.tryParse(_purchaseSyp.text.trim()) ?? 0);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 880),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: .96,
                ),
                theme.colorScheme.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFF958BFF).withValues(alpha: .25),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF756BFF).withValues(alpha: .14),
                blurRadius: 35,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                          ),
                          child: Icon(
                            editing
                                ? Icons.edit_rounded
                                : Icons.add_box_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                editing
                                    ? 'تعديل بيانات المنتج'
                                    : 'إضافة منتج جديد',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'أدخل التفاصيل بدقة، وسيتم حفظها في قاعدة بيانات متجرك.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: .58,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'إغلاق',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _sectionHeader(
                      'البيانات الأساسية',
                      'اسم المنتج والتصنيف والباركود الخاص به.',
                    ),
                    const SizedBox(height: 13),
                    _field(
                      _name,
                      'اسم المنتج',
                      icon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(height: 12),
                    isCompact
                        ? Column(
                            children: [
                              _field(
                                _category,
                                'التصنيف',
                                icon: Icons.category_outlined,
                              ),
                              const SizedBox(height: 12),
                              _field(
                                _barcode,
                                'الباركود',
                                keyboardType: TextInputType.number,
                                requiredField: false,
                                icon: Icons.qr_code_2_rounded,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _category,
                                  'التصنيف',
                                  icon: Icons.category_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  _barcode,
                                  'الباركود',
                                  keyboardType: TextInputType.number,
                                  requiredField: false,
                                  icon: Icons.qr_code_2_rounded,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 22),
                    _sectionHeader(
                      'سعر الصرف العام',
                      'سعر موحّد على المتجر. تغيير السعر يعيد احتساب المقابل السوري للمنتجات القديمة والجديدة.',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0x252D9BFF), Color(0x1F786BFF)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF8C82FF).withValues(alpha: .22),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.currency_exchange_rounded,
                            color: Color(0xFF9D92FF),
                          ),
                          const SizedBox(width: 11),
                          const Expanded(child: Text('1 دولار أمريكي يساوي')),
                          Text(
                            '${_money(ProductCatalog.instance.exchangeRateSypPerUsd)} ل.س',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFBDB5FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionHeader(
                      'سعر الشراء',
                      'أدخل السعر بالدولار أو بالليرة، وسيتم تحويل العملة الثانية تلقائياً.',
                    ),
                    const SizedBox(height: 12),
                    isCompact
                        ? Column(
                            children: [
                              _numberField(
                                controller: _purchaseUsd,
                                label: 'سعر الشراء بالدولار',
                                suffix: 'USD',
                                onChanged: (_) =>
                                    _syncSypFromUsd(_purchaseUsd, _purchaseSyp),
                              ),
                              const SizedBox(height: 12),
                              _numberField(
                                controller: _purchaseSyp,
                                label: 'سعر الشراء بالسوري',
                                suffix: 'ل.س',
                                onChanged: (_) =>
                                    _syncUsdFromSyp(_purchaseSyp, _purchaseUsd),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _numberField(
                                  controller: _purchaseUsd,
                                  label: 'سعر الشراء بالدولار',
                                  suffix: 'USD',
                                  onChanged: (_) => _syncSypFromUsd(
                                    _purchaseUsd,
                                    _purchaseSyp,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _numberField(
                                  controller: _purchaseSyp,
                                  label: 'سعر الشراء بالسوري',
                                  suffix: 'ل.س',
                                  onChanged: (_) => _syncUsdFromSyp(
                                    _purchaseSyp,
                                    _purchaseUsd,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 22),
                    _sectionHeader(
                      'سعر البيع',
                      'يمكن تعديل أي عملة، وسيُعاد حساب المقابل مباشرة.',
                    ),
                    const SizedBox(height: 12),
                    isCompact
                        ? Column(
                            children: [
                              _numberField(
                                controller: _sellingUsd,
                                label: 'سعر البيع بالدولار',
                                suffix: 'USD',
                                onChanged: (_) =>
                                    _syncSypFromUsd(_sellingUsd, _sellingSyp),
                              ),
                              const SizedBox(height: 12),
                              _numberField(
                                controller: _sellingSyp,
                                label: 'سعر البيع بالسوري',
                                suffix: 'ل.س',
                                onChanged: (_) =>
                                    _syncUsdFromSyp(_sellingSyp, _sellingUsd),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _numberField(
                                  controller: _sellingUsd,
                                  label: 'سعر البيع بالدولار',
                                  suffix: 'USD',
                                  onChanged: (_) =>
                                      _syncSypFromUsd(_sellingUsd, _sellingSyp),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _numberField(
                                  controller: _sellingSyp,
                                  label: 'سعر البيع بالسوري',
                                  suffix: 'ل.س',
                                  onChanged: (_) =>
                                      _syncUsdFromSyp(_sellingSyp, _sellingUsd),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26A69A).withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF26A69A).withValues(alpha: .22),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.trending_up_rounded,
                            color: Color(0xFF26A69A),
                            size: 24,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'الربح المتوقع للقطعة',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_usdMoney(profitUsd)}  •  ${_money(profitSyp)}',
                                  style: TextStyle(
                                    color: profitUsd >= 0
                                        ? const Color(0xFF26A69A)
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionHeader(
                      'المخزون',
                      'حدد الكمية المتوفرة وحد التنبيه عند انخفاض المخزون.',
                    ),
                    const SizedBox(height: 12),
                    isCompact
                        ? Column(
                            children: [
                              _field(
                                _quantity,
                                'الكمية الحالية',
                                keyboardType: TextInputType.number,
                                icon: Icons.inventory_outlined,
                              ),
                              const SizedBox(height: 12),
                              _field(
                                _minimum,
                                'حد التنبيه',
                                keyboardType: TextInputType.number,
                                icon: Icons.notifications_active_outlined,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _quantity,
                                  'الكمية الحالية',
                                  keyboardType: TextInputType.number,
                                  icon: Icons.inventory_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  _minimum,
                                  'حد التنبيه',
                                  keyboardType: TextInputType.number,
                                  icon: Icons.notifications_active_outlined,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 12),
                    _field(
                      _description,
                      'وصف أو ملاحظات',
                      requiredField: false,
                      maxLines: 2,
                      icon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: .30),
                      title: const Text(
                        'المنتج ظاهر ومتاح للبيع',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'يمكنك إخفاؤه دون حذفه من سجلات المتجر.',
                      ),
                      value: _isActive,
                      activeThumbColor: const Color(0xFF786BFF),
                      onChanged: (value) => setState(() => _isActive = value),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              editing ? 'حفظ التعديلات' : 'حفظ المنتج',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF786BFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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
      ),
    );
  }

  Widget _sectionHeader(String title, [String? subtitle]) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: subtitle == null ? 22 : 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9A90FF), Color(0xFF675BEB)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .55),
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool requiredField = true,
    TextInputType? keyboardType,
    int maxLines = 1,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .26),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: .35),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: .32),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (requiredField && text.isEmpty) return 'هذا الحقل مطلوب';
        if (controller == _name && text.length < 2)
          return 'اسم المنتج يجب أن يتكون من حرفين على الأقل';
        if (controller == _quantity || controller == _minimum) {
          final number = int.tryParse(text);
          if (number == null || number < 0) return 'أدخل رقماً صحيحاً';
        }
        if (controller == _barcode &&
            text.isNotEmpty &&
            !RegExp(r'^\d{8,14}$').hasMatch(text)) {
          return 'أدخل باركوداً رقمياً من 8 إلى 14 خانة';
        }
        return null;
      },
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    ValueChanged<String>? onChanged,
    bool allowZero = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .26),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: .35),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: .32),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
      validator: (value) {
        final number = double.tryParse((value ?? '').trim());
        if (number == null ||
            !number.isFinite ||
            (allowZero ? number < 0 : number <= 0)) {
          return allowZero ? 'أدخل مبلغاً صحيحاً' : 'يجب أن يكون أكبر من صفر';
        }
        return null;
      },
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.product;
    final barcode = _barcode.text.trim().isNotEmpty
        ? _barcode.text.trim()
        : (old?.barcode ?? ProductCatalog.instance.generateBarcode());

    final currentRate = ProductCatalog.instance.exchangeRateSypPerUsd;
    final purchaseUsd = double.parse(_purchaseUsd.text.trim());
    final sellingUsd = double.parse(_sellingUsd.text.trim());

    final product = ProductModel(
      id: old?.id ?? 'NEW',
      name: _name.text.trim(),
      barcode: barcode,
      category: _category.text.trim(),
      purchasePriceUsd: purchaseUsd,
      purchasePriceSyp: (purchaseUsd * currentRate).roundToDouble(),
      sellingPriceUsd: sellingUsd,
      sellingPriceSyp: (sellingUsd * currentRate).roundToDouble(),
      exchangeRateSypPerUsd: currentRate,
      stockQuantity: int.parse(_quantity.text.trim()),
      minimumStock: int.parse(_minimum.text.trim()),
      description: _description.text.trim(),
      isActive: _isActive,
      createdAt: old?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(context, product);
  }
}

class _ExchangeRateDialog extends StatefulWidget {
  final double currentRate;
  const _ExchangeRateDialog({required this.currentRate});

  @override
  State<_ExchangeRateDialog> createState() => _ExchangeRateDialogState();
}

class _ExchangeRateDialogState extends State<_ExchangeRateDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _numberText(widget.currentRate, 2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF958BFF).withValues(alpha: .26),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF756BFF).withValues(alpha: .14),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF958BFF), Color(0xFF6255E8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.currency_exchange_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إعداد سعر الصرف',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'تحديث العملة المرجعية للمتجر',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('حدد قيمة الدولار الواحد بالليرة السورية.'),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'سعر 1 دولار',
                    suffixText: 'ل.س',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: .26),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final rate = double.tryParse((value ?? '').trim());
                    if (rate == null || !rate.isFinite || rate <= 0) {
                      return 'أدخل سعر صرف أكبر من صفر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'عند الحفظ ستُعاد احتساب الأسعار بالليرة السورية لجميع المنتجات القديمة والجديدة، بالاعتماد على أسعارها بالدولار.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .58),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          Navigator.pop(
                            context,
                            double.parse(_controller.text.trim()),
                          );
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('حفظ سعر الصرف'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF786BFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
    );
  }
}

class _DualPriceCell extends StatelessWidget {
  final double usd;
  final double syp;
  final bool emphasized;

  const _DualPriceCell({
    required this.usd,
    required this.syp,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _usdMoney(usd),
          style: TextStyle(
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _money(syp),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: .58),
          ),
        ),
      ],
    );
  }
}

class Ean13Barcode extends StatelessWidget {
  final String value;
  const Ean13Barcode({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final valid = RegExp(r'^\d{13}$').hasMatch(value);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (valid)
          SizedBox(
            width: 280,
            height: 76,
            child: CustomPaint(painter: _Ean13Painter(value)),
          )
        else
          const Text('هذا الباركود ليس بصيغة EAN-13 لعرضه كخطوط.'),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(letterSpacing: 2, fontSize: 13)),
      ],
    );
  }
}

class _Ean13Painter extends CustomPainter {
  final String value;
  _Ean13Painter(this.value);

  static const _leftOdd = [
    '0001101',
    '0011001',
    '0010011',
    '0111101',
    '0100011',
    '0110001',
    '0101111',
    '0111011',
    '0110111',
    '0001011',
  ];
  static const _leftEven = [
    '0100111',
    '0110011',
    '0011011',
    '0100001',
    '0011101',
    '0111001',
    '0000101',
    '0010001',
    '0001001',
    '0010111',
  ];
  static const _right = [
    '1110010',
    '1100110',
    '1101100',
    '1000010',
    '1011100',
    '1001110',
    '1010000',
    '1000100',
    '1001000',
    '1110100',
  ];
  static const _parity = [
    'OOOOOO',
    'OOEOEE',
    'OOEEOE',
    'OOEEEO',
    'OEOOEE',
    'OEEOOE',
    'OEEEOO',
    'OEOEOE',
    'OEOEEO',
    'OEEOEO',
  ];

  String _modules() {
    final first = int.parse(value[0]);
    final digits = value.split('').map((digit) => int.parse(digit)).toList();
    final parity = _parity[first];
    final buffer = StringBuffer('101');
    for (var i = 1; i <= 6; i++) {
      buffer.write(
        parity[i - 1] == 'O' ? _leftOdd[digits[i]] : _leftEven[digits[i]],
      );
    }
    buffer.write('01010');
    for (var i = 7; i <= 12; i++) {
      buffer.write(_right[digits[i]]);
    }
    buffer.write('101');
    return buffer.toString();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final modules = _modules();
    const quietModules = 7;
    final moduleWidth = size.width / (modules.length + quietModules * 2);
    final barPaint = Paint()..color = Colors.black;
    for (var i = 0; i < modules.length; i++) {
      if (modules[i] != '1') continue;
      final isGuard = i < 3 || (i >= 45 && i < 50) || i >= 92;
      final barHeight = isGuard ? size.height : size.height * .84;
      canvas.drawRect(
        Rect.fromLTWH(
          (quietModules + i) * moduleWidth,
          0,
          moduleWidth + .15,
          barHeight,
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Ean13Painter oldDelegate) =>
      oldDelegate.value != value;
}

String _money(num amount) => '${NumberFormat('#,##0.##').format(amount)} ل.س';
String _usdMoney(num amount) =>
    '\$${NumberFormat('#,##0.######').format(amount)}';
String _dualMoney(num usd, num syp) => '${_usdMoney(usd)} / ${_money(syp)}';
String _numberText(num value, int decimals) {
  if (!value.isFinite) return '';
  final fixed = value.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
