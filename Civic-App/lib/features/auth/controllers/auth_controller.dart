// lib/features/auth/controllers/auth_controller.dart
// Calls the real Django REST / JWT backend.
// JWT access token stored in flutter_secure_storage.
// User name/role cached in SharedPreferences for fast session restore.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../issues/models/user.dart';
import '../../issues/models/issue_status.dart';
import '../models/auth_state.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/services/api_service.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._prefs) : super(_loadState(_prefs));

  final SharedPreferences _prefs;

  static AuthState _loadState(SharedPreferences prefs) {
    final userId = prefs.getString(AppConstants.keyUserId);
    final roleStr = prefs.getString(AppConstants.keyUserRole);
    final name = prefs.getString(AppConstants.keyUserName) ?? '';
    final email = prefs.getString(AppConstants.keyUserEmail) ?? '';

    if (userId != null && roleStr != null) {
      final role = roleStr == 'admin' || roleStr == 'authority'
          ? UserRole.admin
          : UserRole.citizen;
      return AuthState(
        user: AppUser(id: userId, name: name, email: email, role: role),
        isAuthenticated: true,
        isOnboarded: true,
      );
    }
    return const AuthState(isAuthenticated: false, isOnboarded: false);
  }

  /// ── MOCK LOGIN (no backend) — replace with real impl when backend is ready ──
  /// Register: stores name/email locally, auto-logs in. Returns null always.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    // TODO: RESTORE REAL AUTH — replace body below with actual API call
    final user = AppUser(
      id: email,
      name: name.trim().isNotEmpty ? name.trim() : email,
      email: email,
      role: role,
    );
    await _persistSession(user);
    state = AuthState(user: user, isAuthenticated: true, isOnboarded: true);
    return null; // null = success
  }

  /// Login: accepts any credentials, stores locally. Returns null always.
  Future<String?> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    // TODO: RESTORE REAL AUTH — replace body below with actual API call
    // Use the part before '@' as a friendly display name
    final displayName = email.contains('@')
        ? email.split('@').first.replaceAll(RegExp(r'[._]'), ' ')
        : email;

    final user = AppUser(
      id: email,
      name: _capitalize(displayName),
      email: email,
      role: role,
    );
    await _persistSession(user);
    state = AuthState(user: user, isAuthenticated: true, isOnboarded: true);
    return null; // null = success
  }

  /// Capitalises each word in a string.
  String _capitalize(String s) {
    return s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  Future<void> _persistSession(AppUser user) async {
    await _prefs.setString(AppConstants.keyUserId, user.id);
    await _prefs.setString(AppConstants.keyUserRole, user.role.name);
    await _prefs.setString(AppConstants.keyUserName, user.name);
    await _prefs.setString(AppConstants.keyUserEmail, user.email);
  }

  Future<void> switchToAdmin() async {
    if (state.user == null) return;
    final updated = state.user!.copyWith(role: UserRole.admin);
    await _prefs.setString(AppConstants.keyUserRole, 'admin');
    state = state.copyWith(user: updated);
  }

  Future<void> switchToCitizen() async {
    if (state.user == null) return;
    final updated = state.user!.copyWith(role: UserRole.citizen);
    await _prefs.setString(AppConstants.keyUserRole, 'citizen');
    state = state.copyWith(user: updated);
  }

  Future<void> updateName(String name) async {
    if (state.user == null) return;
    final updated = state.user!.copyWith(name: name);
    await _prefs.setString(AppConstants.keyUserName, name);
    state = state.copyWith(user: updated);
  }

  /// Logout: clears secure token and local session data.
  Future<void> logout() async {
    await ApiService.clearToken();
    await _prefs.remove(AppConstants.keyUserId);
    await _prefs.remove(AppConstants.keyUserRole);
    await _prefs.remove(AppConstants.keyUserName);
    await _prefs.remove(AppConstants.keyUserEmail);
    state = const AuthState(isAuthenticated: false, isOnboarded: false);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthController(prefs);
});
