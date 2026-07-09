class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
  });

  final String id;
  final String username;
  final String email;

  factory AuthUser.fromJson(Map<String, Object?> json) {
    return AuthUser(
      id: json['id']! as String,
      username: json['username']! as String,
      email: json['email']! as String,
    );
  }

  Map<String, Object?> toJson() {
    return {'id': id, 'username': username, 'email': email};
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthUser &&
            id == other.id &&
            username == other.username &&
            email == other.email;
  }

  @override
  int get hashCode => Object.hash(id, username, email);
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;

  factory AuthSession.fromJson(Map<String, Object?> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user']! as Map<String, Object?>),
      accessToken: json['accessToken']! as String,
      refreshToken: json['refreshToken']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthSession &&
            user == other.user &&
            accessToken == other.accessToken &&
            refreshToken == other.refreshToken;
  }

  @override
  int get hashCode => Object.hash(user, accessToken, refreshToken);
}

class RegisterResult {
  const RegisterResult({required this.user, required this.isFirstUser});

  final AuthUser user;
  final bool isFirstUser;

  factory RegisterResult.fromJson(Map<String, Object?> json) {
    return RegisterResult(
      user: AuthUser.fromJson(json['user']! as Map<String, Object?>),
      isFirstUser: json['isFirstUser']! as bool,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RegisterResult &&
            user == other.user &&
            isFirstUser == other.isFirstUser;
  }

  @override
  int get hashCode => Object.hash(user, isFirstUser);
}
