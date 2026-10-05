import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/repositories/supabase/row_mappers.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/seller_application.dart';

void main() {
  const projectUrl = 'https://abc.supabase.co';

  group('productFromRow (spec 0015)', () {
    Map<String, dynamic> productRow({Map<String, dynamic> extra = const {}}) => {
      'id': 'p1',
      'title': 'Dress',
      'description': 'd',
      'price': 70.25,
      'category': 'Fashion',
      'store_id': 's1',
      'store_name': 'Store',
      'created_at': '2026-10-05T10:00:00Z',
      ...extra,
    };

    test('reads currency, status, attributes and variants in position order', () {
      final product = productFromRow(
        productRow(extra: {
          'currency': 'TND',
          'status': 'archived',
          'attributes': {'material': 'cotton'},
          'variants': [
            {'id': 'v2', 'size': 'M', 'price': 95.5, 'stock': 6, 'position': 1},
            {'id': 'v1', 'size': 'S', 'color_value': 4288230400, 'price': 70.25, 'stock': 4, 'position': 0},
          ],
        }),
        projectUrl: projectUrl,
      );

      expect(product.currency, 'TND');
      expect(product.status, ProductStatus.archived);
      expect(product.attributes['material'], 'cotton');
      expect(product.variants.map((v) => v.id), ['v1', 'v2']);
      expect(product.variants.first.colorValue, 4288230400);
      expect(product.priceLabel, '70.250 TND');
    });

    test('a row without the new columns reads as a live TND product', () {
      final product = productFromRow(productRow(), projectUrl: projectUrl);

      expect(product.currency, 'TND');
      expect(product.status, ProductStatus.live);
      expect(product.variants, isEmpty);
    });

    test('a photo path becomes a public Storage URL and a full URL stays', () {
      final product = productFromRow(
        productRow(extra: {
          'image_url': 'product-images/u/p/a.jpg',
          'image_urls': ['product-images/u/p/a.jpg', 'https://example.com/b.jpg'],
        }),
        projectUrl: projectUrl,
      );

      expect(product.imageUrl, '$projectUrl/storage/v1/object/public/product-images/u/p/a.jpg');
      expect(product.imageUrls.last, 'https://example.com/b.jpg');
    });
  });

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
