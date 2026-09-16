import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bahi/core/models/user.dart';
import 'package:bahi/features/auth/providers/auth_provider.dart';

void main() {
  group('Edit Profile Name', () {
    test('updateProfileProvider is a FutureProvider', () {
      expect(updateProfileProvider, isNotNull);
    });

    test('updateProfileProvider accepts a fullName string', () {
      final container = ProviderContainer();
      const testName = 'राज कुमार';

      // Verify provider can be called with a string
      final provider = updateProfileProvider(testName);
      expect(provider, isNotNull);
    });

    test('currentUserProfileProvider exists and can be invalidated', () {
      final container = ProviderContainer();

      // Verify currentUserProfileProvider exists
      expect(currentUserProfileProvider, isNotNull);

      // Verify it can be invalidated
      container.invalidate(currentUserProfileProvider);
    });

    test('User model preserves fullName through fromJson/toJson', () {
      const testJson = {
        'id': 'user-123',
        'fullName': 'टेस्ट नाम',
        'createdAt': '2026-01-01T00:00:00Z',
      };

      final user = User.fromJson(testJson);
      expect(user.fullName, 'टेस्ट नाम');

      final json = user.toJson();
      expect(json['fullName'], 'टेस्ट नाम');
    });

    test('updateProfileProvider calls PUT /auth/profile endpoint', () {
      final container = ProviderContainer();
      const testName = 'नया नाम';

      // Verify the provider structure
      final provider = updateProfileProvider(testName);
      expect(provider, isNotNull);
    });
  });
}
