import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'finance_catalog.dart';
import 'finance_models.dart';
import 'finance_report_pdf.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final FinanceCatalog _catalog = FinanceCatalog.instance;
  DateTime _selectedDate = DateTime.now();

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _catalog.load(date: _dateKey, force: true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AnimatedBuilder(
        animation: _catalog,
        builder: (context, _) {
          final snapshot = _catalog.snapshot;
          final summary = snapshot?.summary;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(),
                const SizedBox(height: 20),
                if (_catalog.errorMessage != null) _buildError(),
                if (summary != null) ...[
                  _buildStats(summary),
                  const SizedBox(height: 20),
                ],
                _buildToolbar(),
                const SizedBox(height: 14),
                _buildActions(),
                const SizedBox(height: 18),
                if (_catalog.isLoading && snapshot == null)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot == null)
                  _buildNoData()
                else
                  _buildMovements(snapshot.items),
                const SizedBox(height: 14),
                if (snapshot != null)
                  Text(
                    'عرض ${snapshot.items.length} حركة بتاريخ ${DateFormat('yyyy/MM/dd').format(_selectedDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .5),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF27213F), Color(0xFF191A29)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF8175FF).withValues(alpha: .35),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF8175FF).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFFA79FFF),
              size: 27,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEXOR FINANCE',
                  style: TextStyle(
                    color: Color(0xFFA79FFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'الصندوق والحركة المالية',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'تابع المقبوضات والمدفوعات والسحب والإيداع والتحويل بين العملات من مكان واحد.',
                  style: TextStyle(
                    color: Color(0xFFB7B4C5),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (MediaQuery.of(context).size.width > 760)
            const Icon(Icons.bolt_rounded, color: Color(0xFF958BFF), size: 30),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(_catalog.errorMessage ?? 'حدث خطأ غير متوقع.')),
          TextButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }

  Widget _buildStats(FinanceSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 650
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FinanceMetric(
              width: width,
              title: 'رصيد الصندوق بالدولار',
              value: '${_money(summary.cashBalanceUsd)} USD',
              caption: 'النقد المتوفر بعملة الدولار',
              icon: Icons.attach_money_rounded,
              color: const Color(0xFF28CDA3),
            ),
            _FinanceMetric(
              width: width,
              title: 'رصيد الصندوق بالليرة',
              value: '${_money(summary.cashBalanceSyp)} ل.س',
              caption: 'النقد المتوفر بالليرة السورية',
              icon: Icons.payments_rounded,
              color: const Color(0xFF4CA7F5),
            ),
            _FinanceMetric(
              width: width,
              title: 'مقبوضات اليوم',
              value: '${_money(summary.todayReceiptsUsdEquivalent)} USD',
              caption:
                  '${_money(summary.todayReceiptsSypEquivalent)} ل.س مكافئ',
              icon: Icons.south_west_rounded,
              color: const Color(0xFF28CDA3),
            ),
            _FinanceMetric(
              width: width,
              title: 'مدفوعات اليوم',
              value: '${_money(summary.todayPaymentsUsdEquivalent)} USD',
              caption:
                  '${_money(summary.todayPaymentsSypEquivalent)} ل.س مكافئ',
              icon: Icons.north_east_rounded,
              color: const Color(0xFFF0A84B),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    final snapshot = _catalog.snapshot;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text(DateFormat('yyyy/MM/dd').format(_selectedDate)),
        ),
        OutlinedButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('تحديث'),
        ),
        FilledButton.icon(
          onPressed: snapshot == null ? null : _printReport,
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text('طباعة التقرير اليومي'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
          ),
        ),
        if (snapshot != null)
          Text(
            'سعر الصرف: ${_money(snapshot.exchangeRateSypPerUsd)} ل.س / USD',
            style: const TextStyle(
              color: Color(0xFF958BFF),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _buildActions() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _actionButton(
              'قبض',
              Icons.call_received_rounded,
              const Color(0xFF20B990),
              'INCOME',
            ),
            _actionButton(
              'دفع',
              Icons.call_made_rounded,
              const Color(0xFFE36E77),
              'EXPENSE',
            ),
            _actionButton(
              'إيداع',
              Icons.savings_rounded,
              const Color(0xFF4EA4F5),
              'DEPOSIT',
            ),
            _actionButton(
              'سحب من الصندوق',
              Icons.outbox_rounded,
              const Color(0xFFF0A84B),
              'WITHDRAWAL',
            ),
            _actionButton(
              'رصيد افتتاحي',
              Icons.account_balance_rounded,
              const Color(0xFF8B84FF),
              'OPENING_BALANCE',
            ),
            OutlinedButton.icon(
              onPressed: _catalog.isSaving ? null : _openTransferDialog,
              icon: const Icon(Icons.currency_exchange_rounded, size: 18),
              label: const Text('تحويل عملة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF958BFF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, String type) {
    return FilledButton.icon(
      onPressed: _catalog.isSaving ? null : () => _openTransactionDialog(type),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: .14),
        foregroundColor: color,
        elevation: 0,
      ),
    );
  }

  Widget _buildMovements(List<FinanceMovement> items) {
    if (items.isEmpty) return _buildNoData();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MovementCard(item: item),
                  ),
                )
                .toList(),
          );
        }
        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 940),
                child: DataTable(
                  headingRowHeight: 54,
                  dataRowMinHeight: 62,
                  dataRowMaxHeight: 76,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('الوقت')),
                    DataColumn(label: Text('نوع الحركة')),
                    DataColumn(label: Text('البيان')),
                    DataColumn(label: Text('التصنيف')),
                    DataColumn(label: Text('المبلغ')),
                    DataColumn(label: Text('المكافئ USD')),
                    DataColumn(label: Text('المصدر')),
                  ],
                  rows: items.map((item) {
                    final color = _typeColor(item.type);
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(DateFormat('HH:mm').format(item.occurredAt)),
                        ),
                        DataCell(_TypeBadge(type: item.type)),
                        DataCell(
                          SizedBox(
                            width: 230,
                            child: Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(item.category)),
                        DataCell(
                          Text(
                            '${_money(item.amount)} ${item.currency == 'USD' ? 'USD' : 'ل.س'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        DataCell(
                          Text('${_money(item.amountUsdEquivalent)} USD'),
                        ),
                        DataCell(_SourceBadge(isAutomatic: item.isAutomatic)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoData() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .3),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Text(
            'لا توجد حركات مالية في هذا اليوم',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          SizedBox(height: 5),
          Text(
            'سجّل أول حركة من الأزرار أعلاه أو اختر تاريخاً آخر.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'اختر تاريخ التقرير',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
    await _catalog.load(date: _dateKey, force: true);
  }

  Future<void> _reload() => _catalog.load(date: _dateKey, force: true);

  Future<void> _openTransactionDialog(String type) async {
    final draft = await showDialog<FinanceTransactionDraft>(
      context: context,
      builder: (_) =>
          _FinanceTransactionDialog(type: type, initialDate: _selectedDate),
    );
    if (draft == null || !mounted) return;
    try {
      await _catalog.createTransaction(draft);
      if (!mounted) return;
      _notice('تم تسجيل الحركة المالية بنجاح.');
    } on FinanceCatalogException catch (error) {
      if (mounted) _notice(error.message, isError: true);
    }
  }

  Future<void> _openTransferDialog() async {
    final draft = await showDialog<FinanceTransferDraft>(
      context: context,
      builder: (_) => _FinanceTransferDialog(initialDate: _selectedDate),
    );
    if (draft == null || !mounted) return;
    try {
      await _catalog.createTransfer(draft);
      if (!mounted) return;
      _notice('تم تسجيل التحويل بين العملتين بنجاح.');
    } on FinanceCatalogException catch (error) {
      if (mounted) _notice(error.message, isError: true);
    }
  }

  Future<void> _printReport() async {
    final snapshot = _catalog.snapshot;
    if (snapshot == null) return;
    try {
      await printFinanceDailyReport(snapshot);
    } catch (error) {
      if (mounted) _notice('تعذرت طباعة التقرير: $error', isError: true);
    }
  }

  void _notice(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }
}

class _FinanceMetric extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  const _FinanceMetric({
    required this.width,
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .32)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
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
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: .58),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: .42),
                    fontSize: 9,
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

class _MovementCard extends StatelessWidget {
  final FinanceMovement item;
  const _MovementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(item.type);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.description,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                _TypeBadge(type: item.type),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.category,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: .55),
                fontSize: 11,
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_money(item.amount)} ${item.currency == 'USD' ? 'USD' : 'ل.س'}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  DateFormat('yyyy/MM/dd  HH:mm').format(item.occurredAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  'مكافئ: ${_money(item.amountUsdEquivalent)} USD',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: .65),
                  ),
                ),
                const Spacer(),
                _SourceBadge(isAutomatic: item.isAutomatic),
              ],
            ),
            if (item.note.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                item.note,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _typeLabel(type),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final bool isAutomatic;
  const _SourceBadge({required this.isAutomatic});

  @override
  Widget build(BuildContext context) {
    final color = isAutomatic
        ? const Color(0xFF4EA4F5)
        : const Color(0xFF958BFF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        isAutomatic ? 'مرتبط بعملية' : 'حركة يدوية',
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FinanceTransactionDialog extends StatefulWidget {
  final String type;
  final DateTime initialDate;
  const _FinanceTransactionDialog({
    required this.type,
    required this.initialDate,
  });

  @override
  State<_FinanceTransactionDialog> createState() =>
      _FinanceTransactionDialogState();
}

class _FinanceTransactionDialogState extends State<_FinanceTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _note = TextEditingController();
  String _currency = 'SYP';
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _category.text = _defaultCategory(widget.type);
    _description.text = _defaultDescription(widget.type);
  }

  @override
  void dispose() {
    _amount.dispose();
    _category.dispose();
    _description.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIncoming = const {
      'INCOME',
      'DEPOSIT',
      'OPENING_BALANCE',
    }.contains(widget.type);
    final accent = _typeColor(widget.type);
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: accent),
            const SizedBox(width: 10),
            Expanded(child: Text(_typeLabel(widget.type))),
          ],
        ),
        content: SizedBox(
          width: 470,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'بيان الحركة',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                        ? 'أدخل بيان الحركة'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _category,
                    decoration: const InputDecoration(
                      labelText: 'التصنيف',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                        ? 'أدخل التصنيف'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          validator: (value) {
                            final amount = double.tryParse(
                              (value ?? '').trim(),
                            );
                            if (amount == null ||
                                !amount.isFinite ||
                                amount <= 0)
                              return 'أدخل مبلغاً صحيحاً';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: const InputDecoration(
                            labelText: 'العملة',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'SYP',
                              child: Text('ليرة سورية'),
                            ),
                            DropdownMenuItem(
                              value: 'USD',
                              child: Text('دولار'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _currency = value ?? 'SYP'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _dateTile(context),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isIncoming
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          color: accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isIncoming
                                ? 'سيُضاف المبلغ إلى رصيد الصندوق.'
                                : 'سيُخصم المبلغ من رصيد الصندوق.',
                            style: TextStyle(
                              fontSize: 11,
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('حفظ الحركة'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.event_outlined),
    title: const Text('تاريخ الحركة'),
    subtitle: Text(DateFormat('yyyy/MM/dd').format(_date)),
    trailing: const Icon(Icons.edit_calendar_rounded),
    onTap: () async {
      final value = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (value != null && mounted) setState(() => _date = value);
    },
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amount.text.trim());
    Navigator.pop(
      context,
      FinanceTransactionDraft(
        type: widget.type,
        currency: _currency,
        amount: amount,
        category: _category.text.trim(),
        description: _description.text.trim(),
        note: _note.text.trim(),
        occurredAt: _date,
      ),
    );
  }
}

class _FinanceTransferDialog extends StatefulWidget {
  final DateTime initialDate;
  const _FinanceTransferDialog({required this.initialDate});

  @override
  State<_FinanceTransferDialog> createState() => _FinanceTransferDialogState();
}

class _FinanceTransferDialogState extends State<_FinanceTransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fromAmount = TextEditingController();
  final _toAmount = TextEditingController();
  final _description = TextEditingController(text: 'تحويل بين الدولار والليرة');
  final _note = TextEditingController();
  String _fromCurrency = 'USD';
  String _toCurrency = 'SYP';
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _fromAmount.dispose();
    _toAmount.dispose();
    _description.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sent = double.tryParse(_fromAmount.text.trim());
    final received = double.tryParse(_toAmount.text.trim());
    final rate = sent != null && received != null && sent > 0 && received > 0
        ? (_fromCurrency == 'USD' ? received / sent : sent / received)
        : null;
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.currency_exchange_rounded, color: Color(0xFF958BFF)),
            SizedBox(width: 10),
            Text('تحويل بين العملات'),
          ],
        ),
        content: SizedBox(
          width: 470,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _fromCurrency,
                    decoration: const InputDecoration(
                      labelText: 'العملة الخارجة',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'USD', child: Text('دولار USD')),
                      DropdownMenuItem(
                        value: 'SYP',
                        child: Text('ليرة سورية SYP'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _fromCurrency = value;
                        _toCurrency = value == 'USD' ? 'SYP' : 'USD';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fromAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText:
                          'المبلغ الخارج (${_fromCurrency == 'USD' ? 'USD' : 'ل.س'})',
                      prefixIcon: const Icon(Icons.north_east_rounded),
                    ),
                    validator: (value) {
                      final amount = double.tryParse((value ?? '').trim());
                      if (amount == null || !amount.isFinite || amount <= 0)
                        return 'أدخل المبلغ الخارج';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      color: Color(0xFF958BFF),
                      size: 26,
                    ),
                  ),
                  TextFormField(
                    controller: _toAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText:
                          'المبلغ الداخل (${_toCurrency == 'USD' ? 'USD' : 'ل.س'})',
                      prefixIcon: const Icon(Icons.south_west_rounded),
                    ),
                    validator: (value) {
                      final amount = double.tryParse((value ?? '').trim());
                      if (amount == null || !amount.isFinite || amount <= 0)
                        return 'أدخل المبلغ الداخل';
                      return null;
                    },
                  ),
                  if (rate != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'سعر التحويل الفعلي: 1 USD = ${_money(rate)} ل.س',
                      style: const TextStyle(
                        color: Color(0xFF958BFF),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'بيان التحويل',
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                        ? 'أدخل بيان التحويل'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('تاريخ التحويل'),
                    subtitle: Text(DateFormat('yyyy/MM/dd').format(_date)),
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (value != null && mounted)
                        setState(() => _date = value);
                    },
                  ),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيُسجل التحويل كحركتين مرتبطتين: خروج من العملة الأولى ودخول إلى العملة الثانية، دون تغيير القيمة الإجمالية المكافئة.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('تأكيد التحويل'),
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
    Navigator.pop(
      context,
      FinanceTransferDraft(
        fromCurrency: _fromCurrency,
        toCurrency: _toCurrency,
        fromAmount: double.parse(_fromAmount.text.trim()),
        toAmount: double.parse(_toAmount.text.trim()),
        description: _description.text.trim(),
        note: _note.text.trim(),
        occurredAt: _date,
      ),
    );
  }
}

String _money(double value) => NumberFormat('#,##0.##').format(value);

Color _typeColor(String type) {
  switch (type) {
    case 'INCOME':
    case 'DEPOSIT':
    case 'OPENING_BALANCE':
    case 'TRANSFER_IN':
      return const Color(0xFF20B990);
    case 'EXPENSE':
    case 'WITHDRAWAL':
    case 'TRANSFER_OUT':
      return const Color(0xFFE36E77);
    default:
      return const Color(0xFF958BFF);
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'INCOME':
      return 'قبض';
    case 'EXPENSE':
      return 'دفع';
    case 'DEPOSIT':
      return 'إيداع';
    case 'WITHDRAWAL':
      return 'سحب';
    case 'OPENING_BALANCE':
      return 'رصيد افتتاحي';
    case 'TRANSFER_IN':
      return 'تحويل وارد';
    case 'TRANSFER_OUT':
      return 'تحويل صادر';
    default:
      return type;
  }
}

String _defaultCategory(String type) {
  switch (type) {
    case 'INCOME':
      return 'إيرادات أخرى';
    case 'EXPENSE':
      return 'مصروفات تشغيلية';
    case 'DEPOSIT':
      return 'إيداع صندوق';
    case 'WITHDRAWAL':
      return 'سحب صندوق';
    case 'OPENING_BALANCE':
      return 'رصيد افتتاحي';
    default:
      return 'حركة مالية';
  }
}

String _defaultDescription(String type) {
  switch (type) {
    case 'INCOME':
      return 'قبض نقدي';
    case 'EXPENSE':
      return 'دفع نقدي';
    case 'DEPOSIT':
      return 'إيداع في الصندوق';
    case 'WITHDRAWAL':
      return 'سحب من الصندوق';
    case 'OPENING_BALANCE':
      return 'تسجيل الرصيد الافتتاحي';
    default:
      return 'حركة مالية';
  }
}
