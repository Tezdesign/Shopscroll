import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/mock/mock_sellers.dart';
import 'package:marketplace_app/data/models/user_profile.dart';
import 'package:marketplace_app/data/repositories/mock/mock_user_profile_repository.dart';
import 'package:marketplace_app/data/repositories/user_profile_repository.dart';

void main() {
  late MockUserProfileRepository repository;

  setUp(() {
    repository = MockUserProfileRepository();
  });

  tearDown(() {
    // Tests that add or mutate rows below run against the shared
    // `mockSellers` seed list (also read by other test files), so restore
    // it to its original identities/content after each test.
    mockSellers.removeWhere((profile) => profile.id == 'test-buyer-1');
    final appleIndex = mockSellers.indexWhere(
      (profile) => profile.id == 'seller-apple',
    );
    if (appleIndex != -1 && mockSellers[appleIndex].name != 'Apple') {
      mockSellers[appleIndex] = mockSellers[appleIndex].copyWith(
        name: 'Apple',
        username: '@apple',
      );
    }
  });

  group('getUserProfileById', () {
    test('returns the matching profile', () async {
      final profile = await repository.getUserProfileById('seller-apple');

      expect(profile?.name, 'Apple');
    });

    test('returns null when no profile matches the id', () async {
      final profile = await repository.getUserProfileById('does-not-exist');

      expect(profile, isNull);
    });
  });

  group('updateUserProfile', () {
    test('creates a new profile when the id has no existing row', () async {
      await repository.updateUserProfile(
        'test-buyer-1',
        name: 'Jamie Buyer',
        username: '@jamiebuyer',
        bio: 'Just browsing.',
      );

      final created = await repository.getUserProfileById('test-buyer-1');
      expect(created?.name, 'Jamie Buyer');
      expect(created?.username, '@jamiebuyer');
      expect(created?.bio, 'Just browsing.');
      expect(created?.role, UserRole.buyer);
    });

    test('updates name, username, and bio on an existing profile', () async {
      await repository.updateUserProfile(
        'seller-apple',
        name: 'Apple Inc.',
        username: '@appleinc',
        bio: 'Updated bio.',
      );

      final updated = await repository.getUserProfileById('seller-apple');
      expect(updated?.name, 'Apple Inc.');
      expect(updated?.username, '@appleinc');
      expect(updated?.bio, 'Updated bio.');
    });

    test('leaves id and role unchanged on an existing profile', () async {
      await repository.updateUserProfile(
        'seller-apple',
        name: 'Apple Inc.',
        username: '@appleinc',
      );

      final updated = await repository.getUserProfileById('seller-apple');
      expect(updated?.id, 'seller-apple');
      expect(updated?.role, UserRole.seller);
    });

    test(
      'throws UsernameTakenException when the username belongs to a '
      'different existing profile',
      () async {
        expect(
          () => repository.updateUserProfile(
            'seller-nike',
            name: 'Nike',
            username: '@apple',
          ),
          throwsA(isA<UsernameTakenException>()),
        );
      },
    );

    test('allows keeping the same username on the same profile', () async {
      await repository.updateUserProfile(
        'seller-apple',
        name: 'Apple',
        username: '@apple',
        bio: 'Still Apple.',
      );

      final updated = await repository.getUserProfileById('seller-apple');
      expect(updated?.username, '@apple');
      expect(updated?.bio, 'Still Apple.');
    });

    test('does not create a duplicate row when updating an existing id', () async {
      final before = (await repository.getSellers()).length;

      await repository.updateUserProfile(
        'seller-nike',
        name: 'Nike',
        username: '@nike',
      );

      final after = (await repository.getSellers()).length;
      expect(after, before);
    });
  });
}
