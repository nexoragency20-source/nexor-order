import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'product_model.dart';

class ProductCatalog extends ChangeNotifier {
  ProductCatalog._();

  static final ProductCatalog instance = ProductCatalog._();

  final ApiClient _api = ApiClient.instance;
  final List<ProductModel> _products = [];
  double _exchangeRateSypPerUsd = 15000;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  double get exchangeRateSypPerUsd => _exchangeRateSypPerUsd;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  List<ProductModel> get products => List.unmodifiable(_products);

  List<String> get categories {
    final values =
        _products
            .map((product) => product.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  int get activeCount => _products.where((product) => product.isActive).length;
  int get lowStockCount =>
      _products.where((product) => product.isLowStock).length;
  int get outOfStockCount =>
      _products.where((product) => product.isOutOfStock).length;
  double get totalStockCost =>
      _products.fold(0, (sum, item) => sum + item.stockCostValue);
  double get totalStockCostUsd =>
      _products.fold(0, (sum, item) => sum + item.stockCostValueUsd);

  Future<void> load({bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) return;
    _isLoading = true;
    _errorMessage = null;
    if (force) _products.clear();
    notifyListeners();

    try {
      final response = await _api.get<dynamic>('products');
      final data = _asMap(response.data);
      _exchangeRateSypPerUsd = _asDouble(data['exchangeRateSypPerUsd']);
      final rawItems = data['items'];
      _products
        ..clear()
        ..addAll(
          rawItems is List
              ? rawItems.map((item) => ProductModel.fromJson(_asMap(item)))
              : <ProductModel>[],
        );
      _hasLoaded = true;
    } on DioException catch (error) {
      _errorMessage = _friendlyError(error);
    } catch (_) {
      _errorMessage = 'تعذر قراءة قائمة المنتجات من الخادم.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ProductModel? findByBarcode(String barcode) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;
    for (final product in _products) {
      if (product.barcode == normalized) return product;
    }
    return null;
  }

  ProductModel? findById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  String generateBarcode() {
    while (true) {
      final serial = DateTime.now().microsecondsSinceEpoch % 1000000000000;
      final body = serial.toString().padLeft(12, '0');
      final barcode = '$body${_ean13CheckDigit(body)}';
      if (!_products.any((product) => product.barcode == barcode)) {
        return barcode;
      }
    }
  }

  Future<ProductModel> add(ProductModel product) async {
    try {
      final response = await _api.post<dynamic>(
        'products',
        data: product.toApiJson(),
      );
      final saved = ProductModel.fromJson(_asMap(response.data));
      _products.insert(0, saved);
      _errorMessage = null;
      notifyListeners();
      return saved;
    } on DioException catch (error) {
      throw ProductCatalogException(_friendlyError(error));
    }
  }

  Future<ProductModel> update(ProductModel product) async {
    try {
      final response = await _api.put<dynamic>(
        'products/${product.id}',
        data: product.toApiJson(),
      );
      final saved = ProductModel.fromJson(_asMap(response.data));
      final index = _products.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        _products.insert(0, saved);
      } else {
        _products[index] = saved;
      }
      _errorMessage = null;
      notifyListeners();
      return saved;
    } on DioException catch (error) {
      throw ProductCatalogException(_friendlyError(error));
    }
  }

  Future<void> remove(String id) async {
    try {
      final response = await _api.delete<dynamic>('products/$id');
      final archived = ProductModel.fromJson(_asMap(response.data));
      final index = _products.indexWhere((item) => item.id == id);
      if (index != -1) _products[index] = archived;
      _errorMessage = null;
      notifyListeners();
    } on DioException catch (error) {
      throw ProductCatalogException(_friendlyError(error));
    }
  }

  Future<void> setExchangeRate(double value) async {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError('سعر الصرف يجب أن يكون أكبر من صفر.');
    }

    try {
      await _api.patch<dynamic>(
        'products/exchange-rate',
        data: {'exchangeRateSypPerUsd': value},
      );
      _exchangeRateSypPerUsd = value;
      for (var index = 0; index < _products.length; index++) {
        final product = _products[index];
        _products[index] = product.copyWith(
          purchasePriceSyp: (product.purchasePriceUsd * value).roundToDouble(),
          sellingPriceSyp: (product.sellingPriceUsd * value).roundToDouble(),
          exchangeRateSypPerUsd: value,
        );
      }
      notifyListeners();
    } on DioException catch (error) {
      throw ProductCatalogException(_friendlyError(error));
    }
  }

  /// Compatibility for the currently local-only purchases screen.
  /// Purchase invoices are connected to the API in a later integration stage.
  void applyPurchaseReceipt({
    required String productId,
    required int quantity,
    required double unitCostUsd,
    required double unitCostSyp,
    required double exchangeRateSypPerUsd,
  }) {
    if (quantity <= 0 || unitCostUsd < 0 || exchangeRateSypPerUsd <= 0) {
      throw ArgumentError('بيانات استلام المشتريات غير صحيحة.');
    }
    final index = _products.indexWhere((item) => item.id == productId);
    if (index == -1) throw StateError('المنتج غير موجود.');
    final current = _products[index];
    final nextQuantity = current.stockQuantity + quantity;
    final weightedUsd =
        ((current.purchasePriceUsd * current.stockQuantity) +
            (unitCostUsd * quantity)) /
        nextQuantity;
    _products[index] = current.copyWith(
      stockQuantity: nextQuantity,
      purchasePriceUsd: weightedUsd,
      purchasePriceSyp: (weightedUsd * _exchangeRateSypPerUsd).roundToDouble(),
      exchangeRateSypPerUsd: _exchangeRateSypPerUsd,
    );
    notifyListeners();
  }

  int _ean13CheckDigit(String twelveDigits) {
    var sum = 0;
    for (var i = 0; i < twelveDigits.length; i++) {
      final digit = int.parse(twelveDigits[i]);
      sum += i.isOdd ? digit * 3 : digit;
    }
    return (10 - (sum % 10)) % 10;
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
    return 'تعذر تنفيذ العملية على المنتجات. حاول مرة أخرى.';
  }
}

class ProductCatalogException implements Exception {
  final String message;
  const ProductCatalogException(this.message);
  @override
  String toString() => message;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return <String, dynamic>{};
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
