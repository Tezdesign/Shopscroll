import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_app/data/models/seller_application_request.dart';
import 'package:marketplace_app/data/repositories/seller_application_repository.dart';
import 'package:marketplace_app/data/repositories/supabase/supabase_seller_application_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records what the client sends and answers every call with a JSON string,
/// which is what both the rpc and the Storage upload need to succeed.
class _RecordingHttp extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final body = request.url.path.contains('/rpc/')
        ? '"a1"'
        : '{"Key":"visitor-documents/x","Id":"1"}';
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

/// A token whose `sub` is [sub], the way `currentSessionUserId` reads it.
String _jwtFor(String sub) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'sub': sub})}.sig';
}

void main() {
  group('sellerApplicationFailureFor', () {
    const expected = {
      'no_session': SellerApplicationFailure.noSession,
      'no_profile': SellerApplicationFailure.noProfile,
      'already_seller': SellerApplicationFailure.alreadySeller,
      'already_open': SellerApplicationFailure.alreadyOpen,
      'invalid_field': SellerApplicationFailure.invalidField,
      'username_taken': SellerApplicationFailure.usernameTaken,
      'missing_document': SellerApplicationFailure.missingDocument,
      'file_not_found': SellerApplicationFailure.fileNotFound,
    };

    for (final entry in expected.entries) {
      test('${entry.key} maps to ${entry.value.name}', () {
        expect(sellerApplicationFailureFor(entry.key), entry.value);
      });
    }

    test('any other message maps to failed', () {
      expect(
        sellerApplicationFailureFor('connection reset'),
        SellerApplicationFailure.failed,
      );
    });
  });

  group('visitor applications (spec 0014)', () {
    late _RecordingHttp recorder;
    late SupabaseClient client;
    late SupabaseSellerApplicationRepository repository;

    setUp(() {
      recorder = _RecordingHttp();
      client = SupabaseClient(
        'http://localhost',
        'key',
        httpClient: recorder,
        accessToken: () async => _jwtFor('anon_1'),
      );
      repository = SupabaseSellerApplicationRepository(client);
    });

    const visitor = ApplicantContact(
      name: 'Visitor One',
      email: 'v@example.com',
      phone: '+21612345678',
    );

    SellerApplicationRequest request({
      ApplicantContact? applicant,
      String? personalEmail,
    }) => SellerApplicationRequest(
      id: 'a1',
      storeName: 'Shop',
      username: 'shop_1',
      location: 'Tunis',
      idDocumentPath: 'anon_1/a1/id-x.jpg',
      applicant: applicant,
      personalEmail: personalEmail,
    );

    test(
      'a visitor submit calls submit_visitor_application with the contact',
      () async {
        await repository.submit(request(applicant: visitor));

        final call = recorder.requests.single;
        expect(call.url.path, '/rest/v1/rpc/submit_visitor_application');
        final body =
            jsonDecode((call as http.Request).body) as Map<String, dynamic>;
        expect(body['p_applicant_name'], 'Visitor One');
        expect(body['p_applicant_email'], 'v@example.com');
        expect(body['p_applicant_phone'], '+21612345678');
        expect(body['p_id'], 'a1');
        expect(body['p_id_document_path'], 'anon_1/a1/id-x.jpg');
      },
    );

    test(
      'a signed in submit still calls submit_seller_application with no contact',
      () async {
        await repository.submit(request());

        final call = recorder.requests.single;
        expect(call.url.path, '/rest/v1/rpc/submit_seller_application');
        expect(
          (jsonDecode((call as http.Request).body) as Map<String, dynamic>)
              .keys,
          isNot(contains('p_applicant_name')),
        );
      },
    );

    test(
      'a signed in submit sends the personal email only when given (spec 0017)',
      () async {
        await repository.submit(request(personalEmail: 'me@example.com'));
        await repository.submit(request());

        Map<String, dynamic> body(http.BaseRequest r) =>
            jsonDecode((r as http.Request).body) as Map<String, dynamic>;
        expect(
          body(recorder.requests[0])['p_applicant_email'],
          'me@example.com',
        );
        expect(
          body(recorder.requests[1]).keys,
          isNot(contains('p_applicant_email')),
        );
      },
    );

    test(
      'visitor photos go to visitor-documents as <session>/<application>/<kind>-<name>',
      () async {
        final paths = <SellerApplicationPhoto, String>{};
        for (final photo in SellerApplicationPhoto.values) {
          paths[photo] = await repository.uploadPhoto(
            applicationId: 'a1',
            photo: photo,
            bytes: Uint8List.fromList([1, 2, 3]),
            extension: 'png',
            asVisitor: true,
          );
        }

        expect(
          paths[SellerApplicationPhoto.idDocument],
          matches(RegExp(r'^anon_1/a1/id-[0-9a-f]{24}\.png$')),
        );
        expect(
          paths[SellerApplicationPhoto.businessDocument],
          matches(RegExp(r'^anon_1/a1/business-[0-9a-f]{24}\.png$')),
        );
        expect(
          paths[SellerApplicationPhoto.logo],
          matches(RegExp(r'^anon_1/a1/logo-[0-9a-f]{24}\.png$')),
        );
        expect(
          recorder.requests.every(
            (r) =>
                r.url.path.startsWith('/storage/v1/object/visitor-documents/'),
          ),
          isTrue,
        );
      },
    );

    test('a signed in photo still goes to its own bucket', () async {
      await repository.uploadPhoto(
        applicationId: 'a1',
        photo: SellerApplicationPhoto.logo,
        bytes: Uint8List.fromList([1]),
        extension: 'jpg',
      );

      expect(
        recorder.requests.single.url.path,
        startsWith('/storage/v1/object/store-logos/anon_1/'),
      );
    });

    test('use_account maps to useAccount', () {
      expect(
        sellerApplicationFailureFor('use_account'),
        SellerApplicationFailure.useAccount,
      );
    });
  });
}
