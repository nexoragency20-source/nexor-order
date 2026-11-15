class SupplierModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String note;
  final DateTime createdAt;
  final bool isActive;

  const SupplierModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.note = '',
    required this.createdAt,
    this.isActive = true,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: _asString(json['id']),
      name: _asString(json['name']),
      phone: _asString(json['phone']),
      email: _asString(json['email']),
      address: _asString(json['address']),
      note: _asString(json['note'] ?? json['notes']),
      createdAt: _asDate(json['createdAt']),
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toApiJson() => {
    'name': name.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'address': address.trim(),
    'notes': note.trim(),
  };

  SupplierModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? note,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class PurchaseItemModel {
  final String productId;
  final String productName;
  final String barcode;
  final int quantity;
  final double unitPriceUsd;
  final double unitPriceSyp;

  const PurchaseItemModel({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.unitPriceUsd,
    required this.unitPriceSyp,
  });

  factory PurchaseItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseItemModel(
      productId: _asString(json['productId']),
      productName: _asString(json['productName']),
      barcode: _asString(json['barcode']),
      quantity: _asDouble(json['quantity']).round(),
      unitPriceUsd: _asDouble(json['unitPriceUsd'] ?? json['unitCostUsd']),
      unitPriceSyp: _asDouble(json['unitPriceSyp'] ?? json['unitCostSyp']),
    );
  }

  Map<String, dynamic> toApiJson() => {
    'productId': productId,
    'quantity': quantity,
    'unitCostUsd': unitPriceUsd,
    'unitCostSyp': unitPriceSyp,
  };

  double get totalUsd => quantity * unitPriceUsd;
  double get totalSyp => quantity * unitPriceSyp;
}

class PurchaseModel {
  final String id;
  final String invoiceNumber;
  final String supplierId;
  final String supplierNameSnapshot;
  final List<PurchaseItemModel> items;
  final double exchangeRateSypPerUsd;
  final DateTime createdAt;
  final String note;
  final double? totalUsdSnapshot;
  final double? totalSypSnapshot;
  final double paidUsdSnapshot;
  final String status;

  const PurchaseModel({
    required this.id,
    required this.invoiceNumber,
    required this.supplierId,
    required this.supplierNameSnapshot,
    required this.items,
    required this.exchangeRateSypPerUsd,
    required this.createdAt,
    this.note = '',
    this.totalUsdSnapshot,
    this.totalSypSnapshot,
    this.paidUsdSnapshot = 0,
    this.status = 'RECEIVED',
  });

  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return PurchaseModel(
      id: _asString(json['id']),
      invoiceNumber: _asString(json['invoiceNumber']),
      supplierId: _asString(json['supplierId']),
      supplierNameSnapshot: _asString(
        json['supplierNameSnapshot'] ?? json['supplierName'],
      ),
      items: rawItems is List
          ? rawItems
                .map((item) => PurchaseItemModel.fromJson(_asMap(item)))
                .toList(growable: false)
          : const [],
      exchangeRateSypPerUsd: _asDouble(json['exchangeRateSypPerUsd']),
      createdAt: _asDate(json['createdAt'] ?? json['purchasedAt']),
      note: _asString(json['note'] ?? json['notes']),
      totalUsdSnapshot: json['totalUsd'] == null
          ? null
          : _asDouble(json['totalUsd']),
      totalSypSnapshot: json['totalSyp'] == null
          ? null
          : _asDouble(json['totalSyp']),
      paidUsdSnapshot: _asDouble(json['paidUsd']),
      status: _asString(json['status'], fallback: 'RECEIVED'),
    );
  }

  double get totalUsd =>
      totalUsdSnapshot ?? items.fold(0, (sum, item) => sum + item.totalUsd);
  double get totalSyp =>
      totalSypSnapshot ?? items.fold(0, (sum, item) => sum + item.totalSyp);
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}

class SupplierPaymentModel {
  final String id;
  final String supplierId;
  final String? purchaseId;
  final String supplierNameSnapshot;
  final String? purchaseInvoiceNumber;
  final double amount;
  final String currencyCode;
  final double exchangeRateSypPerUsd;
  final DateTime createdAt;
  final String note;
  final double? usdEquivalentSnapshot;
  final double? sypEquivalentSnapshot;

  const SupplierPaymentModel({
    required this.id,
    required this.supplierId,
    this.purchaseId,
    this.supplierNameSnapshot = '',
    this.purchaseInvoiceNumber,
    required this.amount,
    required this.currencyCode,
    required this.exchangeRateSypPerUsd,
    required this.createdAt,
    this.note = '',
    this.usdEquivalentSnapshot,
    this.sypEquivalentSnapshot,
  });

  factory SupplierPaymentModel.fromJson(Map<String, dynamic> json) {
    return SupplierPaymentModel(
      id: _asString(json['id']),
      supplierId: _asString(json['supplierId']),
      purchaseId: json['purchaseId']?.toString(),
      supplierNameSnapshot: _asString(json['supplierNameSnapshot']),
      purchaseInvoiceNumber: json['purchaseInvoiceNumber']?.toString(),
      amount: _asDouble(json['amount']),
      currencyCode: _asString(
        json['currencyCode'] ?? json['currency'],
        fallback: 'USD',
      ),
      exchangeRateSypPerUsd: _asDouble(
        json['exchangeRateSypPerUsd'],
        fallback: 1,
      ),
      createdAt: _asDate(json['createdAt'] ?? json['paidAt']),
      note: _asString(json['note']),
      usdEquivalentSnapshot: json['amountUsdEquivalent'] == null
          ? null
          : _asDouble(json['amountUsdEquivalent']),
      sypEquivalentSnapshot: json['amountSypEquivalent'] == null
          ? null
          : _asDouble(json['amountSypEquivalent']),
    );
  }

  double get amountUsdEquivalent =>
      usdEquivalentSnapshot ??
      (currencyCode == 'USD' ? amount : amount / exchangeRateSypPerUsd);

  double get amountSypEquivalent =>
      sypEquivalentSnapshot ??
      (currencyCode == 'SYP' ? amount : amount * exchangeRateSypPerUsd);
}

String _asString(dynamic value, {String fallback = ''}) =>
    value == null ? fallback : value.toString();

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime _asDate(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return <String, dynamic>{};
}
