import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'customer_models.dart';

class CustomerCatalog extends ChangeNotifier {
  CustomerCatalog._();
  static final CustomerCatalog instance = CustomerCatalog._();

  final ApiClient _api = ApiClient.instance;
  final List<CustomerRecord> _customers = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  double _exchangeRateSypPerUsd = 15000;

  List<CustomerRecord> get customers => List.unmodifiable(_customers);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  double get exchangeRateSypPerUsd => _exchangeRateSypPerUsd;
  int get customerCount => _customers.length;
  int get activeCustomerCount =>
      _customers.where((item) => item.orderCount > 0).length;
  double get totalPurchasesSyp =>
      _customers.fold(0, (sum, item) => sum + item.totalPurchasesSyp);
  double get totalReceivablesSyp => _customers.fold(
    0,
    (sum, item) => sum + (item.balanceSyp > 0 ? item.balanceSyp : 0),
  );

  Future<void> load({bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) return;
    _isLoading = true;
    _errorMessage = null;
    if (force) _customers.clear();
    notifyListeners();
    try {
      final response = await _api.get<dynamic>('customers');
      final data = _asMap(response.data);
      _exchangeRateSypPerUsd = _asDouble(
        data['exchangeRateSypPerUsd'],
        fallback: 15000,
      );
      final raw = data['items'];
      _customers
        ..clear()
        ..addAll(
          raw is List
              ? raw.whereType<Map>().map(
                  (item) => CustomerRecord.fromJson(_asMap(item)),
                )
              : <CustomerRecord>[],
        );
      _hasLoaded = true;
    } on DioException catch (error) {
      _errorMessage = _friendlyError(error);
    } catch (_) {
      _errorMessage = 'تعذر قراءة بيانات العملاء من الخادم.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CustomerRecord> create(CustomerRecord draft) async {
    try {
      final response = await _api.post<dynamic>(
        'customers',
        data: draft.toApiJson(),
      );
      final saved = CustomerRecord.fromJson(_asMap(response.data));
      _upsert(saved);
      return saved;
    } on DioException catch (error) {
      throw CustomerCatalogException(_friendlyError(error));
    }
  }

  Future<CustomerRecord> update(CustomerRecord customer) async {
    try {
      final response = await _api.put<dynamic>(
        'customers/${customer.id}',
        data: customer.toApiJson(),
      );
      final saved = CustomerRecord.fromJson(_asMap(response.data));
      _upsert(saved);
      return saved;
    } on DioException catch (error) {
      throw CustomerCatalogException(_friendlyError(error));
    }
  }

  Future<void> archive(String id) async {
    try {
      await _api.delete<dynamic>('customers/$id');
      _customers.removeWhere((item) => item.id == id);
      notifyListeners();
    } on DioException catch (error) {
      throw CustomerCatalogException(_friendlyError(error));
    }
  }

  Future<CustomerStatement> loadStatement(String customerId) async {
    try {
      final response = await _api.get<dynamic>(
        'customers/$customerId/statement',
      );
      return CustomerStatement.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw CustomerCatalogException(_friendlyError(error));
    }
  }

  Future<void> recordPayment(
    String customerId,
    CustomerPaymentDraft payment,
  ) async {
    try {
      await _api.post<dynamic>(
        'customers/$customerId/payments',
        data: payment.toApiJson(),
      );
      await load(force: true);
    } on DioException catch (error) {
      throw CustomerCatalogException(_friendlyError(error));
    }
  }

  void _upsert(CustomerRecord customer) {
    final index = _customers.indexWhere((item) => item.id == customer.id);
    if (index == -1) {
      _customers.insert(0, customer);
    } else {
      _customers[index] = customer;
    }
    _customers.sort((a, b) => a.name.compareTo(b.name));
    _errorMessage = null;
    _hasLoaded = true;
    notifyListeners();
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
    if (error.response?.statusCode == 401) {
      return 'انتهت جلسة الدخول. سجّل الدخول مجدداً.';
    }
    return 'تعذر تنفيذ العملية على بيانات العملاء. حاول مرة أخرى.';
  }
}

class CustomerCatalogException implements Exception {
  final String message;
  const CustomerCatalogException(this.message);
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
