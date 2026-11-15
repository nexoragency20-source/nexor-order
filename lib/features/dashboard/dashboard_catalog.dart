import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'dashboard_models.dart';

class DashboardCatalog extends ChangeNotifier {
  DashboardCatalog._();
  static final DashboardCatalog instance = DashboardCatalog._();

  final ApiClient _api = ApiClient.instance;
  DashboardOverview? _overview;
  bool _isLoading = false;
  String? _errorMessage;

  DashboardOverview? get overview => _overview;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _overview != null;

  Future<void> load({bool force = false}) async {
    if (_isLoading || (_overview != null && !force)) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final date = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final response = await _api.get<dynamic>(
        'dashboard/overview',
        queryParameters: {
          'date': date,
          'utcOffsetMinutes': now.timeZoneOffset.inMinutes,
        },
      );
      _overview = DashboardOverview.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      _errorMessage = _friendlyError(error);
    } catch (_) {
      _errorMessage = 'تعذر قراءة بيانات لوحة التحكم من الخادم.';
    } finally {
      _isLoading = false;
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
    return 'تعذر تحميل إحصائيات المتجر.';
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return <String, dynamic>{};
}
