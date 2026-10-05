import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/area/app_area.dart';
import 'package:marketplace_app/core/area/landing_after_sign_in.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/user_profile_repository.dart';
import 'package:marketplace_app/shared/widgets/account_type_toggle.dart';
import 'package:shopscroll_shared/models/seller_application.dart';
import 'package:shopscroll_shared/models/user_profile.dart';

SellerApplication application(
  SellerApplicationStatus status, {
  String? reason,
}) => SellerApplication(
  id: 'a1',
  applicantId: 'u1',
  status: status,
  storeName: 'Shop',
  username: 'shop',
  location: 'Tunis',
  idDocumentPath: 'x',
  rejectionReason: reason,
  createdAt: DateTime(2026, 1, 1),
);

class _Profiles implements UserProfileRepository {
  _Profiles(this.role);

  final UserRole role;

  @override
  Future<UserProfile?> getUserProfileById(String id) async =>
      UserProfile(id: id, name: 'N', username: 'n', role: role);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('areaNoticeFor (spec 0014, AC-1)', () {
    test('no application says to apply from Settings', () {
      final notice = areaNoticeFor(const []);
      expect(notice.kind, AreaNoticeKind.none);
      expect(
        notice.message,
        'You are not a store owner yet. Apply from Settings, Seller application.',
      );
    });

    test('one under review says it is being reviewed', () {
      final notice = areaNoticeFor([
        application(SellerApplicationStatus.reviewing),
      ]);
      expect(notice.message, 'Your application is being reviewed.');
    });

    test('a rejected one gives the reason', () {
      final notice = areaNoticeFor([
        application(SellerApplicationStatus.rejected, reason: 'Blurry ID'),
      ]);
      expect(notice.message, 'Your application was rejected: Blurry ID.');
    });

    test('a rejected one with no reason still reads well', () {
      final notice = areaNoticeFor([
        application(SellerApplicationStatus.rejected),
      ]);
      expect(notice.message, 'Your application was rejected.');
    });

    test('one under review wins over an older rejected one', () {
      final notice = areaNoticeFor([
        application(SellerApplicationStatus.reviewing),
        application(SellerApplicationStatus.rejected, reason: 'old'),
      ]);
      expect(notice.kind, AreaNoticeKind.reviewing);
    });

    test('the newest decision counts when nothing is under review', () {
      final notice = areaNoticeFor([
        application(SellerApplicationStatus.rejected, reason: 'new'),
        application(SellerApplicationStatus.approved),
      ]);
      expect(notice.kind, AreaNoticeKind.rejected);
    });

    test('an approved one that did not make a seller points to the screen', () {
      final notice = areaNoticeFor([
        application(SellerApplicationStatus.approved),
      ]);
      expect(notice.kind, AreaNoticeKind.approved);
      expect(notice.message, contains('Seller application'));
    });
  });

  group('landingAfterSignIn (spec 0014, AC-1)', () {
    Future<List<SellerApplication>> noApplications() async => const [];

    test(
      'Buyer opens the buyer area, even for a seller, with no lookups',
      () async {
        final landing = await landingAfterSignIn(
          choice: AccountType.buyer,
          role: () async => throw StateError('not asked'),
          applications: () async => throw StateError('not asked'),
        );
        expect(landing.area, AppArea.buyer);
        expect(landing.notice, isNull);
      },
    );

    test('Store owner opens the store area for a seller', () async {
      final landing = await landingAfterSignIn(
        choice: AccountType.storeOwner,
        role: () async => UserRole.seller,
        applications: noApplications,
      );
      expect(landing.area, AppArea.store);
      expect(landing.notice, isNull);
    });

    test(
      'Store owner who is a buyer opens the buyer area with a notice',
      () async {
        final landing = await landingAfterSignIn(
          choice: AccountType.storeOwner,
          role: () async => UserRole.buyer,
          applications: () async => [
            application(SellerApplicationStatus.reviewing),
          ],
        );
        expect(landing.area, AppArea.buyer);
        expect(landing.notice?.kind, AreaNoticeKind.reviewing);
      },
    );

    test('a failed lookup still signs in, in the buyer area', () async {
      final landing = await landingAfterSignIn(
        choice: AccountType.storeOwner,
        role: () async => throw StateError('offline'),
        applications: () async => throw StateError('offline'),
      );
      expect(landing.area, AppArea.buyer);
      expect(landing.notice?.kind, AreaNoticeKind.none);
    });
  });

  group('isSellerProvider', () {
    Future<bool> readIsSeller(UserRole role, {String? userId = 'u1'}) async {
      final container = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(_Profiles(role)),
          signedInUserIdProvider.overrideWith((ref) => userId),
        ],
      );
      addTearDown(container.dispose);
      container.listen(isSellerProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return container.read(isSellerProvider);
    }

    test('true for a signed in seller', () async {
      expect(await readIsSeller(UserRole.seller), isTrue);
    });

    test('false for a buyer', () async {
      expect(await readIsSeller(UserRole.buyer), isFalse);
    });

    test('false for a visitor', () async {
      expect(await readIsSeller(UserRole.seller, userId: null), isFalse);
    });
  });
}
