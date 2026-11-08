class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  final String id;
  final String name;
  final String email;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  /// Reads the reply of the register and login endpoints.
  factory AuthSession.fromResponse(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      AuthSession.fromResponse(json);

  final String token;
  final AuthUser user;

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}
