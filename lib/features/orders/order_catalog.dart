import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/order_model.dart';

class OrderCatalog extends ChangeNotifier {
  OrderCatalog._();
  static final OrderCatalog instance = OrderCatalog._();

  final ApiClient _api = ApiClient.instance;
  final List<OrderModel> _orders = [];
  final List<OrderCustomer> _customers = [];
  bool _isLoading = false;
  bool _isLoadingCustomers = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  double _exchangeRateSypPerUsd = 15000;

  List<OrderModel> get orders => List.unmodifiable(_orders);
  List<OrderCustomer> get customers => List.unmodifiable(_customers);
  bool get isLoading => _isLoading;
  bool get isLoadingCustomers => _isLoadingCustomers;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  double get exchangeRateSypPerUsd => _exchangeRateSypPerUsd;
  int get totalOrders => _orders.length;
  int get pendingOrders =>
      _orders.where((o) => o.status == OrderStatus.pending).length;
  int get processingOrders =>
      _orders.where((o) => o.status == OrderStatus.processing).length;
  double get totalSalesSyp => _orders
      .where((o) => o.status != OrderStatus.cancelled)
      .fold(0, (sum, order) => sum + order.totalAmount);

  Future<void> load({bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) return;
    _isLoading = true;
    _errorMessage = null;
    if (force) _orders.clear();
    notifyListeners();
    try {
      final response = await _api.get<dynamic>('orders');
      final data = _asMap(response.data);
      _exchangeRateSypPerUsd = _asDouble(
        data['exchangeRateSypPerUsd'],
        fallback: 15000,
      );
      final raw = data['items'];
      _orders
        ..clear()
        ..addAll(
          raw is List
              ? raw.map((item) => OrderModel.fromJson(_asMap(item)))
              : <OrderModel>[],
        );
      _hasLoaded = true;
    } on DioException catch (error) {
      _errorMessage = _friendlyError(error);
    } catch (_) {
      _errorMessage = 'تعذر قراءة الطلبات من الخادم.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCustomers({bool force = false}) async {
    if (_isLoadingCustomers || (_customers.isNotEmpty && !force)) return;
    _isLoadingCustomers = true;
    notifyListeners();
    try {
      final response = await _api.get<dynamic>('orders/customers');
      final data = _asMap(response.data);
      final raw = data['items'];
      _customers
        ..clear()
        ..addAll(
          raw is List
              ? raw.map((item) => OrderCustomer.fromJson(_asMap(item)))
              : <OrderCustomer>[],
        );
    } on DioException {
      // The order form still permits entering a new customer manually.
    } finally {
      _isLoadingCustomers = false;
      notifyListeners();
    }
  }

  Future<OrderModel> create(OrderModel order) async {
    try {
      final response = await _api.post<dynamic>(
        'orders',
        data: order.toApiJson(),
      );
      final saved = OrderModel.fromJson(_asMap(response.data));
      _upsert(saved);
      await loadCustomers(force: true);
      notifyListeners();
      return saved;
    } on DioException catch (error) {
      throw OrderCatalogException(_friendlyError(error));
    }
  }

  Future<OrderModel> update(OrderModel order) async {
    if (order.recordId.isEmpty)
      throw const OrderCatalogException('معرّف الطلب غير متوفر.');
    try {
      final response = await _api.put<dynamic>(
        'orders/${order.recordId}',
        data: order.toApiJson(includeInitialPayment: false),
      );
      final saved = OrderModel.fromJson(_asMap(response.data));
      _upsert(saved);
      await loadCustomers(force: true);
      notifyListeners();
      return saved;
    } on DioException catch (error) {
      throw OrderCatalogException(_friendlyError(error));
    }
  }

  Future<OrderModel> changeStatus(OrderModel order, OrderStatus status) async {
    if (order.recordId.isEmpty)
      throw const OrderCatalogException('معرّف الطلب غير متوفر.');
    try {
      final response = await _api.patch<dynamic>(
        'orders/${order.recordId}/status',
        data: {'status': _statusToApi(status)},
      );
      final saved = OrderModel.fromJson(_asMap(response.data));
      _upsert(saved);
      notifyListeners();
      return saved;
    } on DioException catch (error) {
      throw OrderCatalogException(_friendlyError(error));
    }
  }

  Future<OrderModel> cancel(OrderModel order) =>
      changeStatus(order, OrderStatus.cancelled);

  Future<OrderModel> recordPayment({
    required OrderModel order,
    required double amount,
    required PaymentCurrency currency,
    required PaymentMethod method,
    String note = '',
  }) async {
    if (order.recordId.isEmpty)
      throw const OrderCatalogException('معرّف الطلب غير متوفر.');
    try {
      final response = await _api.post<dynamic>(
        'orders/${order.recordId}/payments',
        data: {
          'amount': amount,
          'currency': currency == PaymentCurrency.usd ? 'USD' : 'SYP',
          'method': _paymentMethodToApi(method),
          'note': note,
        },
      );
      final saved = OrderModel.fromJson(_asMap(response.data));
      _upsert(saved);
      notifyListeners();
      return saved;
    } on DioException catch (error) {
      throw OrderCatalogException(_friendlyError(error));
    }
  }

  void _upsert(OrderModel order) {
    final index = _orders.indexWhere((item) => item.recordId == order.recordId);
    if (index == -1) {
      _orders.insert(0, order);
    } else {
      _orders[index] = order;
    }
    _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _errorMessage = null;
    _hasLoaded = true;
  }

  String _statusToApi(OrderStatus status) {
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

  String _friendlyError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) {
        return message.map((item) => item.toString()).join('\n');
      }
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'تعذر الاتصال بالخادم. تأكد أن NestJS يعمل على المنفذ 3000.';
    }
    if (error.response?.statusCode == 401)
      return 'انتهت جلسة الدخول. سجّل الدخول مجدداً.';
    return 'تعذر تنفيذ العملية على الطلبات. حاول مرة أخرى.';
  }
}

class OrderCatalogException implements Exception {
  final String message;
  const OrderCatalogException(this.message);
  @override
  String toString() => message;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return <String, dynamic>{};
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
