import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_config.dart';
import 'auth_session.dart';

enum AuthStatus { restoring, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  static const String _tokenStorageKey = ApiConfig.accessTokenKey;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final Dio _dio;

  AuthStatus _status = AuthStatus.restoring;
  AuthSession? _session;
  bool _isBusy = false;
  String? _errorMessage;

  AuthController() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl.endsWith('/')
            ? ApiConfig.baseUrl
            : '${ApiConfig.baseUrl}/',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // The token is read from secure storage for every request. This also
    // protects /auth/me after the app has been restarted.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _storage.read(key: _tokenStorageKey);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          } catch (error) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                message: 'تعذر قراءة جلسة الدخول الآمنة.',
              ),
            );
          }
        },
      ),
    );
  }

  AuthStatus get status => _status;
  AuthSession? get session => _session;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _status == AuthStatus.signedIn && _session != null;

  Future<void> restoreSession() async {
    try {
      final token = await _storage.read(key: _tokenStorageKey);
      if (token == null || token.isEmpty) {
        _status = AuthStatus.signedOut;
        return;
      }

      final response = await _dio.get<dynamic>('auth/me');
      final data = _responseMap(response.data);
      _session = AuthSession.fromProfile(json: data, accessToken: token);
      _status = AuthStatus.signedIn;
    } on DioException catch (error) {
      // Expired/invalid sessions are removed. A temporary network error also
      // returns to the login screen; the user can retry without a stale token.
      await _clearStoredSession();
      _session = null;
      _status = AuthStatus.signedOut;
      _errorMessage = _friendlyError(error);
    } catch (_) {
      await _clearStoredSession();
      _session = null;
      _status = AuthStatus.signedOut;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) {
    return _authenticate(
      endpoint: 'auth/login',
      body: {'email': email.trim(), 'password': password},
    );
  }

  Future<bool> register({
    required String activationCode,
    required String email,
    required String fullName,
    required String password,
  }) {
    final body = <String, dynamic>{
      'activationCode': activationCode.trim().toUpperCase(),
      'email': email.trim(),
      'fullName': fullName.trim(),
      'password': password,
    };
    return _authenticate(endpoint: 'auth/register', body: body);
  }

  Future<bool> _authenticate({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.post<dynamic>(endpoint, data: body);
      final data = _responseMap(response.data);
      final token = data['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        throw const AuthException('لم يُرجع الخادم رمز الدخول.');
      }

      await _storage.write(key: _tokenStorageKey, value: token);
      _session = AuthSession.fromAuthResponse(data);
      _status = AuthStatus.signedIn;
      return true;
    } on DioException catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } on AuthException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'حدث خطأ غير متوقع أثناء تسجيل الدخول.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _clearStoredSession();
    _session = null;
    _status = AuthStatus.signedOut;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _clearStoredSession() async {
    try {
      await _storage.delete(key: _tokenStorageKey);
    } catch (_) {
      // Continue signing out locally even if secure storage reports an error.
    }
  }

  Map<String, dynamic> _responseMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  String _friendlyError(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map) {
      final message = responseData['message'];
      if (message is String && message.trim().isNotEmpty) return message;
      if (message is List && message.isNotEmpty) {
        return message.map((item) => item.toString()).join('\n');
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'انتهت مهلة الاتصال بالخادم. حاول مرة أخرى.';
      case DioExceptionType.connectionError:
        return 'تعذر الاتصال بالخادم. تأكد أن NestJS يعمل على المنفذ 3000.';
      case DioExceptionType.badCertificate:
        return 'تعذر التحقق من شهادة الاتصال الآمن.';
      default:
        if (error.response?.statusCode == 401) {
          return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
        }
        if (error.response?.statusCode == 409) {
          return 'هذا البريد الإلكتروني مسجل مسبقاً.';
        }
        return 'تعذر إتمام الطلب. تحقق من الاتصال وحاول مجدداً.';
    }
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}
