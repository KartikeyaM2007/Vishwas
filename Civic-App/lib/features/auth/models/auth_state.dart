// lib/features/auth/models/auth_state.dart
import '../../issues/models/user.dart';
import '../../issues/models/issue_status.dart';

class AuthState {
  final AppUser? user;
  final bool isAuthenticated;
  final bool isOnboarded;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isOnboarded = false,
  });

  UserRole? get role => user?.role;

  AuthState copyWith({
    AppUser? user,
    bool? isAuthenticated,
    bool? isOnboarded,
  }) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }
}
