import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/models/seller_application_request.dart';
import 'package:marketplace_app/data/repositories/mock/mock_seller_application_repository.dart';
import 'package:marketplace_app/data/repositories/seller_application_repository.dart';
import 'package:shopscroll_shared/models/seller_application.dart';

SellerApplicationRequest request({
  String id = 'a1',
  String storeName = 'My Shop',
  String username = 'my_shop',
  String location = 'Tunis',
  String idDocumentPath = 'user/a1/id.jpg',
}) => SellerApplicationRequest(
  id: id,
  storeName: storeName,
  username: username,
  location: location,
  idDocumentPath: idDocumentPath,
);

Matcher refusedWith(SellerApplicationFailure reason) => throwsA(
  isA<SellerApplicationException>().having((e) => e.reason, 'reason', reason),
);

void main() {
  late MockSellerApplicationRepository repository;

  setUp(() => repository = MockSellerApplicationRepository());

  test('starts with no applications', () async {
    expect(await repository.getMyApplications(), isEmpty);
  });

  test('submit creates a reviewing application, newest first', () async {
    final id = await repository.submit(request());
    final list = await repository.getMyApplications();

    expect(id, 'a1');
    expect(list.single.status, SellerApplicationStatus.reviewing);
    expect(list.single.storeName, 'My Shop');
  });

  test('the same id again is a retry and creates nothing', () async {
    await repository.submit(request());
    final id = await repository.submit(request(storeName: 'Other'));

    expect(id, 'a1');
    expect(await repository.getMyApplications(), hasLength(1));
  });

  test('a new id while one is reviewing is refused', () async {
    await repository.submit(request());

    expect(
      repository.submit(request(id: 'a2', username: 'other_shop')),
      refusedWith(SellerApplicationFailure.alreadyOpen),
    );
  });

  test('bad fields are refused', () {
    expect(
      repository.submit(request(storeName: 'S')),
      refusedWith(SellerApplicationFailure.invalidField),
    );
    expect(
      repository.submit(request(username: 'Bad Name')),
      refusedWith(SellerApplicationFailure.invalidField),
    );
    expect(
      repository.submit(request(location: '  ')),
      refusedWith(SellerApplicationFailure.invalidField),
    );
  });

  test('a missing ID document is refused', () {
    expect(
      repository.submit(request(idDocumentPath: ' ')),
      refusedWith(SellerApplicationFailure.missingDocument),
    );
  });
  test('uploadPhoto stores under the same folders the server allows', () async {
    final bytes = Uint8List(3);
    final logo = await repository.uploadPhoto(
      applicationId: 'a1',
      photo: SellerApplicationPhoto.logo,
      bytes: bytes,
      extension: 'png',
    );
    final id = await repository.uploadPhoto(
      applicationId: 'a1',
      photo: SellerApplicationPhoto.idDocument,
      bytes: bytes,
      extension: 'jpg',
    );
    final again = await repository.uploadPhoto(
      applicationId: 'a1',
      photo: SellerApplicationPhoto.idDocument,
      bytes: bytes,
      extension: 'jpg',
    );

    expect(logo, matches(RegExp(r'^mock-buyer/[0-9a-f]+\.png$')));
    expect(id, matches(RegExp(r'^mock-buyer/a1/id-[0-9a-f]+\.jpg$')));
    expect(again, isNot(id), reason: 'a retry never reuses a name');
  });

  group('visitor applications (spec 0014)', () {
    SellerApplicationRequest visitorRequest({
      String name = 'Visitor One',
      String email = 'v@example.com',
      String phone = '+21612345678',
    }) => SellerApplicationRequest(
      id: 'v1',
      storeName: 'My Shop',
      username: 'my_shop',
      location: 'Tunis',
      idDocumentPath: 'anon/v1/id.jpg',
      applicant: ApplicantContact(name: name, email: email, phone: phone),
    );

    test('accepts a valid visitor application', () async {
      expect(await repository.submit(visitorRequest()), 'v1');
    });

    test(
      'refuses a short name, a bad email and a phone not in international format',
      () async {
        for (final bad in [
          visitorRequest(name: 'V'),
          visitorRequest(email: 'nope'),
          visitorRequest(email: 'a@b'),
          visitorRequest(phone: '0612345678'),
          visitorRequest(phone: '+0612345678'),
          visitorRequest(phone: '+216 12'),
        ]) {
          await expectLater(
            repository.submit(bad),
            refusedWith(SellerApplicationFailure.invalidField),
          );
        }
      },
    );

    test(
      'uploads for a visitor are named <kind>-<name> under the application',
      () async {
        Future<String> upload(SellerApplicationPhoto photo) =>
            repository.uploadPhoto(
              applicationId: 'v1',
              photo: photo,
              bytes: Uint8List(1),
              extension: 'png',
              asVisitor: true,
            );

        expect(
          await upload(SellerApplicationPhoto.logo),
          contains('/v1/logo-'),
        );
        expect(
          await upload(SellerApplicationPhoto.idDocument),
          contains('/v1/id-'),
        );
        expect(
          await upload(SellerApplicationPhoto.businessDocument),
          contains('/v1/business-'),
        );
      },
    );
  });
}
