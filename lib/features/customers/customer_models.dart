class CustomerRecord {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final int orderCount;
  final double totalPurchasesUsd;
  final double totalPurchasesSyp;
  final double paidUsd;
  final double paidSyp;
  final double balanceUsd;
  final double balanceSyp;
  final DateTime? lastOrderAt;

  const CustomerRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.notes,
    required this.isActive,
    required this.createdAt,
    required this.orderCount,
    required this.totalPurchasesUsd,
    required this.totalPurchasesSyp,
    required this.paidUsd,
    required this.paidSyp,
    required this.balanceUsd,
    required this.balanceSyp,
    required this.lastOrderAt,
  });

  factory CustomerRecord.fromJson(Map<String, dynamic> json) {
    return CustomerRecord(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      email: '${json['email'] ?? ''}',
      address: '${json['address'] ?? ''}',
      notes: '${json['notes'] ?? ''}',
      isActive: json['isActive'] != false,
      createdAt: _date(json['createdAt']),
      orderCount: _int(json['orderCount']),
      totalPurchasesUsd: _double(json['totalPurchasesUsd']),
      totalPurchasesSyp: _double(json['totalPurchasesSyp']),
      paidUsd: _double(json['paidUsd']),
      paidSyp: _double(json['paidSyp']),
      balanceUsd: _double(json['balanceUsd']),
      balanceSyp: _double(json['balanceSyp']),
      lastOrderAt: json['lastOrderAt'] == null
          ? null
          : _date(json['lastOrderAt']),
    );
  }

  Map<String, dynamic> toApiJson() => {
    'name': name.trim(),
    'phone': _nullable(phone),
    'email': _nullable(email),
    'address': _nullable(address),
    'notes': _nullable(notes),
  };
}

class CustomerOrderSummary {
  final String id;
  final String orderNumber;
  final String status;
  final DateTime createdAt;
  final double totalUsd;
  final double totalSyp;
  final double returnedUsd;
  final double returnedSyp;
  final double netTotalUsd;
  final double netTotalSyp;
  final double paidUsd;
  final double paidSyp;
  final double remainingUsd;
  final double remainingSyp;

  const CustomerOrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.totalUsd,
    required this.totalSyp,
    this.returnedUsd = 0,
    this.returnedSyp = 0,
    this.netTotalUsd = 0,
    this.netTotalSyp = 0,
    required this.paidUsd,
    required this.paidSyp,
    required this.remainingUsd,
    required this.remainingSyp,
  });

  factory CustomerOrderSummary.fromJson(Map<String, dynamic> json) =>
      CustomerOrderSummary(
        id: '${json['id'] ?? ''}',
        orderNumber: '${json['orderNumber'] ?? ''}',
        status: '${json['status'] ?? ''}',
        createdAt: _date(json['createdAt']),
        totalUsd: _double(json['totalUsd']),
        totalSyp: _double(json['totalSyp']),
        returnedUsd: _double(json['returnedUsd']),
        returnedSyp: _double(json['returnedSyp']),
        netTotalUsd: _double(
          json['netTotalUsd'],
          fallback: _double(json['totalUsd']) - _double(json['returnedUsd']),
        ),
        netTotalSyp: _double(
          json['netTotalSyp'],
          fallback: _double(json['totalSyp']) - _double(json['returnedSyp']),
        ),
        paidUsd: _double(json['paidUsd']),
        paidSyp: _double(json['paidSyp']),
        remainingUsd: _double(json['remainingUsd']),
        remainingSyp: _double(json['remainingSyp']),
      );
}

class CustomerMovement {
  final String id;
  final String type;
  final String title;
  final String reference;
  final DateTime date;
  final double debitSyp;
  final double creditSyp;
  final double balanceAfterSyp;
  final String note;
  final String? currency;
  final double? amount;
  final String? method;

  const CustomerMovement({
    required this.id,
    required this.type,
    required this.title,
    required this.reference,
    required this.date,
    required this.debitSyp,
    required this.creditSyp,
    required this.balanceAfterSyp,
    required this.note,
    this.currency,
    this.amount,
    this.method,
  });

  factory CustomerMovement.fromJson(Map<String, dynamic> json) =>
      CustomerMovement(
        id: '${json['id'] ?? ''}',
        type: '${json['type'] ?? ''}',
        title: '${json['title'] ?? ''}',
        reference: '${json['reference'] ?? ''}',
        date: _date(json['date']),
        debitSyp: _double(json['debitSyp']),
        creditSyp: _double(json['creditSyp']),
        balanceAfterSyp: _double(json['balanceAfterSyp']),
        note: '${json['note'] ?? ''}',
        currency: json['currency']?.toString(),
        amount: json['amount'] == null ? null : _double(json['amount']),
        method: json['method']?.toString(),
      );
}

class CustomerStatement {
  final CustomerRecord customer;
  final double exchangeRateSypPerUsd;
  final List<CustomerOrderSummary> orders;
  final List<CustomerMovement> movements;

  const CustomerStatement({
    required this.customer,
    required this.exchangeRateSypPerUsd,
    required this.orders,
    required this.movements,
  });

  factory CustomerStatement.fromJson(Map<String, dynamic> json) {
    final rawOrders = json['orders'] is List
        ? json['orders'] as List
        : const [];
    final rawMovements = json['movements'] is List
        ? json['movements'] as List
        : const [];
    return CustomerStatement(
      customer: CustomerRecord.fromJson(_map(json['customer'])),
      exchangeRateSypPerUsd: _double(json['exchangeRateSypPerUsd']),
      orders: rawOrders
          .whereType<Map>()
          .map((item) => CustomerOrderSummary.fromJson(_map(item)))
          .toList(growable: false),
      movements: rawMovements
          .whereType<Map>()
          .map((item) => CustomerMovement.fromJson(_map(item)))
          .toList(growable: false),
    );
  }
}

class CustomerPaymentDraft {
  final double amount;
  final String currency;
  final String method;
  final String? orderId;
  final DateTime paidAt;
  final String note;

  const CustomerPaymentDraft({
    required this.amount,
    required this.currency,
    required this.method,
    required this.orderId,
    required this.paidAt,
    required this.note,
  });

  Map<String, dynamic> toApiJson() => {
    'amount': amount,
    'currency': currency,
    'method': method,
    if (orderId != null) 'orderId': orderId,
    'paidAt': paidAt.toIso8601String(),
    'note': note.trim(),
  };
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return <String, dynamic>{};
}

double _double(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();

String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
