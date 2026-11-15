import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';

class ReturnableOrderItem {
  final String orderItemId;
  final String productId;
  final String productName;
  final String barcode;
  final double quantity;
  final double reservedQuantity;
  final double returnableQuantity;
  final double unitPriceUsd;
  final double unitPriceSyp;

  const ReturnableOrderItem({
    required this.orderItemId,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.reservedQuantity,
    required this.returnableQuantity,
    required this.unitPriceUsd,
    required this.unitPriceSyp,
  });

  factory ReturnableOrderItem.fromJson(Map<String, dynamic> json) =>
      ReturnableOrderItem(
        orderItemId: '${json['orderItemId'] ?? ''}',
        productId: '${json['productId'] ?? ''}',
        productName: '${json['productName'] ?? ''}',
        barcode: '${json['barcode'] ?? ''}',
        quantity: _num(json['quantity']),
        reservedQuantity: _num(json['reservedQuantity']),
        returnableQuantity: _num(json['returnableQuantity']),
        unitPriceUsd: _num(json['unitPriceUsd']),
        unitPriceSyp: _num(json['unitPriceSyp']),
      );
}

class ReturnableOrder {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String status;
  final DateTime createdAt;
  final double exchangeRateSypPerUsd;
  final double subtotalUsd;
  final double discountUsd;
  final List<ReturnableOrderItem> items;

  const ReturnableOrder({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.createdAt,
    required this.exchangeRateSypPerUsd,
    required this.subtotalUsd,
    required this.discountUsd,
    required this.items,
  });

  factory ReturnableOrder.fromJson(Map<String, dynamic> json) =>
      ReturnableOrder(
        id: '${json['id'] ?? ''}',
        orderNumber: '${json['orderNumber'] ?? ''}',
        customerId: '${json['customerId'] ?? ''}',
        customerName: '${json['customerName'] ?? ''}',
        customerPhone: '${json['customerPhone'] ?? ''}',
        status: '${json['status'] ?? ''}',
        createdAt:
            DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
        exchangeRateSypPerUsd: _num(json['exchangeRateSypPerUsd'], 1),
        subtotalUsd: _num(json['subtotalUsd']),
        discountUsd: _num(json['discountUsd']),
        items: _mapList(
          json['items'],
        ).map(ReturnableOrderItem.fromJson).toList(),
      );
}

class SalesReturnLine {
  final String productName;
  final String barcode;
  final double quantity;
  final double lineTotalUsd;
  final double lineTotalSyp;

  const SalesReturnLine({
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.lineTotalUsd,
    required this.lineTotalSyp,
  });

  factory SalesReturnLine.fromJson(Map<String, dynamic> json) =>
      SalesReturnLine(
        productName: '${json['productName'] ?? ''}',
        barcode: '${json['barcode'] ?? ''}',
        quantity: _num(json['quantity']),
        lineTotalUsd: _num(json['lineTotalUsd']),
        lineTotalSyp: _num(json['lineTotalSyp']),
      );
}

class SalesReturnRecord {
  final String id;
  final String returnNumber;
  final String status;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String settlementType;
  final String currency;
  final double amount;
  final double amountUsdEquivalent;
  final double amountSypEquivalent;
  final String reason;
  final String notes;
  final DateTime createdAt;
  final DateTime? receivedAt;
  final List<SalesReturnLine> items;

  const SalesReturnRecord({
    required this.id,
    required this.returnNumber,
    required this.status,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.settlementType,
    required this.currency,
    required this.amount,
    required this.amountUsdEquivalent,
    required this.amountSypEquivalent,
    required this.reason,
    required this.notes,
    required this.createdAt,
    required this.receivedAt,
    required this.items,
  });

  factory SalesReturnRecord.fromJson(Map<String, dynamic> json) =>
      SalesReturnRecord(
        id: '${json['id'] ?? ''}',
        returnNumber: '${json['returnNumber'] ?? ''}',
        status: '${json['status'] ?? ''}',
        orderNumber: '${json['orderNumber'] ?? ''}',
        customerName: '${json['customerName'] ?? ''}',
        customerPhone: '${json['customerPhone'] ?? ''}',
        settlementType: '${json['settlementType'] ?? 'CASH'}',
        currency: '${json['currency'] ?? 'SYP'}',
        amount: _num(json['amount']),
        amountUsdEquivalent: _num(json['amountUsdEquivalent']),
        amountSypEquivalent: _num(json['amountSypEquivalent']),
        reason: '${json['reason'] ?? ''}',
        notes: '${json['notes'] ?? ''}',
        createdAt:
            DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
        receivedAt: DateTime.tryParse('${json['receivedAt'] ?? ''}'),
        items: _mapList(json['items']).map(SalesReturnLine.fromJson).toList(),
      );
}

class ReturnCatalog extends ChangeNotifier {
  ReturnCatalog._();
  static final ReturnCatalog instance = ReturnCatalog._();

  final ApiClient _api = ApiClient.instance;
  final List<SalesReturnRecord> _returns = [];
  final List<ReturnableOrder> _eligibleOrders = [];
  Map<String, dynamic> _summary = const {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  List<SalesReturnRecord> get returns => List.unmodifiable(_returns);
  List<ReturnableOrder> get eligibleOrders =>
      List.unmodifiable(_eligibleOrders);
  Map<String, dynamic> get summary => Map.unmodifiable(_summary);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.get<dynamic>('returns'),
        _api.get<dynamic>('returns/eligible-orders'),
      ]);
      final data = _asMap(results[0].data);
      _summary = _asMap(data['summary']);
      _returns
        ..clear()
        ..addAll(_mapList(data['items']).map(SalesReturnRecord.fromJson));
      final eligible = _asMap(results[1].data);
      _eligibleOrders
        ..clear()
        ..addAll(_mapList(eligible['items']).map(ReturnableOrder.fromJson));
      _hasLoaded = true;
    } on DioException catch (error) {
      _errorMessage = _friendlyError(error);
    } catch (_) {
      _errorMessage = 'تعذر تحميل بيانات المرتجعات من الخادم.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SalesReturnRecord> create({
    required ReturnableOrder order,
    required List<Map<String, dynamic>> items,
    required String settlementType,
    required String currency,
    required String reason,
    required String notes,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        'returns',
        data: {
          'orderId': order.id,
          'items': items,
          'settlementType': settlementType,
          'currency': currency,
          'reason': reason,
          'notes': notes,
        },
      );
      final saved = SalesReturnRecord.fromJson(_asMap(response.data));
      await load(force: true);
      return saved;
    } on DioException catch (error) {
      throw ReturnCatalogException(_friendlyError(error));
    }
  }

  Future<void> receive(
    SalesReturnRecord item,
    DateTime receivedAt,
    String note,
  ) async {
    try {
      await _api.post<dynamic>(
        'returns/${item.id}/receive',
        data: {'receivedAt': receivedAt.toIso8601String(), 'note': note},
      );
      await load(force: true);
    } on DioException catch (error) {
      throw ReturnCatalogException(_friendlyError(error));
    }
  }

  Future<void> reject(SalesReturnRecord item, String reason) async {
    try {
      await _api.post<dynamic>(
        'returns/${item.id}/reject',
        data: {'reason': reason},
      );
      await load(force: true);
    } on DioException catch (error) {
      throw ReturnCatalogException(_friendlyError(error));
    }
  }

  String _friendlyError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) return message.join('\n');
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'تعذر الاتصال بالخادم. تأكد أن NestJS يعمل على المنفذ 3000.';
    }
    if (error.response?.statusCode == 401)
      return 'انتهت جلسة الدخول. سجّل الدخول مجدداً.';
    return 'تعذر تنفيذ العملية. حاول مرة أخرى.';
  }
}

class ReturnCatalogException implements Exception {
  final String message;
  const ReturnCatalogException(this.message);
  @override
  String toString() => message;
}

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value.whereType<Map>().map(_asMap).toList()
    : <Map<String, dynamic>>[];

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return <String, dynamic>{};
}

double _num(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
