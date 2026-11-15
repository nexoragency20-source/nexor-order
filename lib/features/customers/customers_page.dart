import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'customer_catalog.dart';
import 'customer_models.dart';
import 'customer_statement_pdf.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _searchController = TextEditingController();
  final _tableController = ScrollController();
  final _catalog = CustomerCatalog.instance;

  @override
  void initState() {
    super.initState();
    _catalog.load(force: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableController.dispose();
    super.dispose();
  }

  List<CustomerRecord> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _catalog.customers;
    return _catalog.customers
        .where((customer) {
          return customer.name.toLowerCase().contains(query) ||
              customer.phone.toLowerCase().contains(query) ||
              customer.email.toLowerCase().contains(query) ||
              customer.address.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AnimatedBuilder(
        animation: _catalog,
        builder: (context, _) {
          final customers = _filtered;
          final isNarrow = MediaQuery.of(context).size.width < 850;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 22),
                _buildMetrics(),
                const SizedBox(height: 22),
                _buildToolbar(context),
                const SizedBox(height: 16),
                if (_catalog.isLoading && customers.isEmpty)
                  const _LoadingState()
                else if (_catalog.errorMessage != null && customers.isEmpty)
                  _LoadErrorState(
                    message: _catalog.errorMessage!,
                    onRetry: () => _catalog.load(force: true),
                  )
                else if (customers.isEmpty)
                  _EmptyCustomersState(
                    hasSearch: _searchController.text.trim().isNotEmpty,
                    onAdd: _openCustomerForm,
                  )
                else if (isNarrow)
                  ...customers.map(
                    (customer) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CustomerCard(
                        customer: customer,
                        onStatement: () => _showStatement(customer),
                        onPayment: () => _showPayment(customer),
                        onEdit: () => _openCustomerForm(customer: customer),
                        onArchive: () => _archiveCustomer(customer),
                      ),
                    ),
                  )
                else
                  _buildTable(context, customers),
                const SizedBox(height: 16),
                Text(
                  'عرض ${customers.length} من أصل ${_catalog.customerCount} عميل',
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

  Widget _buildHeader(BuildContext context) {
    return _PageHeading(
      eyebrow: 'CUSTOMER RELATIONSHIP',
      title: 'إدارة العملاء',
      subtitle: 'ملفات العملاء، الطلبات، الدفعات وكشوف الحساب من مكان واحد.',
      action: FilledButton.icon(
        onPressed: () => _openCustomerForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text('إضافة عميل'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF786BFA),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMetrics() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _MetricCard(
          title: 'إجمالي العملاء',
          value: '${_catalog.customerCount}',
          caption: 'عميل مسجل في المتجر',
          icon: Icons.groups_2_rounded,
          tone: const Color(0xFF8175FF),
        ),
        _MetricCard(
          title: 'عملاء نشطون',
          value: '${_catalog.activeCustomerCount}',
          caption: 'لديهم طلب واحد على الأقل',
          icon: Icons.verified_user_outlined,
          tone: const Color(0xFF22B990),
        ),
        _MetricCard(
          title: 'إجمالي المشتريات',
          value: _money(_catalog.totalPurchasesSyp),
          caption: 'من الطلبات غير الملغاة',
          icon: Icons.account_balance_wallet_outlined,
          tone: const Color(0xFF4EA4F5),
        ),
        _MetricCard(
          title: 'الرصيد المستحق',
          value: _money(_catalog.totalReceivablesSyp),
          caption: 'المبالغ المتبقية على العملاء',
          icon: Icons.pending_actions_rounded,
          tone: const Color(0xFFF0A84B),
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
          width: 360,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'ابحث بالاسم أو الهاتف أو البريد أو العنوان...',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(_searchController.clear),
          icon: const Icon(Icons.restart_alt_rounded, size: 17),
          label: const Text('إعادة ضبط'),
        ),
        OutlinedButton.icon(
          onPressed: _catalog.isLoading
              ? null
              : () => _catalog.load(force: true),
          icon: _catalog.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('تحديث'),
        ),
        if (_catalog.errorMessage != null)
          Text(
            _catalog.errorMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }

  Widget _buildTable(BuildContext context, List<CustomerRecord> customers) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: .32)),
      ),
      child: Scrollbar(
        controller: _tableController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _tableController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1220),
            child: DataTable(
              headingRowHeight: 58,
              dataRowMinHeight: 68,
              dataRowMaxHeight: 78,
              columnSpacing: 25,
              horizontalMargin: 20,
              columns: const [
                DataColumn(label: Text('العميل')),
                DataColumn(label: Text('رقم الهاتف')),
                DataColumn(label: Text('المدينة / العنوان')),
                DataColumn(label: Text('الطلبات')),
                DataColumn(label: Text('إجمالي المشتريات')),
                DataColumn(label: Text('الرصيد')),
                DataColumn(label: Text('آخر طلب')),
                DataColumn(label: Text('الإجراءات')),
              ],
              rows: customers.map((customer) {
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 175,
                        child: Row(
                          children: [
                            const _CustomerAvatar(size: 35),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (customer.email.isNotEmpty)
                                    Text(
                                      customer.email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: .48),
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () => _showStatement(customer),
                    ),
                    DataCell(
                      Text(customer.phone.isEmpty ? '—' : customer.phone),
                    ),
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Text(
                          customer.address.isEmpty ? '—' : customer.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text('${customer.orderCount}')),
                    DataCell(
                      Text(
                        _money(customer.totalPurchasesSyp),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(_BalanceText(balance: customer.balanceSyp)),
                    DataCell(Text(_dateText(customer.lastOrderAt))),
                    DataCell(
                      _CustomerActions(
                        onStatement: () => _showStatement(customer),
                        onPayment: () => _showPayment(customer),
                        onEdit: () => _openCustomerForm(customer: customer),
                        onArchive: () => _archiveCustomer(customer),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCustomerForm({CustomerRecord? customer}) async {
    final draft = await showDialog<CustomerFormDraft>(
      context: context,
      builder: (_) => CustomerFormDialog(customer: customer),
    );
    if (draft == null || !mounted) return;

    final savedDraft = CustomerRecord(
      id: customer?.id ?? '',
      name: draft.name,
      phone: draft.phone,
      email: draft.email,
      address: draft.address,
      notes: draft.notes,
      isActive: true,
      createdAt: customer?.createdAt ?? DateTime.now(),
      orderCount: customer?.orderCount ?? 0,
      totalPurchasesUsd: customer?.totalPurchasesUsd ?? 0,
      totalPurchasesSyp: customer?.totalPurchasesSyp ?? 0,
      paidUsd: customer?.paidUsd ?? 0,
      paidSyp: customer?.paidSyp ?? 0,
      balanceUsd: customer?.balanceUsd ?? 0,
      balanceSyp: customer?.balanceSyp ?? 0,
      lastOrderAt: customer?.lastOrderAt,
    );
    try {
      if (customer == null) {
        await _catalog.create(savedDraft);
      } else {
        await _catalog.update(savedDraft);
      }
      if (!mounted) return;
      _notice(
        customer == null
            ? 'تمت إضافة العميل وحفظه في Neon.'
            : 'تم تحديث بيانات العميل.',
      );
    } catch (error) {
      if (!mounted) return;
      _notice(error.toString(), isError: true);
    }
  }

  Future<void> _archiveCustomer(CustomerRecord customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('أرشفة العميل'),
          content: Text(
            'سيختفي ${customer.name} من قائمة العملاء النشطين، مع الاحتفاظ بطلباته ودفعاته وكشف حسابه. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE05260),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('أرشفة العميل'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _catalog.archive(customer.id);
      if (mounted) _notice('تمت أرشفة العميل مع الاحتفاظ بسجلاته.');
    } catch (error) {
      if (mounted) _notice(error.toString(), isError: true);
    }
  }

  Future<void> _showStatement(CustomerRecord customer) async {
    CustomerStatement statement;
    try {
      statement = await _catalog.loadStatement(customer.id);
    } catch (error) {
      if (mounted) _notice(error.toString(), isError: true);
      return;
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Dialog(
              insetPadding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1050,
                  maxHeight: 820,
                ),
                child: Column(
                  children: [
                    _StatementHeader(
                      statement: statement,
                      onClose: () => Navigator.pop(dialogContext),
                      onPrint: () async {
                        try {
                          await printCustomerStatement(statement);
                        } catch (error) {
                          if (mounted)
                            _notice(
                              'تعذرت طباعة كشف الحساب: $error',
                              isError: true,
                            );
                        }
                      },
                      onPayment: () async {
                        final draft = await showDialog<CustomerPaymentDraft>(
                          context: dialogContext,
                          builder: (_) =>
                              CustomerPaymentDialog(statement: statement),
                        );
                        if (draft == null) return;
                        try {
                          await _catalog.recordPayment(
                            statement.customer.id,
                            draft,
                          );
                          final refreshed = await _catalog.loadStatement(
                            statement.customer.id,
                          );
                          setDialogState(() => statement = refreshed);
                          if (mounted) setState(() {});
                          if (mounted)
                            _notice('تم تسجيل الدفعة وتحديث كشف الحساب.');
                        } catch (error) {
                          if (mounted) _notice(error.toString(), isError: true);
                        }
                      },
                    ),
                    Expanded(child: _StatementBody(statement: statement)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPayment(CustomerRecord customer) async {
    CustomerStatement statement;
    try {
      statement = await _catalog.loadStatement(customer.id);
    } catch (error) {
      if (mounted) _notice(error.toString(), isError: true);
      return;
    }
    if (!mounted) return;
    final draft = await showDialog<CustomerPaymentDraft>(
      context: context,
      builder: (_) => CustomerPaymentDialog(statement: statement),
    );
    if (draft == null || !mounted) return;
    try {
      await _catalog.recordPayment(customer.id, draft);
      if (!mounted) return;
      _notice('تم تسجيل الدفعة بنجاح.');
    } catch (error) {
      if (mounted) _notice(error.toString(), isError: true);
    }
  }

  void _notice(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFB83D4B) : null,
      ),
    );
  }
}

class CustomerFormDraft {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String notes;
  const CustomerFormDraft({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.notes,
  });
}

class CustomerFormDialog extends StatefulWidget {
  final CustomerRecord? customer;
  const CustomerFormDialog({super.key, this.customer});

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    _phone = TextEditingController(text: customer?.phone ?? '');
    _email = TextEditingController(text: customer?.email ?? '');
    _address = TextEditingController(text: customer?.address ?? '');
    _notes = TextEditingController(text: customer?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _CustomerAvatar(size: 44),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customer == null
                                  ? 'إضافة عميل جديد'
                                  : 'تعديل بيانات العميل',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'سيتم حفظ البيانات على قاعدة Neon.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _formField(
                    _name,
                    'اسم العميل',
                    Icons.person_outline_rounded,
                    requiredField: true,
                  ),
                  const SizedBox(height: 13),
                  _formField(
                    _phone,
                    'رقم الهاتف',
                    Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 13),
                  _formField(
                    _email,
                    'البريد الإلكتروني',
                    Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 13),
                  _formField(
                    _address,
                    'المدينة / عنوان العميل',
                    Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 13),
                  _formField(
                    _notes,
                    'ملاحظات إضافية',
                    Icons.notes_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
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
                          onPressed: _save,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('حفظ البيانات'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF786BFA),
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

  Widget _formField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool requiredField = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (requiredField && (value == null || value.trim().length < 2)) {
          return 'أدخل اسماً صحيحاً من حرفين على الأقل.';
        }
        return null;
      },
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CustomerFormDraft(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }
}

class CustomerPaymentDialog extends StatefulWidget {
  final CustomerStatement statement;
  const CustomerPaymentDialog({super.key, required this.statement});

  @override
  State<CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<CustomerPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _currency = 'SYP';
  String _method = 'CASH';
  String? _orderId;
  late DateTime _paidAt;

  @override
  void initState() {
    super.initState();
    _paidAt = DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.statement.customer;
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تسجيل دفعة من ${customer.name}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    customer.balanceSyp >= 0
                        ? 'الرصيد المستحق: ${_money(customer.balanceSyp)}'
                        : 'رصيد دائن للعميل: ${_money(customer.balanceSyp.abs())}',
                    style: const TextStyle(
                      color: Color(0xFF958BFF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String?>(
                    initialValue: _orderId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'ربط الدفعة بطلب (اختياري)',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('دفعة عامة على حساب العميل'),
                      ),
                      ...widget.statement.orders
                          .where((order) => order.remainingUsd > 0.000001)
                          .map(
                            (order) => DropdownMenuItem<String?>(
                              value: order.id,
                              child: Text(
                                '${order.orderNumber} — متبقي ${_money(order.remainingSyp)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (value) => setState(() => _orderId = value),
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
                            labelText: 'مبلغ الدفعة',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          validator: (value) {
                            final number = double.tryParse(
                              (value ?? '').replaceAll(',', '.'),
                            );
                            if (number == null ||
                                !number.isFinite ||
                                number <= 0)
                              return 'أدخل مبلغاً صحيحاً.';
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
                            DropdownMenuItem(value: 'SYP', child: Text('ليرة')),
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
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    decoration: const InputDecoration(
                      labelText: 'طريقة الدفع',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('نقدي')),
                      DropdownMenuItem(
                        value: 'BANK_TRANSFER',
                        child: Text('تحويل بنكي'),
                      ),
                      DropdownMenuItem(value: 'CARD', child: Text('بطاقة')),
                      DropdownMenuItem(value: 'OTHER', child: Text('أخرى')),
                    ],
                    onChanged: (value) =>
                        setState(() => _method = value ?? 'CASH'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('تاريخ الدفعة'),
                    subtitle: Text(DateFormat('yyyy/MM/dd').format(_paidAt)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _pickDate,
                  ),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      prefixIcon: Icon(Icons.notes_rounded),
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
                          onPressed: _save,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('تسجيل الدفعة'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF786BFA),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) =>
          Directionality(textDirection: ui.TextDirection.rtl, child: child!),
    );
    if (selected != null) setState(() => _paidAt = selected);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amount.text.trim().replaceAll(',', '.'));
    Navigator.pop(
      context,
      CustomerPaymentDraft(
        amount: amount,
        currency: _currency,
        method: _method,
        orderId: _orderId,
        paidAt: _paidAt,
        note: _note.text.trim(),
      ),
    );
  }
}

class _StatementHeader extends StatelessWidget {
  final CustomerStatement statement;
  final VoidCallback onClose;
  final VoidCallback onPayment;
  final VoidCallback onPrint;
  const _StatementHeader({
    required this.statement,
    required this.onClose,
    required this.onPayment,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final identity = Row(
        children: [
          const _CustomerAvatar(size: 44),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'كشف حساب العميل',
                  style: TextStyle(
                    color: Color(0xFFAAA1FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statement.customer.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  statement.customer.phone,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
      final actions = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onPrint,
            icon: const Icon(
              Icons.print_outlined,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              'طباعة الكشف',
              style: TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: .28)),
            ),
          ),
          FilledButton.icon(
            onPressed: onPayment,
            icon: const Icon(Icons.add_card_rounded, size: 18),
            label: const Text('تسجيل دفعة'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF786BFA),
            ),
          ),
        ],
      );
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF211D3A), Color(0xFF171923)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: identity),
                      IconButton(
                        onPressed: onClose,
                        tooltip: 'إغلاق',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  actions,
                ],
              )
            : Row(
                children: [
                  Expanded(child: identity),
                  actions,
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'إغلاق',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

class _StatementBody extends StatelessWidget {
  final CustomerStatement statement;
  const _StatementBody({required this.statement});

  @override
  Widget build(BuildContext context) {
    final customer = statement.customer;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatementMetric(
                title: 'عدد الطلبات',
                value: '${customer.orderCount}',
                icon: Icons.receipt_long_outlined,
                tone: const Color(0xFF8B82FF),
              ),
              _StatementMetric(
                title: 'إجمالي المشتريات',
                value: _money(customer.totalPurchasesSyp),
                icon: Icons.shopping_bag_outlined,
                tone: const Color(0xFF4EA4F5),
              ),
              _StatementMetric(
                title: 'إجمالي المدفوع',
                value: _money(customer.paidSyp),
                icon: Icons.payments_outlined,
                tone: const Color(0xFF22B990),
              ),
              _StatementMetric(
                title: customer.balanceSyp >= 0
                    ? 'المتبقي على العميل'
                    : 'رصيد دائن للعميل',
                value: _money(customer.balanceSyp.abs()),
                icon: Icons.account_balance_wallet_outlined,
                tone: customer.balanceSyp > 0
                    ? const Color(0xFFF0A84B)
                    : const Color(0xFF22B990),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'الحركة المالية',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'سعر الصرف: ${NumberFormat('#,##0.##').format(statement.exchangeRateSypPerUsd)} ل.س / USD',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (statement.movements.isEmpty)
            const _StatementEmpty()
          else
            Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 870),
                  child: DataTable(
                    headingRowHeight: 48,
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 66,
                    columns: const [
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('البيان')),
                      DataColumn(label: Text('المرجع')),
                      DataColumn(label: Text('مدين')),
                      DataColumn(label: Text('دائن')),
                      DataColumn(label: Text('الرصيد بعد الحركة')),
                    ],
                    rows: statement.movements
                        .map(
                          (movement) => DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  DateFormat(
                                    'yyyy/MM/dd',
                                  ).format(movement.date),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      movement.type == 'ORDER'
                                          ? Icons.receipt_long_outlined
                                          : movement.type == 'RETURN'
                                          ? Icons.assignment_return_outlined
                                          : movement.type == 'REFUND'
                                          ? Icons.money_off
                                          : Icons.payments_outlined,
                                      size: 17,
                                      color: movement.type == 'ORDER'
                                          ? const Color(0xFF8B82FF)
                                          : movement.type == 'REFUND'
                                          ? const Color(0xFFD85B67)
                                          : const Color(0xFF22B990),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(movement.title),
                                  ],
                                ),
                              ),
                              DataCell(Text(movement.reference)),
                              DataCell(
                                Text(
                                  movement.debitSyp > 0
                                      ? _money(movement.debitSyp)
                                      : '—',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  movement.creditSyp > 0
                                      ? _money(movement.creditSyp)
                                      : '—',
                                  style: const TextStyle(
                                    color: Color(0xFF22B990),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(
                                _BalanceText(balance: movement.balanceAfterSyp),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          if (statement.orders.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'طلبات العميل',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...statement.orders.map(
              (order) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: .25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_outlined,
                      color: Color(0xFF8B82FF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            DateFormat('yyyy/MM/dd').format(order.createdAt),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'الصافي ${_money(order.netTotalSyp)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
                    const SizedBox(width: 18),
                    Text(
                      order.remainingSyp.abs() < 0.01
                          ? 'مسدد'
                          : 'متبقي ${_money(order.remainingSyp)}',
                      style: TextStyle(
                        color: order.remainingSyp.abs() < 0.01
                            ? const Color(0xFF22B990)
                            : const Color(0xFFF0A84B),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (customer.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'ملاحظات العميل',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(customer.notes, style: const TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

class _StatementMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color tone;
  const _StatementMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 205,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .3),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: tone, size: 19),
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
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CustomerCard extends StatelessWidget {
  final CustomerRecord customer;
  final VoidCallback onStatement;
  final VoidCallback onPayment;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  const _CustomerCard({
    required this.customer,
    required this.onStatement,
    required this.onPayment,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: BorderSide(
        color: Theme.of(context).dividerColor.withValues(alpha: .3),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CustomerAvatar(size: 42),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      customer.phone.isEmpty
                          ? 'لا يوجد رقم هاتف'
                          : customer.phone,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onArchive,
                tooltip: 'أرشفة',
                icon: const Icon(
                  Icons.archive_outlined,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          _MobileInfoLine(
            label: 'العنوان',
            value: customer.address.isEmpty ? '—' : customer.address,
          ),
          _MobileInfoLine(
            label: 'عدد الطلبات',
            value: '${customer.orderCount}',
          ),
          _MobileInfoLine(
            label: 'المشتريات',
            value: _money(customer.totalPurchasesSyp),
          ),
          _MobileInfoLine(
            label: customer.balanceSyp >= 0 ? 'الرصيد المستحق' : 'رصيد دائن',
            value: _money(customer.balanceSyp.abs()),
            valueColor: customer.balanceSyp > 0
                ? const Color(0xFFF0A84B)
                : const Color(0xFF22B990),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStatement,
                  icon: const Icon(Icons.receipt_long_outlined, size: 17),
                  label: const Text('كشف الحساب'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPayment,
                  icon: const Icon(Icons.add_card_rounded, size: 17),
                  label: const Text('تسجيل دفعة'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF786BFA),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MobileInfoLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _MobileInfoLine({
    required this.label,
    required this.value,
    this.valueColor,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: valueColor,
          ),
        ),
      ],
    ),
  );
}

class _CustomerActions extends StatelessWidget {
  final VoidCallback onStatement;
  final VoidCallback onPayment;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  const _CustomerActions({
    required this.onStatement,
    required this.onPayment,
    required this.onEdit,
    required this.onArchive,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'كشف الحساب',
        onPressed: onStatement,
        icon: const Icon(
          Icons.receipt_long_outlined,
          size: 18,
          color: Color(0xFF8B82FF),
        ),
      ),
      IconButton(
        tooltip: 'تسجيل دفعة',
        onPressed: onPayment,
        icon: const Icon(
          Icons.add_card_rounded,
          size: 18,
          color: Color(0xFF22B990),
        ),
      ),
      IconButton(
        tooltip: 'تعديل',
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined, size: 18),
      ),
      IconButton(
        tooltip: 'أرشفة',
        onPressed: onArchive,
        icon: const Icon(
          Icons.archive_outlined,
          size: 18,
          color: Colors.redAccent,
        ),
      ),
    ],
  );
}

class _BalanceText extends StatelessWidget {
  final double balance;
  const _BalanceText({required this.balance});
  @override
  Widget build(BuildContext context) {
    final isCredit = balance < -0.01;
    final isSettled = balance.abs() <= .01;
    return Text(
      isSettled
          ? 'مسدد'
          : '${isCredit ? 'دائن' : 'عليه'} ${_money(balance.abs())}',
      style: TextStyle(
        fontWeight: FontWeight.w800,
        color: isSettled || isCredit
            ? const Color(0xFF22B990)
            : const Color(0xFFF0A84B),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final double size;
  const _CustomerAvatar({this.size = 38});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF8175FF), Color(0xFF5146B6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * .34),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF786BFA).withValues(alpha: .2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Icon(Icons.person_rounded, color: Colors.white, size: size * .58),
  );
}

class _PageHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 720;
      final heading = Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8175FF).withValues(alpha: .17),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.groups_2_rounded, color: Color(0xFFA69EFF)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: Color(0xFFAAA1FF),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .58),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF211D3A), Color(0xFF171923)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: const Color(0xFF8175FF).withValues(alpha: .28),
          ),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              )
            : Row(
                children: [
                  Expanded(child: heading),
                  if (action != null) ...[const SizedBox(width: 12), action!],
                ],
              ),
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color tone;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 230,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .32),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: tone),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .57),
                  fontSize: 11,
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
              const SizedBox(height: 3),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .42),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 90),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _LoadErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context).colorScheme.error.withValues(alpha: .3),
      ),
    ),
    child: Column(
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 42,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      ],
    ),
  );
}

class _EmptyCustomersState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onAdd;
  const _EmptyCustomersState({required this.hasSearch, required this.onAdd});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .3),
      ),
    ),
    child: Column(
      children: [
        const Icon(Icons.groups_2_outlined, size: 52, color: Color(0xFF8175FF)),
        const SizedBox(height: 13),
        Text(
          hasSearch ? 'لا يوجد عملاء مطابقون للبحث' : 'لم تتم إضافة عملاء بعد',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 7),
        Text(
          hasSearch
              ? 'جرّب اسماً أو رقماً مختلفاً.'
              : 'أضف أول عميل وابدأ بتسجيل طلباته ودفعاته.',
          style: const TextStyle(color: Colors.grey),
        ),
        if (!hasSearch) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('إضافة أول عميل'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF786BFA),
            ),
          ),
        ],
      ],
    ),
  );
}

class _StatementEmpty extends StatelessWidget {
  const _StatementEmpty();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Column(
      children: [
        Icon(Icons.receipt_long_outlined, size: 38, color: Colors.grey),
        SizedBox(height: 8),
        Text(
          'لا توجد حركات مالية لهذا العميل بعد',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );
}

String _money(double value) => '${NumberFormat('#,##0.##').format(value)} ل.س';

String _dateText(DateTime? value) =>
    value == null ? '—' : DateFormat('yyyy/MM/dd').format(value);
