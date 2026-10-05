import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/models/seller_application.dart';

void main() {
  final application = SellerApplication(
    id: 'a1',
    applicantId: 'user_1',
    status: SellerApplicationStatus.rejected,
    storeName: 'My Shop',
    username: 'my_shop',
    bio: 'Hello',
    location: 'Tunis',
    contactEmail: 'shop@example.com',
    logoPath: 'user_1/logo.png',
    idDocumentPath: 'user_1/a1/id.jpg',
    rejectionReason: 'Blurry photo',
    reviewedAt: DateTime.utc(2026, 10, 3),
    createdAt: DateTime.utc(2026, 10, 2),
  );

  test('round-trips through toJson and fromJson', () {
    final copy = SellerApplication.fromJson(application.toJson());

    expect(copy.toJson(), application.toJson());
    expect(copy.status, SellerApplicationStatus.rejected);
    expect(copy.reviewedAt, application.reviewedAt);
  });

  test('keeps optional fields null through the round trip', () {
    final minimal = SellerApplication(
      id: 'a2',
      applicantId: 'user_2',
      status: SellerApplicationStatus.reviewing,
      storeName: 'Shop',
      username: 'shop',
      location: 'Sfax',
      idDocumentPath: 'user_2/a2/id.jpg',
      createdAt: DateTime.utc(2026, 10, 2),
    );

    final copy = SellerApplication.fromJson(minimal.toJson());

    expect(copy.bio, isNull);
    expect(copy.logoPath, isNull);
    expect(copy.rejectionReason, isNull);
    expect(copy.reviewedAt, isNull);
  });

  test('copyWith changes only what is given and keeps id and applicant', () {
    final approved = application.copyWith(
      status: SellerApplicationStatus.approved,
    );

    expect(approved.status, SellerApplicationStatus.approved);
    expect(approved.storeName, 'My Shop');
    expect(approved.id, 'a1');
    expect(approved.applicantId, 'user_1');
  });
}
