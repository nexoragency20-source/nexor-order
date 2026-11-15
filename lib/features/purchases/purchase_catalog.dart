import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../products/product_catalog.dart';
import 'purchase_models.dart';

class PurchaseCatalog extends ChangeNotifier {
  PurchaseCatalog._();

  static final PurchaseCatalog instance = PurchaseCatalog._();

  final ApiClient _api = ApiClient.instance;
  final List<SupplierModel> _suppliers = [];
  final List<PurchaseModel> _purchases = [];
  final List<SupplierPaymentModel> _payments = [];

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  List<SupplierModel> get suppliers => List.unmodifiable(_suppliers);
  List<PurchaseModel> get purchases => List.unmodifiable(_purchases);
  List<SupplierPaymentModel> get payments => List.unmodifiable(_payments);

  int get invoiceCount => _purchases.length;
  int get supplierCount => _suppliers.where((item) => item.isActive).length;
  double get totalPurchasesUsd =>
      _purchases.fold(0, (sum, item) => sum + item.totalUsd);
  double get totalSupplierBalancesUsd => _suppliers.fold(
    0,
    (sum, supplier) =>
        sum +
        (supplierBalanceUsd(supplier.id) > 0
            ? supplierBalanceUsd(supplier.id)
            : 0),
  );

  Future<void> load({bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final responses = await Future.wait([
        _api.get<dynamic>('suppliers'),
        _api.get<dynamic>('purchases'),
        _api.get<dynamic>('supplier-payments'),
      ]);
      final suppliersData = _asMap(responses[0].data);
      final purchasesData = _asMap(responses[1].data);
      final paymentsData = _asMap(responses[2].data);

      _suppliers
        ..clear()
        ..addAll(_items(suppliersData).map(SupplierModel.fromJson));
      _purchases
        ..clear()
        ..addAll(_items(purchasesData).map(PurchaseModel.fromJson));
      _payments
        ..clear()
        ..addAll(_items(paymentsData).map(SupplierPaymentModel.fromJson));
      _hasLoaded = true;
    } on DioException catch (error) {
      _errorMessage = _friendlyError(error);
    } catch (_) {
      _errorMessage = 'تعذر تحميل بيانات الموردين والمشتريات من الخادم.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  SupplierModel? supplierById(String id) {
    for (final supplier in _suppliers) {
      if (supplier.id == id) return supplier;
    }
    return null;
  }

  PurchaseModel? purchaseById(String id) {
    for (final purchase in _purchases) {
      if (purchase.id == id) return purchase;
    }
    return null;
  }

  Future<SupplierModel> addSupplier({
    required String name,
    String phone = '',
    String email = '',
    String address = '',
    String note = '',
  }) async {
    if (name.trim().length < 2)
      throw ArgumentError('اسم المورد يجب أن يتكون من حرفين على الأقل.');
    try {
      final response = await _api.post<dynamic>(
        'suppliers',
        data: {
          'name': name.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
          'address': address.trim(),
          'notes': note.trim(),
        },
      );
      final supplier = SupplierModel.fromJson(_asMap(response.data));
      _suppliers.insert(0, supplier);
      _errorMessage = null;
      notifyListeners();
      return supplier;
    } on DioException catch (error) {
      throw PurchaseCatalogException(_friendlyError(error));
    }
  }

  Future<SupplierModel> updateSupplier(SupplierModel supplier) async {
    try {
      final response = await _api.put<dynamic>(
        'suppliers/${supplier.id}',
        data: supplier.toApiJson(),
      );
      final saved = SupplierModel.fromJson(_asMap(response.data));
      final index = _suppliers.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        _suppliers.insert(0, saved);
      } else {
        _suppliers[index] = saved;
      }
      _errorMessage = null;
      notifyListeners();
      return saved;
    } on DioException catch (error) {
      throw PurchaseCatalogException(_friendlyError(error));
    }
  }

  Future<void> removeSupplier(String supplierId) async {
    try {
      await _api.delete<dynamic>('suppliers/$supplierId');
      final index = _suppliers.indexWhere((item) => item.id == supplierId);
      if (index != -1)
        _suppliers[index] = _suppliers[index].copyWith(isActive: false);
      _errorMessage = null;
      notifyListeners();
    } on DioException catch (error) {
      throw PurchaseCatalogException(_friendlyError(error));
    }
  }

  Future<SupplierPaymentModel> recordPayment({
    required String supplierId,
    String? purchaseId,
    required double amount,
    required String currencyCode,
    required double exchangeRateSypPerUsd,
    String note = '',
  }) async {
    if (!amount.isFinite || amount <= 0)
      throw ArgumentError('أدخل مبلغاً أكبر من صفر.');
    if (currencyCode != 'USD' && currencyCode != 'SYP') {
      throw ArgumentError('العملة غير مدعومة.');
    }
    if (!exchangeRateSypPerUsd.isFinite || exchangeRateSypPerUsd <= 0) {
      throw ArgumentError('سعر الصرف غير صحيح.');
    }
    try {
      final response = await _api.post<dynamic>(
        'suppliers/$supplierId/payments',
        data: {
          'amount': amount,
          'currency': currencyCode,
          if (purchaseId != null) 'purchaseInvoiceId': purchaseId,
          'note': note.trim(),
        },
      );
      final payment = SupplierPaymentModel.fromJson(_asMap(response.data));
      _payments.insert(0, payment);
      _errorMessage = null;
      notifyListeners();
      return payment;
    } on DioException catch (error) {
      throw PurchaseCatalogException(_friendlyError(error));
    }
  }

  Future<PurchaseModel> createPurchase({
    required String supplierId,
    required String invoiceNumber,
    required List<PurchaseItemModel> items,
    required double exchangeRateSypPerUsd,
    String note = '',
    double initialPaymentAmount = 0,
    String initialPaymentCurrency = 'USD',
  }) async {
    if (invoiceNumber.trim().isEmpty)
      throw ArgumentError('رقم فاتورة المورد مطلوب.');
    if (items.isEmpty) throw ArgumentError('أضف منتجاً واحداً على الأقل.');
    if (!initialPaymentAmount.isFinite || initialPaymentAmount < 0) {
      throw ArgumentError('قيمة الدفعة الأولى غير صحيحة.');
    }
    try {
      final response = await _api.post<dynamic>(
        'purchases',
        data: {
          'supplierId': supplierId,
          'invoiceNumber': invoiceNumber.trim(),
          'note': note.trim(),
          'items': items.map((item) => item.toApiJson()).toList(),
          'initialPaymentAmount': initialPaymentAmount,
          'initialPaymentCurrency': initialPaymentCurrency,
        },
      );
      final purchase = PurchaseModel.fromJson(_asMap(response.data));
      // The server transaction has already updated stock and written the ledger movement.
      // Refresh both catalogs; never apply this receipt locally a second time.
      await Future.wait([
        load(force: true),
        ProductCatalog.instance.load(force: true),
      ]);
      return purchase;
    } on DioException catch (error) {
      throw PurchaseCatalogException(_friendlyError(error));
    }
  }

  double paidForPurchaseUsd(String purchaseId) => _payments
      .where((payment) => payment.purchaseId == purchaseId)
      .fold(0, (sum, payment) => sum + payment.amountUsdEquivalent);

  double outstandingForPurchaseUsd(PurchaseModel purchase) =>
      (purchase.totalUsd - paidForPurchaseUsd(purchase.id))
          .clamp(0, double.infinity)
          .toDouble();

  double supplierBalanceUsd(String supplierId) {
    final invoices = _purchases
        .where(
          (item) => item.supplierId == supplierId && item.status == 'RECEIVED',
        )
        .fold(0.0, (sum, item) => sum + item.totalUsd);
    final paid = _payments
        .where((item) => item.supplierId == supplierId)
        .fold(0.0, (sum, item) => sum + item.amountUsdEquivalent);
    return invoices - paid;
  }

  double supplierBalanceSyp(String supplierId) =>
      supplierBalanceUsd(supplierId) *
      ProductCatalog.instance.exchangeRateSypPerUsd;

  List<PurchaseModel> purchasesForSupplier(String supplierId) => _purchases
      .where((item) => item.supplierId == supplierId)
      .toList(growable: false);

  List<SupplierPaymentModel> paymentsForSupplier(String supplierId) => _payments
      .where((item) => item.supplierId == supplierId)
      .toList(growable: false);

  List<Map<String, dynamic>> _items(Map<String, dynamic> payload) {
    final raw = payload['items'];
    if (raw is! List) return const [];
    return raw.map(_asMap).toList(growable: false);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
    return <String, dynamic>{};
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
    return 'تعذر تنفيذ العملية. تحقق من البيانات وحاول مرة أخرى.';
  }
}

class PurchaseCatalogException implements Exception {
  final String message;
  const PurchaseCatalogException(this.message);
  @override
  String toString() => message;
}
