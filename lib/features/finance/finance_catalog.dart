import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'finance_models.dart';

class FinanceCatalog extends ChangeNotifier {
  FinanceCatalog._();
  static final FinanceCatalog instance = FinanceCatalog._();

  final ApiClient _api = ApiClient.instance;
  FinanceSnapshot? _snapshot;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  FinanceSnapshot? get snapshot => _snapshot;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load({String? date, bool force = false}) async {
    if (_isLoading) return;
    if (_snapshot != null && !force && (date == null || _snapshot!.date == date)) {
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.get<dynamic>(
        'finance/overview',
        queryParameters: date == null ? null : {'date': date},
      );
      _snapshot = FinanceSnapshot.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      _errorMessage = _friendlyError(error);
    } catch (_) {
      _errorMessage = 'تعذر قراءة حركة الصندوق من الخادم.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTransaction(FinanceTransactionDraft draft) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.post<dynamic>('finance/transactions', data: draft.toJson());
      await load(date: _snapshot?.date, force: true);
    } on DioException catch (error) {
      throw FinanceCatalogException(_friendlyError(error));
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> createTransfer(FinanceTransferDraft draft) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.post<dynamic>('finance/transfers', data: draft.toJson());
      await load(date: _snapshot?.date, force: true);
    } on DioException catch (error) {
      throw FinanceCatalogException(_friendlyError(error));
    } finally {
      _isSaving = false;
      notifyListeners();
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
    if (error.response?.statusCode == 401) {
      return 'انتهت جلسة الدخول. سجّل الدخول مجدداً.';
    }
    return 'تعذر تنفيذ الحركة المالية. حاول مرة أخرى.';
  }
}

class FinanceCatalogException implements Exception {
  final String message;
  const FinanceCatalogException(this.message);
  @override
  String toString() => message;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return <String, dynamic>{};
}
