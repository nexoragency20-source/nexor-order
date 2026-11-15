import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'returns_catalog.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  final _catalog = ReturnCatalog.instance;
  final _search = TextEditingController();
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _catalog.load(force: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SalesReturnRecord> get _visible {
    final query = _search.text.trim().toLowerCase();
    return _catalog.returns.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.returnNumber.toLowerCase().contains(query) ||
          item.orderNumber.toLowerCase().contains(query) ||
          item.customerName.toLowerCase().contains(query) ||
          item.items.any(
            (line) => line.productName.toLowerCase().contains(query),
          );
      final matchesFilter = _filter == 'ALL' || item.status == _filter;
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AnimatedBuilder(
        animation: _catalog,
        builder: (context, _) {
          final rows = _visible;
          return RefreshIndicator(
            onRefresh: () => _catalog.load(force: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  const SizedBox(height: 20),
                  _summaryCards(context),
                  const SizedBox(height: 20),
                  _toolbar(context),
                  const SizedBox(height: 14),
                  if (_catalog.isLoading && _catalog.returns.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 70),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_catalog.errorMessage != null &&
                      _catalog.returns.isEmpty)
                    _errorState(context)
                  else if (rows.isEmpty)
                    _emptyState(context)
                  else
                    ...rows.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReturnCard(
                          item: item,
                          onReceive: item.status == 'REQUESTED'
                              ? () => _receive(item)
                              : null,
                          onReject: item.status == 'REQUESTED'
                              ? () => _reject(item)
                              : null,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'عرض ${rows.length} من أصل ${_catalog.returns.length} مرتجع',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .5),
                      fontSize: 11,
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

  Widget _header(BuildContext context) {
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
              Icons.assignment_return_rounded,
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
                  'إدارة المرتجعات والاستبدال',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'استلام المرتجع، إعادة المخزون، وتسوية قيمة العميل من سجل واحد.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .66),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _catalog.eligibleOrders.isEmpty ? null : _createReturn,
            icon: const Icon(Icons.add_rounded),
            label: const Text('مرتجع جديد'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF776BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCards(BuildContext context) {
    final summary = _catalog.summary;
    final returnedUsd = _n(summary['returnedUsd']);
    final returnedSyp = _n(summary['returnedSyp']);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 760 ? 2 : 4;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'طلبات قيد المراجعة',
                value: '${summary['requestedCount'] ?? 0}',
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFFE3A33A),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'مرتجعات مستلمة',
                value: '${summary['receivedCount'] ?? 0}',
                icon: Icons.inventory_rounded,
                color: const Color(0xFF20B990),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'إجمالي المرتجع USD',
                value: _money(returnedUsd),
                icon: Icons.attach_money_rounded,
                color: const Color(0xFF7C73F5),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                title: 'إجمالي المرتجع ل.س',
                value: _money(returnedSyp),
                icon: Icons.currency_exchange_rounded,
                color: const Color(0xFF4EA4F5),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 290,
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ابحث برقم المرتجع أو الطلب أو العميل...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        _filterChip('الكل', 'ALL'),
        _filterChip('قيد المراجعة', 'REQUESTED'),
        _filterChip('مستلم', 'RECEIVED'),
        _filterChip('مرفوض', 'REJECTED'),
        IconButton.filledTonal(
          tooltip: 'تحديث',
          onPressed: () => _catalog.load(force: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) => ChoiceChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
    selectedColor: const Color(0xFF6C63FF).withValues(alpha: .16),
    side: BorderSide(
      color: _filter == value
          ? const Color(0xFF6C63FF)
          : Colors.grey.withValues(alpha: .2),
    ),
    labelStyle: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _filter == value ? const Color(0xFF8B84FF) : null,
    ),
  );

  Widget _emptyState(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.withValues(alpha: .12)),
    ),
    child: Column(
      children: [
        Icon(
          Icons.assignment_return_outlined,
          size: 42,
          color: Colors.grey.withValues(alpha: .55),
        ),
        const SizedBox(height: 12),
        const Text(
          'لا توجد مرتجعات ضمن هذا العرض',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'يمكنك بدء مرتجع جديد من طلب تم شحنه أو إكماله.',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _errorState(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 30),
        const SizedBox(height: 8),
        Text(_catalog.errorMessage ?? 'تعذر التحميل'),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _catalog.load(force: true),
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
        ),
      ],
    ),
  );

  Future<void> _createReturn() async {
    final result = await showDialog<_CreateReturnDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateReturnDialog(orders: _catalog.eligibleOrders),
    );
    if (result == null || !mounted) return;
    try {
      await _catalog.create(
        order: result.order,
        items: result.items,
        settlementType: result.settlementType,
        currency: result.currency,
        reason: result.reason,
        notes: result.notes,
      );
      if (mounted)
        _notice(
          'تم إنشاء طلب المرتجع. لم يتغير المخزون أو الصندوق بعد.',
          success: true,
        );
    } on ReturnCatalogException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  Future<void> _receive(SalesReturnRecord item) async {
    DateTime selectedDate = DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد استلام المرتجع'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سيتم اعتماد المرتجع ${item.returnNumber} وتسجيل حركة المخزون والتسوية المالية.',
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.event_available_rounded,
                      color: Color(0xFF776BFF),
                    ),
                    title: const Text('تاريخ الاستلام'),
                    subtitle: Text(
                      DateFormat('yyyy/MM/dd').format(selectedDate),
                    ),
                    trailing: const Icon(Icons.edit_calendar_rounded),
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (value != null)
                        setDialogState(
                          () => selectedDate = DateTime(
                            value.year,
                            value.month,
                            value.day,
                            DateTime.now().hour,
                            DateTime.now().minute,
                          ),
                        );
                    },
                  ),
                  Text(
                    'التسوية: ${item.settlementType == 'CASH' ? 'رد نقدي من الصندوق' : 'إضافة رصيد للعميل'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8B84FF),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'تأكد من استلام البضاعة فعلياً قبل المتابعة.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('اعتماد الاستلام'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _catalog.receive(
        item,
        selectedDate,
        'تم تأكيد استلام البضاعة فعلياً',
      );
      if (mounted)
        _notice(
          'تم استلام المرتجع وتحديث المخزون والتسوية المالية.',
          success: true,
        );
    } on ReturnCatalogException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  Future<void> _reject(SalesReturnRecord item) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض طلب المرتجع'),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: reason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'سبب الرفض (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD85B67),
              ),
              child: const Text('تأكيد الرفض'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _catalog.reject(item, reason.text.trim());
        if (mounted)
          _notice(
            'تم رفض طلب المرتجع دون تعديل المخزون أو الصندوق.',
            success: true,
          );
      } on ReturnCatalogException catch (error) {
        if (mounted) _notice(error.message);
      }
    }
    reason.dispose();
  }

  void _notice(String text, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success
            ? const Color(0xFF168B6B)
            : const Color(0xFFD85B67),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: .55),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
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

class _ReturnCard extends StatelessWidget {
  final SalesReturnRecord item;
  final VoidCallback? onReceive;
  final VoidCallback? onReject;
  const _ReturnCard({required this.item, this.onReceive, this.onReject});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(item.status);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.returnNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'طلب ${item.orderNumber}  •  ${item.customerName}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: .55,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: item.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: item.items
                .map(
                  (line) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: .045,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${line.productName} × ${_quantity(line.quantity)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 13),
          const Divider(height: 1),
          const SizedBox(height: 11),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${_money(item.amountUsdEquivalent)} USD',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8B84FF),
                  fontSize: 14,
                ),
              ),
              Text(
                '${_money(item.amountSypEquivalent)} ل.س',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: .68),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              Text(
                item.settlementType == 'CASH' ? 'رد نقدي' : 'رصيد للعميل',
                style: TextStyle(
                  color: item.settlementType == 'CASH'
                      ? const Color(0xFFE39A42)
                      : const Color(0xFF4EA4F5),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                DateFormat('yyyy/MM/dd').format(item.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
          if (item.reason.isNotEmpty || item.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [item.reason, item.notes].where((e) => e.isNotEmpty).join(' • '),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: .5),
                fontSize: 10,
              ),
            ),
          ],
          if (onReceive != null || onReject != null) ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.block_rounded, size: 17),
                    label: const Text('رفض الطلب'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD85B67),
                      side: const BorderSide(color: Color(0x55D85B67)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onReceive,
                    icon: const Icon(Icons.inventory_2_rounded, size: 17),
                    label: const Text('تأكيد الاستلام'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (item.status == 'RECEIVED' && item.receivedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'تم الاستلام بتاريخ ${DateFormat('yyyy/MM/dd').format(item.receivedAt!)}',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = switch (status) {
      'REQUESTED' => 'قيد المراجعة',
      'RECEIVED' => 'تم الاستلام',
      'REJECTED' => 'مرفوض',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CreateReturnDraft {
  final ReturnableOrder order;
  final List<Map<String, dynamic>> items;
  final String settlementType;
  final String currency;
  final String reason;
  final String notes;
  const _CreateReturnDraft({
    required this.order,
    required this.items,
    required this.settlementType,
    required this.currency,
    required this.reason,
    required this.notes,
  });
}

class _CreateReturnDialog extends StatefulWidget {
  final List<ReturnableOrder> orders;
  const _CreateReturnDialog({required this.orders});
  @override
  State<_CreateReturnDialog> createState() => _CreateReturnDialogState();
}

class _CreateReturnDialogState extends State<_CreateReturnDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  String? _selectedOrderId;
  String _settlementType = 'CASH';
  String _currency = 'SYP';
  bool _saving = false;
  List<_ReturnQuantityDraft> _lines = [];

  ReturnableOrder? get _order {
    for (final item in widget.orders) {
      if (item.id == _selectedOrderId) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.orders.isNotEmpty) {
      _selectedOrderId = widget.orders.first.id;
      _resetLines();
    }
  }

  void _resetLines() {
    for (final line in _lines) {
      line.dispose();
    }
    _lines = (_order?.items ?? [])
        .map((item) => _ReturnQuantityDraft(item))
        .toList();
  }

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _estimateUsd {
    final order = _order;
    if (order == null || order.subtotalUsd <= 0) return 0;
    final factor = ((order.subtotalUsd - order.discountUsd) / order.subtotalUsd)
        .clamp(0, 1);
    return _lines.fold<double>(0, (sum, line) {
      final quantity = double.tryParse(line.quantity.text.trim()) ?? 0;
      return sum + quantity * line.item.unitPriceUsd * factor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_return_rounded, color: Color(0xFF8B84FF)),
            SizedBox(width: 10),
            Text('إنشاء مرتجع جديد'),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedOrderId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الطلب الأصلي',
                      prefixIcon: Icon(Icons.receipt_long_rounded),
                    ),
                    items: widget.orders
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.orderNumber} — ${item.customerName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedOrderId = value;
                      _resetLines();
                    }),
                    validator: (value) =>
                        value == null ? 'حدد الطلب الأصلي' : null,
                  ),
                  if (order != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFF8B84FF),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${order.customerName}  •  ${order.customerPhone}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            order.status == 'COMPLETED' ? 'مكتمل' : 'مشحون',
                            style: const TextStyle(
                              color: Color(0xFF20B990),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      'الأصناف والكميات المراد إرجاعها',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._lines.map(
                      (line) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: .15),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'متاح ${_quantity(line.item.returnableQuantity)} من ${_quantity(line.item.quantity)}  •  ${_money(line.item.unitPriceSyp)} ل.س',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 105,
                              child: TextFormField(
                                controller: line.quantity,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'الكمية',
                                  hintText: '0',
                                  isDense: true,
                                ),
                                validator: (value) {
                                  final raw = (value ?? '').trim();
                                  if (raw.isEmpty) return null;
                                  final quantity = double.tryParse(raw);
                                  if (quantity == null ||
                                      !quantity.isFinite ||
                                      quantity < 0)
                                    return 'قيمة غير صحيحة';
                                  if (quantity >
                                      line.item.returnableQuantity + .000001)
                                    return 'الحد ${_quantity(line.item.returnableQuantity)}';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20B990).withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calculate_outlined,
                            color: Color(0xFF20B990),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'قيمة المرتجع التقديرية بعد توزيع الخصم',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${_money(_estimateUsd)} USD',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF20B990),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _settlementType,
                    decoration: const InputDecoration(
                      labelText: 'طريقة التسوية',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'CASH',
                        child: Text('رد المبلغ نقداً من الصندوق'),
                      ),
                      DropdownMenuItem(
                        value: 'CUSTOMER_CREDIT',
                        child: Text('إضافة رصيد دائن للعميل'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _settlementType = value ?? 'CASH'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(
                      labelText: 'عملة التسوية',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'SYP',
                        child: Text('ليرة سورية SYP'),
                      ),
                      DropdownMenuItem(value: 'USD', child: Text('دولار USD')),
                    ],
                    onChanged: (value) =>
                        setState(() => _currency = value ?? 'SYP'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _reason,
                    decoration: const InputDecoration(
                      labelText: 'سبب الإرجاع',
                      prefixIcon: Icon(Icons.info_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات إضافية (اختياري)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'لن يتغير المخزون أو الصندوق عند إنشاء الطلب. يتم التحديث فقط بعد تأكيد استلام البضاعة.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ طلب المرتجع'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final order = _order;
    if (order == null) return;
    if (_settlementType == 'CUSTOMER_CREDIT' && order.customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هذا الطلب غير مرتبط بعميل، لذلك لا يمكن إضافة رصيد دائن.',
          ),
        ),
      );
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (final line in _lines) {
      final text = line.quantity.text.trim();
      if (text.isEmpty) continue;
      final quantity = double.tryParse(text) ?? 0;
      if (quantity <= 0) continue;
      items.add({'orderItemId': line.item.orderItemId, 'quantity': quantity});
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل كمية لصنف واحد على الأقل.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _CreateReturnDraft(
        order: order,
        items: items,
        settlementType: _settlementType,
        currency: _currency,
        reason: _reason.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }
}

class _ReturnQuantityDraft {
  final ReturnableOrderItem item;
  final TextEditingController quantity = TextEditingController();
  _ReturnQuantityDraft(this.item);
  void dispose() => quantity.dispose();
}

Color _statusColor(String status) => switch (status) {
  'REQUESTED' => const Color(0xFFE3A33A),
  'RECEIVED' => const Color(0xFF20B990),
  'REJECTED' => const Color(0xFFD85B67),
  _ => const Color(0xFF958BFF),
};

double _n(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _money(double value) => NumberFormat('#,##0.##').format(value);
String _quantity(double value) => NumberFormat('#,##0.###').format(value);
