import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../theme/theme_controller.dart';
import '../../features/auth/controllers/auth_controller.dart';

String maskCitizenId(String id) {
  if (id.length <= 8) return '****';
  return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
}

final citizenIdentityProvider = FutureProvider<String>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final loggedInId = auth.user?.id.trim();
  if (loggedInId != null && loggedInId.isNotEmpty) {
    return loggedInId;
  }

  final prefs = ref.watch(sharedPreferencesProvider);
  final existing = prefs.getString(AppConstants.keyCitizenId);
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }

  final generated = 'mobile_user_${const Uuid().v4()}';
  await prefs.setString(AppConstants.keyCitizenId, generated);
  return generated;
});
