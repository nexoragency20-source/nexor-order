class AuthSession {
  final String accessToken;
  final String tokenType;
  final String expiresIn;
  final AuthUser user;
  final AuthOrganization organization;
  final AuthStore store;
  final String role;

  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
    required this.organization,
    required this.store,
    required this.role,
  });

  factory AuthSession.fromAuthResponse(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: _readString(json['accessToken']),
      tokenType: _readString(json['tokenType'], fallback: 'Bearer'),
      expiresIn: _readString(json['expiresIn']),
      user: AuthUser.fromJson(_asMap(json['user'])),
      organization: AuthOrganization.fromJson(_asMap(json['organization'])),
      store: AuthStore.fromJson(_asMap(json['store'])),
      role: _readString(json['role']),
    );
  }

  factory AuthSession.fromProfile({
    required Map<String, dynamic> json,
    required String accessToken,
  }) {
    return AuthSession(
      accessToken: accessToken,
      tokenType: 'Bearer',
      expiresIn: '',
      user: AuthUser.fromJson(_asMap(json['user'])),
      organization: AuthOrganization.fromJson(_asMap(json['organization'])),
      store: AuthStore.fromJson(_asMap(json['store'])),
      role: _readString(json['role']),
    );
  }
}

class AuthUser {
  final String id;
  final String email;
  final String fullName;

  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: _readString(json['id']),
    email: _readString(json['email']),
    fullName: _readString(json['fullName']),
  );
}

class AuthOrganization {
  final String id;
  final String name;
  final String slug;

  const AuthOrganization({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory AuthOrganization.fromJson(Map<String, dynamic> json) =>
      AuthOrganization(
        id: _readString(json['id']),
        name: _readString(json['name']),
        slug: _readString(json['slug']),
      );
}

class AuthStore {
  final String id;
  final String name;
  final String defaultCurrency;
  final double exchangeRateSypPerUsd;

  const AuthStore({
    required this.id,
    required this.name,
    required this.defaultCurrency,
    required this.exchangeRateSypPerUsd,
  });

  factory AuthStore.fromJson(Map<String, dynamic> json) => AuthStore(
    id: _readString(json['id']),
    name: _readString(json['name']),
    defaultCurrency: _readString(json['defaultCurrency'], fallback: 'SYP'),
    exchangeRateSypPerUsd:
        double.tryParse(json['exchangeRateSypPerUsd']?.toString() ?? '') ?? 0,
  );
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return <String, dynamic>{};
}

String _readString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final result = value.toString();
  return result.isEmpty ? fallback : result;
}
