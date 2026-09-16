import '../../../core/models/user.dart';
import '../../../core/services/api_client.dart';

/// Plain (non-Riverpod) repository for auth/profile mutations. Deliberately
/// NOT wrapped in a provider — using it via an autoDispose FutureProvider
/// and immediately invalidating a different provider right after
/// triggered a Riverpod internal "_dependents.isEmpty" assertion (teardown
/// of the just-completed autoDispose provider raced with the invalidate).
/// A plain static call sidesteps that provider-disposal race entirely.
class AuthRepository {
  static Future<User> updateProfileName(String fullName) async {
    final response = await ApiClient.instance.put(
      '/auth/profile',
      data: {'fullName': fullName},
    );
    return User.fromJson(response.data);
  }
}
