import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/repositories/supabase/row_mappers.dart';
import 'package:shopscroll_shared/models/seller_application.dart';

void main() {
  const projectUrl = 'https://abc.supabase.co';

  Map<String, dynamic> profileRow(String? avatarUrl) => {
    'id': 'user_1',
    'name': 'Shop',
    'username': 'shop',
    'avatar_url': avatarUrl,
    'role': 'seller',
  };

  group('userProfileFromRow avatar_url (spec 0013, AC-12)', () {
    test('a full URL renders as it did before', () {
      final profile = userProfileFromRow(
        profileRow('https://example.com/a.png'),
        projectUrl: projectUrl,
      );

      expect(profile.avatarUrl, 'https://example.com/a.png');
    });

    test('null stays null', () {
      final profile = userProfileFromRow(
        profileRow(null),
        projectUrl: projectUrl,
      );

      expect(profile.avatarUrl, isNull);
    });

    test('a bucket relative path becomes a public Storage URL', () {
      final profile = userProfileFromRow(
        profileRow('store-logos/user_1/logo-1.png'),
        projectUrl: projectUrl,
      );

      expect(
        profile.avatarUrl,
        'https://abc.supabase.co/storage/v1/object/public/store-logos/user_1/logo-1.png',
      );
    });
  });

  group('sellerApplicationFromRow', () {
    test('maps a rejected row and its optional columns', () {
      final application = sellerApplicationFromRow({
        'id': 'a1',
        'applicant_id': 'user_1',
        'status': 'rejected',
        'store_name': 'My Shop',
        'username': 'my_shop',
        'bio': null,
        'location': 'Tunis',
        'website_url': null,
        'contact_phone': '+216',
        'contact_email': null,
        'logo_path': null,
        'id_document_path': 'user_1/a1/id.jpg',
        'business_document_path': null,
        'rejection_reason': 'Blurry photo',
        'reviewed_at': '2026-10-03T10:00:00+00:00',
        'created_at': '2026-10-02T10:00:00+00:00',
      });

      expect(application.status, SellerApplicationStatus.rejected);
      expect(application.rejectionReason, 'Blurry photo');
      expect(application.contactPhone, '+216');
      expect(application.logoPath, isNull);
      expect(application.reviewedAt, DateTime.utc(2026, 10, 3, 10));
    });
  });
}
