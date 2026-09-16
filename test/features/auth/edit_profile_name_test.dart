import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bahi/core/models/user.dart';
import 'package:bahi/features/auth/providers/auth_provider.dart';
import 'package:bahi/features/auth/repositories/auth_repository.dart';

void main() {
  group('Edit Profile Name', () {
    test('AuthRepository.updateProfileName is callable', () {
      // Plain repository method, not a Riverpod provider — see
      // auth_repository.dart's doc comment for why.
      expect(AuthRepository.updateProfileName, isNotNull);
    });

    test('currentUserProfileProvider exists and can be invalidated', () {
      final container = ProviderContainer();

      expect(currentUserProfileProvider, isNotNull);
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
  });
}
