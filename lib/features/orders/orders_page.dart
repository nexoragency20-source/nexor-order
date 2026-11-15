import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../products/product_catalog.dart';
import '../products/product_model.dart';
import 'order_catalog.dart';
import '../../shared/models/order_model.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _searchController = TextEditingController();
  final _horizontalController = ScrollController();
  final _catalog = OrderCatalog.instance;
  OrderStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _catalog.load(force: true);
    _catalog.loadCustomers(force: true);
    ProductCatalog.instance.load(force: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  List<OrderModel> get _filteredOrders {
    final query = _searchController.text.trim().toLowerCase();
    return _catalog.orders.where((order) {
      final matchesQuery =
          query.isEmpty ||
          order.id.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query) ||
          order.phone.toLowerCase().contains(query) ||
          order.items.any(
            (item) =>
                item.productName.toLowerCase().contains(query) ||
                item.barcode.toLowerCase().contains(query),
          );
      final matchesStatus =
          _selectedStatus == null || order.status == _selectedStatus;
      return matchesQuery && matchesStatus;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AnimatedBuilder(
        animation: Listenable.merge([_catalog, ProductCatalog.instance]),
        builder: (context, _) {
          final orders = _filteredOrders;
          final isNarrow = MediaQuery.of(context).size.width < 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 22),
                _buildStatistics(),
                const SizedBox(height: 22),
                _buildToolbar(context),
                const SizedBox(height: 16),
                if (_catalog.isLoading && orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 72),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_catalog.errorMessage != null && orders.isEmpty)
                  _buildLoadError(context)
                else if (orders.isEmpty)
                  _buildEmptyState(context)
                else if (isNarrow)
                  ...orders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OrderCard(
                        order: order,
                        onDetails: () => _showOrderDetails(order),
                        onEdit: order.status == OrderStatus.pending
                            ? () => _openOrderForm(order: order)
                            : null,
                        onCancel: _canCancel(order)
                            ? () => _cancelOrder(order)
                            : null,
                      ),
                    ),
                  )
                else
                  _buildTable(context, orders),
                const SizedBox(height: 16),
                Text(
                  'عرض ${orders.length} من أصل ${_catalog.orders.length} طلب',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF25213F), Color(0xFF171923)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B84FF).withValues(alpha: .22),
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
              Icons.receipt_long_rounded,
              color: Color(0xFFAAA5FF),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة الطلبات والمبيعات',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'أنشئ الطلبات، تابع حالتها، وسجّل دفعات العملاء من مكان واحد.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .66),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: ProductCatalog.instance.hasLoaded
                ? () => _openOrderForm()
                : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('طلب جديد'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF776BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _StatCard(
          title: 'إجمالي الطلبات',
          value: '${_catalog.totalOrders}',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF8B84FF),
        ),
        _StatCard(
          title: 'طلبات جديدة',
          value: '${_catalog.pendingOrders}',
          icon: Icons.fiber_new_rounded,
          color: const Color(0xFFFFB547),
        ),
        _StatCard(
          title: 'قيد المعالجة',
          value: '${_catalog.processingOrders}',
          icon: Icons.sync_rounded,
          color: const Color(0xFF39A9FF),
        ),
        _StatCard(
          title: 'إجمالي المبيعات',
          value: _money(_catalog.totalSalesSyp),
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF2DD4A7),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 330,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ابحث برقم الطلب أو العميل أو الصنف',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: .35),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: .35),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: .35),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<OrderStatus?>(
              value: _selectedStatus,
              hint: const Text('كل الحالات'),
              borderRadius: BorderRadius.circular(12),
              items: [
                const DropdownMenuItem<OrderStatus?>(
                  value: null,
                  child: Text('كل الحالات'),
                ),
                ...OrderStatus.values.map(
                  (status) => DropdownMenuItem<OrderStatus?>(
                    value: status,
                    child: Text(_statusLabel(status)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedStatus = value),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            _searchController.clear();
            setState(() => _selectedStatus = null);
            _catalog.load(force: true);
            _catalog.loadCustomers(force: true);
            ProductCatalog.instance.load(force: true);
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تحديث'),
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context, List<OrderModel> orders) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: .35)),
          ),
          child: Scrollbar(
            controller: _horizontalController,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 1420),
                child: DataTable(
                  headingRowHeight: 58,
                  dataRowMinHeight: 68,
                  dataRowMaxHeight: 78,
                  columnSpacing: 24,
                  horizontalMargin: 20,
                  columns: const [
                    DataColumn(label: Text('رقم الطلب')),
                    DataColumn(label: Text('العميل')),
                    DataColumn(label: Text('الأصناف')),
                    DataColumn(label: Text('الإجمالي')),
                    DataColumn(label: Text('المدفوع / المتبقي')),
                    DataColumn(label: Text('حالة الدفع')),
                    DataColumn(label: Text('حالة الطلب')),
                    DataColumn(label: Text('التاريخ')),
                    DataColumn(label: Text('الإجراءات')),
                  ],
                  rows: orders.map((order) {
                    final itemNames = order.items
                        .map((item) => '${item.productName} × ${item.quantity}')
                        .join('، ');
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            order.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8B84FF),
                            ),
                          ),
                          onTap: () => _showOrderDetails(order),
                        ),
                        DataCell(
                          SizedBox(
                            width: 155,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  order.phone,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: .55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              itemNames,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _money(order.totalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (order.returnedSyp > 0)
                                Text(
                                  'مرتجع ${_money(order.returnedSyp)}',
                                  style: const TextStyle(
                                    color: Color(0xFF20B990),
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مدفوع ${_money(order.paidAmountSyp)}',
                                  style: const TextStyle(
                                    color: Color(0xFF2DD4A7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'متبقي ${_money(order.remainingSyp)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: .6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(_PaymentBadge(status: order.paymentStatus)),
                        DataCell(_StatusBadge(status: order.status)),
                        DataCell(
                          Text(
                            DateFormat('yyyy/MM/dd').format(order.createdAt),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'التفاصيل',
                                onPressed: () => _showOrderDetails(order),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 19,
                                ),
                              ),
                              IconButton(
                                tooltip: 'تعديل',
                                onPressed: order.status == OrderStatus.pending
                                    ? () => _openOrderForm(order: order)
                                    : null,
                                icon: const Icon(Icons.edit_outlined, size: 19),
                              ),
                              IconButton(
                                tooltip: 'إلغاء الطلب',
                                onPressed: _canCancel(order)
                                    ? () => _cancelOrder(order)
                                    : null,
                                icon: Icon(
                                  Icons.cancel_outlined,
                                  size: 19,
                                  color: _canCancel(order)
                                      ? Colors.redAccent
                                      : theme.disabledColor,
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
        const SizedBox(height: 8),
        Text(
          'اسحب شريط التمرير أسفل الجدول لعرض بقية الأعمدة',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: .5),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadError(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 46,
            color: Color(0xFFFFA726),
          ),
          const SizedBox(height: 12),
          const Text(
            'تعذر تحميل الطلبات',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            _catalog.errorMessage ?? 'تحقق من اتصال الخادم.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _catalog.load(force: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 58, horizontal: 22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 52,
            color: theme.colorScheme.onSurface.withValues(alpha: .28),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد طلبات مطابقة',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            'ابدأ بإنشاء طلب جديد أو غيّر خيارات البحث.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: () => _openOrderForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إنشاء أول طلب'),
          ),
        ],
      ),
    );
  }

  Future<void> _openOrderForm({OrderModel? order}) async {
    if (order != null && order.status != OrderStatus.pending) return;
    final draft = await showDialog<OrderModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OrderFormDialog(order: order),
    );
    if (draft == null || !mounted) return;
    try {
      if (order == null) {
        await _catalog.create(draft);
        _showMessage('تم إنشاء الطلب وحفظه في قاعدة البيانات.');
      } else {
        await _catalog.update(draft);
        _showMessage('تم تحديث الطلب.');
      }
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _showOrderDetails(OrderModel order) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('تفاصيل الطلب')),
              _StatusBadge(status: order.status),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.id,
                    style: Theme.of(dialogContext).textTheme.titleMedium
                        ?.copyWith(
                          color: const Color(0xFF8B84FF),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _DetailLine(label: 'اسم العميل', value: order.customerName),
                  _DetailLine(label: 'رقم الهاتف', value: order.phone),
                  _DetailLine(label: 'العنوان', value: order.address),
                  _DetailLine(
                    label: 'تاريخ الطلب',
                    value: DateFormat(
                      'yyyy/MM/dd - HH:mm',
                    ).format(order.createdAt),
                  ),
                  _DetailLine(
                    label: 'طريقة الدفع',
                    value: _paymentLabel(order.paymentMethod),
                  ),
                  const Divider(height: 26),
                  const Text(
                    'الأصناف',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  const SizedBox(height: 9),
                  ...order.items.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.productName} × ${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'سعر القطعة ${_money(item.unitPrice)}',
                                  style: Theme.of(
                                    dialogContext,
                                  ).textTheme.bodySmall,
                                ),
                                if (item.barcode.isNotEmpty)
                                  Text(
                                    'الباركود: ${item.barcode}',
                                    style: Theme.of(dialogContext)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontFamily: 'monospace'),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            _money(item.total),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 26),
                  _DetailLine(
                    label: 'إجمالي الطلب الأصلي',
                    value: _money(order.totalAmountSyp),
                  ),
                  if (order.returnedSyp > 0)
                    _DetailLine(
                      label: 'قيمة المرتجع',
                      value: '- ${_money(order.returnedSyp)}',
                    ),
                  _DetailLine(
                    label: 'الإجمالي بعد المرتجعات',
                    value: _money(order.totalAmount),
                  ),
                  _DetailLine(
                    label: 'المدفوع على الفاتورة',
                    value: _money(order.paidAmountSyp),
                  ),
                  _DetailLine(
                    label: 'المتبقي',
                    value: _money(order.remainingSyp),
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'حالة الدفع',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      _PaymentBadge(status: order.paymentStatus),
                    ],
                  ),
                  if (order.payments.isNotEmpty) ...[
                    const Divider(height: 26),
                    const Text(
                      'سجل الدفعات',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...order.payments.map(
                      (payment) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          radius: 17,
                          child: Icon(Icons.payments_outlined, size: 17),
                        ),
                        title: Text('${_money(payment.amountSypEquivalent)}'),
                        subtitle: Text(
                          '${_paymentLabel(payment.method)} • ${DateFormat('yyyy/MM/dd').format(payment.paidAt)}${payment.note.isEmpty ? '' : ' • ${payment.note}'}',
                        ),
                        trailing: Text(
                          payment.currency == PaymentCurrency.usd
                              ? 'USD'
                              : 'SYP',
                        ),
                      ),
                    ),
                  ],
                  if (order.note.isNotEmpty) ...[
                    const Divider(height: 26),
                    const Text(
                      'ملاحظات',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(order.note),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق'),
            ),
            if (order.status != OrderStatus.cancelled &&
                order.status != OrderStatus.completed &&
                order.remainingUsd > 0.000001)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _recordPayment(order);
                },
                icon: const Icon(Icons.payments_outlined),
                label: const Text('تسجيل دفعة'),
              ),
            if (order.status != OrderStatus.cancelled &&
                order.status != OrderStatus.completed)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _changeStatus(order);
                },
                icon: const Icon(Icons.sync_rounded),
                label: const Text('تغيير الحالة'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordPayment(OrderModel order) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    var currency = PaymentCurrency.syp;
    var method = PaymentMethod.cash;
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<_PaymentDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تسجيل دفعة للطلب'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'قيمة الدفعة',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (v) {
                        final x = double.tryParse(v ?? '');
                        return x == null || x <= 0
                            ? 'أدخل مبلغاً صحيحاً'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PaymentCurrency>(
                      initialValue: currency,
                      decoration: const InputDecoration(labelText: 'العملة'),
                      items: const [
                        DropdownMenuItem(
                          value: PaymentCurrency.syp,
                          child: Text('ليرة سورية'),
                        ),
                        DropdownMenuItem(
                          value: PaymentCurrency.usd,
                          child: Text('دولار أمريكي'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => currency = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: method,
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع',
                      ),
                      items: PaymentMethod.values
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(_paymentLabel(v)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => method = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'المتبقي: ${_money(order.remainingSyp)}',
                        style: const TextStyle(
                          color: Color(0xFF2DD4A7),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(
                    dialogContext,
                    _PaymentDraft(
                      amount: double.parse(amountController.text.trim()),
                      currency: currency,
                      method: method,
                      note: noteController.text.trim(),
                    ),
                  );
                },
                child: const Text('حفظ الدفعة'),
              ),
            ],
          ),
        ),
      ),
    );
    amountController.dispose();
    noteController.dispose();
    if (result == null || !mounted) return;
    try {
      await _catalog.recordPayment(
        order: order,
        amount: result.amount,
        currency: result.currency,
        method: result.method,
        note: result.note,
      );
      _showMessage('تم تسجيل الدفعة وتحديث رصيد الطلب.');
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _changeStatus(OrderModel order) async {
    OrderStatus selected = order.status;
    final options = [order.status, ..._nextStatuses(order.status)];
    if (options.length <= 1) return;
    final next = await showDialog<OrderStatus>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تغيير حالة الطلب'),
            content: DropdownButtonFormField<OrderStatus>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'الحالة الجديدة'),
              items: options
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_statusLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setDialogState(() => selected = value);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ),
      ),
    );
    if (next == null || !mounted) return;
    try {
      await _catalog.changeStatus(order, next);
      _showMessage(
        next == OrderStatus.processing
            ? 'تم اعتماد الطلب وخصم الكمية من المخزون.'
            : 'تم تحديث حالة الطلب.',
      );
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد إلغاء الطلب'),
          content: Text(
            'هل تريد إلغاء الطلب ${order.id}؟${order.status == OrderStatus.processing ? '\nسيتم إرجاع الكميات المصروفة إلى المخزون.' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('إلغاء الطلب'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _catalog.cancel(order);
      _showMessage('تم إلغاء الطلب وتحديث المخزون عند الحاجة.');
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  bool _canCancel(OrderModel order) =>
      order.status != OrderStatus.cancelled &&
      order.status != OrderStatus.completed &&
      order.status != OrderStatus.shipped;

  List<OrderStatus> _nextStatuses(OrderStatus current) {
    switch (current) {
      case OrderStatus.pending:
        return [OrderStatus.processing, OrderStatus.cancelled];
      case OrderStatus.processing:
        return [OrderStatus.shipped, OrderStatus.cancelled];
      case OrderStatus.shipped:
        return [OrderStatus.completed];
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return [];
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }
}

class _OrderFormDialog extends StatefulWidget {
  final OrderModel? order;
  const _OrderFormDialog({this.order});

  @override
  State<_OrderFormDialog> createState() => _OrderFormDialogState();
}

class _OrderFormDialogState extends State<_OrderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerName;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _note;
  late final TextEditingController _discountSyp;
  late final TextEditingController _shippingSyp;
  late final TextEditingController _initialPayment;
  late List<_OrderLineDraft> _lines;
  String _customerId = '__new_customer__';
  late OrderStatus _status;
  late PaymentMethod _paymentMethod;
  PaymentCurrency _initialCurrency = PaymentCurrency.syp;
  bool _saving = false;

  bool get _isEditing => widget.order != null;
  double get _rate => ProductCatalog.instance.exchangeRateSypPerUsd > 0
      ? ProductCatalog.instance.exchangeRateSypPerUsd
      : 1;
  double get _draftRate =>
      widget.order?.exchangeRateSypPerUsd != null &&
          widget.order!.exchangeRateSypPerUsd > 0
      ? widget.order!.exchangeRateSypPerUsd
      : _rate;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _customerName = TextEditingController(text: order?.customerName ?? '');
    _phone = TextEditingController(text: order?.phone ?? '');
    _address = TextEditingController(text: order?.address ?? '');
    _note = TextEditingController(text: order?.note ?? '');
    _discountSyp = TextEditingController(
      text: order == null ? '' : _plain(order.discountUsd * _draftRate),
    );
    _shippingSyp = TextEditingController(
      text: order == null ? '' : _plain(order.shippingUsd * _draftRate),
    );
    _initialPayment = TextEditingController();
    _customerId = order?.customerId?.isNotEmpty == true
        ? order!.customerId!
        : '__new_customer__';
    _status = order?.status ?? OrderStatus.pending;
    _paymentMethod = order?.paymentMethod ?? PaymentMethod.cashOnDelivery;
    _lines = order == null || order.items.isEmpty
        ? [_OrderLineDraft()]
        : order.items.map(_OrderLineDraft.fromItem).toList();
  }

  @override
  void dispose() {
    _customerName.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    _discountSyp.dispose();
    _shippingSyp.dispose();
    _initialPayment.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customers = OrderCatalog.instance.customers;
    final products = ProductCatalog.instance.products
        .where((p) => p.isActive)
        .toList();
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 860),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF282344), Color(0xFF171923)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0x33776BFF),
                      child: Icon(
                        Icons.add_shopping_cart_rounded,
                        color: Color(0xFFB4AEFF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'تعديل الطلب' : 'إنشاء طلب جديد',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'بيانات العميل والأصناف والدفع',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(22),
                    children: [
                      _sectionHeader(
                        'بيانات العميل',
                        Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: customers.any((c) => c.id == _customerId)
                            ? _customerId
                            : '__new_customer__',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'اختيار عميل محفوظ',
                          prefixIcon: Icon(Icons.people_alt_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '__new_customer__',
                            child: Text('عميل جديد / إدخال يدوي'),
                          ),
                          ...customers.map(
                            (customer) => DropdownMenuItem(
                              value: customer.id,
                              child: Text(
                                '${customer.name}${customer.phone.isEmpty ? '' : ' — ${customer.phone}'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _customerId = value;
                            if (value != '__new_customer__') {
                              final customer = customers.firstWhere(
                                (c) => c.id == value,
                              );
                              _customerName.text = customer.name;
                              _phone.text = customer.phone;
                              _address.text = customer.address;
                            } else {
                              _customerName.clear();
                              _phone.clear();
                              _address.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        _customerName,
                        'اسم العميل',
                        Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _textField(
                              _phone,
                              'رقم الهاتف',
                              Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              requiredField: false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _textField(
                              _address,
                              'عنوان التوصيل',
                              Icons.location_on_outlined,
                              requiredField: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _sectionHeader(
                              'أصناف الطلب',
                              Icons.inventory_2_outlined,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _addLine,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('إضافة صنف'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(
                        _lines.length,
                        (index) => _buildLine(index, products),
                      ),
                      const SizedBox(height: 16),
                      _sectionHeader('الخصم والشحن', Icons.calculate_outlined),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _textField(
                              _discountSyp,
                              'الخصم الإجمالي (ل.س)',
                              Icons.discount_outlined,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              requiredField: false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _textField(
                              _shippingSyp,
                              'تكلفة الشحن (ل.س)',
                              Icons.local_shipping_outlined,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              requiredField: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(
                        'الدفع وحالة الطلب',
                        Icons.payments_outlined,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PaymentMethod>(
                        initialValue: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'طريقة الدفع',
                          prefixIcon: Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        items: PaymentMethod.values
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(_paymentLabel(m)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null)
                            setState(() => _paymentMethod = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (!_isEditing)
                        DropdownButtonFormField<OrderStatus>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'حالة الطلب عند الإنشاء',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: OrderStatus.pending,
                              child: Text('جديد — دون خصم المخزون'),
                            ),
                            DropdownMenuItem(
                              value: OrderStatus.processing,
                              child: Text('قيد المعالجة — اعتماد وخصم المخزون'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _status = value);
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'يمكن تغيير حالة الطلب من شاشة التفاصيل. تعديل الأصناف متاح قبل اعتماد الطلب فقط.',
                          ),
                        ),
                      if (!_isEditing) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _textField(
                                _initialPayment,
                                'دفعة أولى (اختياري)',
                                Icons.payments_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                requiredField: false,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<PaymentCurrency>(
                                initialValue: _initialCurrency,
                                decoration: const InputDecoration(
                                  labelText: 'عملة الدفعة',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: PaymentCurrency.syp,
                                    child: Text('ليرة سورية'),
                                  ),
                                  DropdownMenuItem(
                                    value: PaymentCurrency.usd,
                                    child: Text('دولار أمريكي'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null)
                                    setState(() => _initialCurrency = value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      _textField(
                        _note,
                        'ملاحظات إضافية (اختياري)',
                        Icons.notes_rounded,
                        maxLines: 2,
                        requiredField: false,
                      ),
                      const SizedBox(height: 18),
                      _buildLiveTotal(theme),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded),
                              label: Text(
                                _saving
                                    ? 'جارٍ الحفظ...'
                                    : (_isEditing
                                          ? 'حفظ التعديلات'
                                          : 'إنشاء الطلب'),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF776BFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(int index, List<ProductModel> products) {
    final line = _lines[index];
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'الصنف ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (_lines.length > 1)
                IconButton(
                  tooltip: 'حذف الصنف من الطلب',
                  onPressed: () => _removeLine(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: products.any((p) => p.id == line.productId)
                ? line.productId!
                : '__manual__',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'ربط الصنف بالمخزون',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            items: [
              const DropdownMenuItem(
                value: '__manual__',
                child: Text('صنف يدوي — لا يخصم من المخزون'),
              ),
              ...products.map(
                (product) => DropdownMenuItem(
                  value: product.id,
                  child: Text(
                    '${product.name} • المتوفر ${product.stockQuantity}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                if (value == '__manual__') {
                  line.productId = null;
                } else {
                  final product = products.firstWhere((p) => p.id == value);
                  line.productId = product.id;
                  line.name.text = product.name;
                  line.barcode.text = product.barcode;
                  line.price.text = _plain(
                    product.sellingPriceUsd * _draftRate,
                  );
                }
              });
            },
          ),
          const SizedBox(height: 10),
          _textField(line.name, 'اسم الصنف', Icons.shopping_bag_outlined),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _textField(
                  line.quantity,
                  'الكمية',
                  Icons.numbers_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  line.price,
                  'سعر القطعة (ل.س)',
                  Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _textField(
            line.barcode,
            'الباركود (اختياري)',
            Icons.qr_code_2_rounded,
            requiredField: false,
          ),
          if (line.productId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: Color(0xFF8B84FF),
                ),
                const SizedBox(width: 5),
                Text(
                  'سيتم تحديث مخزون هذا الصنف عند اعتماد الطلب.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8B84FF),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveTotal(ThemeData theme) {
    var subtotal = 0.0;
    for (final line in _lines) {
      final quantity = int.tryParse(line.quantity.text) ?? 0;
      final price = double.tryParse(line.price.text) ?? 0;
      subtotal += quantity * price;
    }
    final discount = double.tryParse(_discountSyp.text) ?? 0;
    final shipping = double.tryParse(_shippingSyp.text) ?? 0;
    final total = (subtotal - discount + shipping)
        .clamp(0, double.infinity)
        .toDouble();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF766BFF).withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF8B84FF).withValues(alpha: .25),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'الإجمالي التقريبي',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            _money(total),
            style: const TextStyle(
              color: Color(0xFF8B84FF),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFF8B84FF)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      ),
    ],
  );

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: (_) {
        if (controller == _discountSyp ||
            controller == _shippingSyp ||
            _lines.any(
              (line) => line.quantity == controller || line.price == controller,
            ))
          setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (value) {
        if (requiredField && (value == null || value.trim().isEmpty))
          return 'هذا الحقل مطلوب';
        if (controller == _customerName && (value?.trim().length ?? 0) < 2)
          return 'اسم العميل قصير جداً';
        if (_lines.any((line) => line.quantity == controller)) {
          final quantity = int.tryParse(value ?? '');
          if (quantity == null || quantity <= 0) return 'أدخل كمية صحيحة';
        }
        if (_lines.any((line) => line.price == controller)) {
          final price = double.tryParse(value ?? '');
          if (price == null || price < 0) return 'أدخل سعراً صحيحاً';
        }
        if (controller == _initialPayment && (value ?? '').trim().isNotEmpty) {
          final amount = double.tryParse(value ?? '');
          if (amount == null || amount < 0) return 'أدخل دفعة صحيحة';
        }
        return null;
      },
    );
  }

  void _addLine() => setState(() => _lines.add(_OrderLineDraft()));

  void _removeLine(int index) {
    final removed = _lines.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) return;
    final rate = _draftRate;
    final items = <OrderItem>[];
    for (final line in _lines) {
      final quantity = int.parse(line.quantity.text.trim());
      final price = double.parse(line.price.text.trim());
      final product = line.productId == null
          ? null
          : ProductCatalog.instance.findById(line.productId!);
      if (line.productId != null && product == null) {
        _showFormError('أحد الأصناف المحددة لم يعد موجوداً في المخزون.');
        return;
      }
      items.add(
        OrderItem(
          productId: line.productId,
          productName: product?.name ?? line.name.text.trim(),
          barcode: product?.barcode ?? line.barcode.text.trim(),
          quantity: quantity,
          unitPrice: price,
          unitPriceUsd: price / rate,
          unitCostUsd: product?.purchasePriceUsd ?? 0,
        ),
      );
    }
    setState(() => _saving = true);
    final totalSyp =
        items.fold<double>(0, (sum, item) => sum + item.total) -
        (double.tryParse(_discountSyp.text.trim()) ?? 0) +
        (double.tryParse(_shippingSyp.text.trim()) ?? 0);
    final draft = OrderModel(
      recordId: widget.order?.recordId ?? '',
      id: widget.order?.id ?? 'NEW',
      customerId: _customerId == '__new_customer__' ? null : _customerId,
      customerName: _customerName.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      items: items,
      status: widget.order?.status ?? _status,
      paymentMethod: _paymentMethod,
      createdAt: widget.order?.createdAt ?? DateTime.now(),
      note: _note.text.trim(),
      exchangeRateSypPerUsd: rate,
      discountUsd: (double.tryParse(_discountSyp.text.trim()) ?? 0) / rate,
      shippingUsd: (double.tryParse(_shippingSyp.text.trim()) ?? 0) / rate,
      totalAmountSyp: totalSyp.clamp(0, double.infinity).toDouble(),
      initialPaymentAmount: _isEditing
          ? 0
          : (double.tryParse(_initialPayment.text.trim()) ?? 0),
      initialPaymentCurrency: _initialCurrency,
    );
    if (draft.initialPaymentAmount > 0) {
      final paymentUsd = _initialCurrency == PaymentCurrency.usd
          ? draft.initialPaymentAmount
          : draft.initialPaymentAmount / rate;
      if (paymentUsd > (draft.totalAmountSyp / rate) + 0.000001) {
        setState(() => _saving = false);
        _showFormError('الدفعة الأولى أكبر من إجمالي الطلب.');
        return;
      }
    }
    if (mounted) Navigator.pop(context, draft);
  }

  void _showFormError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}

class _OrderLineDraft {
  String? productId;
  final TextEditingController name;
  final TextEditingController barcode;
  final TextEditingController quantity;
  final TextEditingController price;

  _OrderLineDraft({
    this.productId,
    String name = '',
    String barcode = '',
    String quantity = '1',
    String price = '',
  }) : name = TextEditingController(text: name),
       barcode = TextEditingController(text: barcode),
       quantity = TextEditingController(text: quantity),
       price = TextEditingController(text: price);

  factory _OrderLineDraft.fromItem(OrderItem item) => _OrderLineDraft(
    productId: item.productId,
    name: item.productName,
    barcode: item.barcode,
    quantity: '${item.quantity}',
    price: _plain(item.unitPrice),
  );

  void dispose() {
    name.dispose();
    barcode.dispose();
    quantity.dispose();
    price.dispose();
  }
}

class _PaymentDraft {
  final double amount;
  final PaymentCurrency currency;
  final PaymentMethod method;
  final String note;
  const _PaymentDraft({
    required this.amount,
    required this.currency,
    required this.method,
    required this.note,
  });
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 225,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  const _OrderCard({
    required this.order,
    required this.onDetails,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: .35)),
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
                    order.id,
                    style: const TextStyle(
                      color: Color(0xFF8B84FF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const Divider(height: 22),
            _DetailLine(label: 'العميل', value: order.customerName),
            _DetailLine(label: 'الهاتف', value: order.phone),
            _DetailLine(
              label: 'الأصناف',
              value: order.items
                  .map((item) => '${item.productName} × ${item.quantity}')
                  .join('، '),
            ),
            _DetailLine(
              label: 'الإجمالي بعد المرتجعات',
              value: _money(order.totalAmount),
            ),
            if (order.returnedSyp > 0)
              _DetailLine(
                label: 'قيمة المرتجع',
                value: '- ${_money(order.returnedSyp)}',
              ),
            _DetailLine(
              label: 'المدفوع على الفاتورة',
              value: _money(order.paidAmountSyp),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'حالة الدفع',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                _PaymentBadge(status: order.paymentStatus),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('التفاصيل'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'تعديل',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'إلغاء',
                  onPressed: onCancel,
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: onCancel == null
                        ? theme.disabledColor
                        : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  const _DetailLine({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .55),
              fontSize: 12,
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

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.pending => const Color(0xFFF59E0B),
      OrderStatus.processing => const Color(0xFF3B82F6),
      OrderStatus.shipped => const Color(0xFF8B5CF6),
      OrderStatus.completed => const Color(0xFF10B981),
      OrderStatus.cancelled => const Color(0xFFEF4444),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final PaymentStatus status;
  const _PaymentBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PaymentStatus.unpaid => const Color(0xFFEF4444),
      PaymentStatus.partiallyPaid => const Color(0xFFF59E0B),
      PaymentStatus.paid => const Color(0xFF10B981),
    };
    final label = switch (status) {
      PaymentStatus.unpaid => 'غير مدفوع',
      PaymentStatus.partiallyPaid => 'مدفوع جزئياً',
      PaymentStatus.paid => 'مدفوع',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _statusLabel(OrderStatus status) => switch (status) {
  OrderStatus.pending => 'جديد',
  OrderStatus.processing => 'قيد المعالجة',
  OrderStatus.shipped => 'تم الشحن',
  OrderStatus.completed => 'مكتمل',
  OrderStatus.cancelled => 'ملغي',
};

String _paymentLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'نقدي',
  PaymentMethod.card => 'بطاقة',
  PaymentMethod.transfer => 'تحويل بنكي',
  PaymentMethod.cashOnDelivery => 'الدفع عند الاستلام',
  PaymentMethod.other => 'أخرى',
};

String _money(double value) => '${NumberFormat('#,##0.##').format(value)} ل.س';
String _plain(double value) => NumberFormat('0.################').format(value);
