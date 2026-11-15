enum OrderStatus { pending, processing, shipped, completed, cancelled }

enum PaymentMethod { cash, card, transfer, cashOnDelivery, other }

enum PaymentStatus { unpaid, partiallyPaid, paid }

enum PaymentCurrency { usd, syp }

class OrderCustomer {
  final String id;
  final String name;
  final String phone;
  final String address;

  const OrderCustomer({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
  });

  factory OrderCustomer.fromJson(Map<String, dynamic> json) => OrderCustomer(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    phone: '${json['phone'] ?? ''}',
    address: '${json['address'] ?? ''}',
  );
}

class OrderItem {
  final String? productId;
  final String productName;
  final String barcode;
  final int quantity;

  /// Unit selling price in the store's display currency (SYP).
  final double unitPrice;
  final double unitPriceUsd;
  final double unitCostUsd;

  const OrderItem({
    this.productId,
    required this.productName,
    this.barcode = '',
    required this.quantity,
    required this.unitPrice,
    double? unitPriceUsd,
    this.unitCostUsd = 0,
  }) : unitPriceUsd = unitPriceUsd ?? 0;

  double get total => quantity * unitPrice;
  double get totalUsd => quantity * unitPriceUsd;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    productId: _nullableString(json['productId']).isEmpty
        ? null
        : _nullableString(json['productId']),
    productName: '${json['productName'] ?? ''}',
    barcode: '${json['barcode'] ?? ''}',
    quantity: _asDouble(json['quantity']).round(),
    unitPrice: _asDouble(json['unitPrice'] ?? json['unitPriceSyp']),
    unitPriceUsd: _asDouble(json['unitPriceUsd']),
    unitCostUsd: _asDouble(json['unitCostUsd']),
  );

  Map<String, dynamic> toApiJson(double exchangeRate) => {
    'productId': productId,
    'productName': productName,
    'barcode': barcode,
    'quantity': quantity,
    'unitPriceUsd': unitPriceUsd > 0
        ? unitPriceUsd
        : (exchangeRate > 0 ? unitPrice / exchangeRate : 0),
  };
}

class OrderPayment {
  final String id;
  final double amount;
  final PaymentCurrency currency;
  final double amountUsdEquivalent;
  final double amountSypEquivalent;
  final PaymentMethod method;
  final String note;
  final DateTime paidAt;

  const OrderPayment({
    required this.id,
    required this.amount,
    required this.currency,
    required this.amountUsdEquivalent,
    required this.amountSypEquivalent,
    required this.method,
    required this.note,
    required this.paidAt,
  });

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
    id: '${json['id'] ?? ''}',
    amount: _asDouble(json['amount']),
    currency: _currencyFromApi(json['currency']),
    amountUsdEquivalent: _asDouble(json['amountUsdEquivalent']),
    amountSypEquivalent: _asDouble(json['amountSypEquivalent']),
    method: _paymentMethodFromApi(json['method']),
    note: '${json['note'] ?? ''}',
    paidAt: DateTime.tryParse('${json['paidAt'] ?? ''}') ?? DateTime.now(),
  );
}

class OrderModel {
  /// UUID used for API operations. Kept separate from the human order number.
  final String recordId;
  final String id;
  final String? customerId;
  final String customerName;
  final String phone;
  final String address;
  final List<OrderItem> items;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final String note;
  final double exchangeRateSypPerUsd;
  final double subtotalUsd;
  final double discountUsd;
  final double shippingUsd;
  final double totalUsd;
  final double totalAmountSyp;
  final double returnedUsd;
  final double returnedSyp;
  final double paidUsd;
  final double paidAmountSyp;
  final double remainingUsd;
  final double remainingSyp;
  final List<OrderPayment> payments;
  final bool hasPersistedTotals;

  /// Used only while creating a new order. The server creates the payment row.
  final double initialPaymentAmount;
  final PaymentCurrency initialPaymentCurrency;

  const OrderModel({
    this.recordId = '',
    required this.id,
    this.customerId,
    required this.customerName,
    this.phone = '',
    this.address = '',
    required this.items,
    required this.status,
    required this.paymentMethod,
    this.paymentStatus = PaymentStatus.unpaid,
    required this.createdAt,
    this.note = '',
    this.exchangeRateSypPerUsd = 1,
    this.subtotalUsd = 0,
    this.discountUsd = 0,
    this.shippingUsd = 0,
    this.totalUsd = 0,
    this.totalAmountSyp = 0,
    this.returnedUsd = 0,
    this.returnedSyp = 0,
    this.paidUsd = 0,
    this.paidAmountSyp = 0,
    this.remainingUsd = 0,
    this.remainingSyp = 0,
    this.payments = const [],
    this.hasPersistedTotals = false,
    this.initialPaymentAmount = 0,
    this.initialPaymentCurrency = PaymentCurrency.syp,
  });

  double get totalAmount => hasPersistedTotals
      ? (totalAmountSyp - returnedSyp).clamp(0, double.infinity).toDouble()
      : items.fold(0, (sum, item) => sum + item.total);

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final items = json['items'] is List
        ? (json['items'] as List)
              .whereType<Map>()
              .map((item) => OrderItem.fromJson(_asMap(item)))
              .toList(growable: false)
        : <OrderItem>[];
    final payments = json['payments'] is List
        ? (json['payments'] as List)
              .whereType<Map>()
              .map((payment) => OrderPayment.fromJson(_asMap(payment)))
              .toList(growable: false)
        : <OrderPayment>[];
    return OrderModel(
      recordId: '${json['recordId'] ?? json['uuid'] ?? ''}',
      id: '${json['orderNumber'] ?? json['id'] ?? ''}',
      customerId: _nullableString(json['customerId']).isEmpty
          ? null
          : _nullableString(json['customerId']),
      customerName: '${json['customerName'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      address: '${json['address'] ?? ''}',
      items: items,
      status: _orderStatusFromApi(json['status']),
      paymentMethod: _paymentMethodFromApi(json['paymentMethod']),
      paymentStatus: _paymentStatusFromApi(json['paymentStatus']),
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      note: '${json['note'] ?? ''}',
      exchangeRateSypPerUsd: _asDouble(
        json['exchangeRateSypPerUsd'],
        fallback: 1,
      ),
      subtotalUsd: _asDouble(json['subtotalUsd']),
      discountUsd: _asDouble(json['discountUsd']),
      shippingUsd: _asDouble(json['shippingUsd']),
      totalUsd: _asDouble(json['totalUsd']),
      totalAmountSyp: _asDouble(json['totalSyp'] ?? json['totalAmount']),
      returnedUsd: _asDouble(json['returnedUsd']),
      returnedSyp: _asDouble(json['returnedSyp']),
      paidUsd: _asDouble(json['paidUsd']),
      paidAmountSyp: _asDouble(json['paidAmountSyp']),
      remainingUsd: _asDouble(json['remainingUsd']),
      remainingSyp: _asDouble(json['remainingSyp']),
      payments: payments,
      hasPersistedTotals:
          json.containsKey('totalSyp') || json.containsKey('totalAmount'),
    );
  }

  Map<String, dynamic> toApiJson({bool includeInitialPayment = true}) => {
    if (customerId != null) 'customerId': customerId,
    'customerName': customerName,
    'phone': phone,
    'address': address,
    'items': items
        .map((item) => item.toApiJson(exchangeRateSypPerUsd))
        .toList(),
    'status': _orderStatusToApi(status),
    'paymentMethod': _paymentMethodToApi(paymentMethod),
    'discountUsd': discountUsd,
    'shippingUsd': shippingUsd,
    'notes': note,
    if (includeInitialPayment && initialPaymentAmount > 0) ...{
      'initialPaymentAmount': initialPaymentAmount,
      'initialPaymentCurrency': _currencyToApi(initialPaymentCurrency),
      'initialPaymentMethod': _paymentMethodToApi(paymentMethod),
    },
  };
}

String _orderStatusToApi(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'PENDING';
    case OrderStatus.processing:
      return 'PROCESSING';
    case OrderStatus.shipped:
      return 'SHIPPED';
    case OrderStatus.completed:
      return 'COMPLETED';
    case OrderStatus.cancelled:
      return 'CANCELLED';
  }
}

OrderStatus _orderStatusFromApi(dynamic value) {
  switch ('$value'.toUpperCase()) {
    case 'CONFIRMED':
    case 'PROCESSING':
      return OrderStatus.processing;
    case 'SHIPPED':
      return OrderStatus.shipped;
    case 'COMPLETED':
      return OrderStatus.completed;
    case 'CANCELLED':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.pending;
  }
}

String _paymentMethodToApi(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return 'CASH';
    case PaymentMethod.card:
      return 'CARD';
    case PaymentMethod.transfer:
      return 'BANK_TRANSFER';
    case PaymentMethod.cashOnDelivery:
      return 'CASH_ON_DELIVERY';
    case PaymentMethod.other:
      return 'OTHER';
  }
}

PaymentMethod _paymentMethodFromApi(dynamic value) {
  switch ('$value'.toUpperCase()) {
    case 'CARD':
      return PaymentMethod.card;
    case 'BANK_TRANSFER':
    case 'TRANSFER':
      return PaymentMethod.transfer;
    case 'CASH_ON_DELIVERY':
      return PaymentMethod.cashOnDelivery;
    case 'OTHER':
      return PaymentMethod.other;
    default:
      return PaymentMethod.cash;
  }
}

PaymentStatus _paymentStatusFromApi(dynamic value) {
  switch ('$value'.toUpperCase()) {
    case 'PAID':
      return PaymentStatus.paid;
    case 'PARTIALLY_PAID':
      return PaymentStatus.partiallyPaid;
    default:
      return PaymentStatus.unpaid;
  }
}

PaymentCurrency _currencyFromApi(dynamic value) =>
    '$value'.toUpperCase() == 'USD' ? PaymentCurrency.usd : PaymentCurrency.syp;

String _currencyToApi(PaymentCurrency value) =>
    value == PaymentCurrency.usd ? 'USD' : 'SYP';

String _nullableString(dynamic value) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? '' : text;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return <String, dynamic>{};
}
