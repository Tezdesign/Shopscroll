import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shopscroll_shared/models/seller_application.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/seller_application_request.dart';
import '../seller_application_repository.dart';
import 'row_mappers.dart';
import 'session_user_id.dart';

class SupabaseSellerApplicationRepository
    implements SellerApplicationRepository {
  SupabaseSellerApplicationRepository(this._client);

  final SupabaseClient _client;

  // No user filter: row level security already limits `seller_applications`
  // to the caller's own rows (spec 0013, AC-4).
  @override
  Future<List<SellerApplication>> getMyApplications() async {
    final rows = await _client
        .from('seller_applications')
        .select()
        .order('created_at', ascending: false);
    return rows.map(sellerApplicationFromRow).toList();
  }

  /// Calls the `submit_seller_application` Postgres function (see
  /// `supabase/migrations/0006_seller_applications.sql`), or for a visitor the
  /// `submit_visitor_application` one (`0007_visitor_applications.sql`), which
  /// checks every field and file path on the server and returns the
  /// application id.
  @override
  Future<String> submit(SellerApplicationRequest request) async {
    final applicant = request.applicant;
    try {
      final id = await _client.rpc(
        applicant == null
            ? 'submit_seller_application'
            : 'submit_visitor_application',
        params: {
          if (applicant != null) ...{
            'p_applicant_name': applicant.name,
            'p_applicant_email': applicant.email,
            'p_applicant_phone': applicant.phone,
          },
          'p_id': request.id,
          'p_store_name': request.storeName,
          'p_username': request.username,
          'p_location': request.location,
          'p_id_document_path': request.idDocumentPath,
          'p_bio': request.bio,
          'p_website_url': request.websiteUrl,
          'p_contact_phone': request.contactPhone,
          'p_contact_email': request.contactEmail,
          'p_logo_path': request.logoPath,
          'p_business_document_path': request.businessDocumentPath,
          // Sent only when given, so a backend without migration 0012 still
          // accepts every other submit (spec 0017, AC-8).
          if (applicant == null && request.personalEmail != null)
            'p_applicant_email': request.personalEmail,
        },
      );
      return id as String;
    } on PostgrestException catch (error) {
      debugPrint('seller application submit refused: ${error.message}');
      throw SellerApplicationException(
        sellerApplicationFailureFor(error.message),
      );
    } catch (error) {
      debugPrint('seller application submit failed: $error');
      throw const SellerApplicationException(SellerApplicationFailure.failed);
    }
  }

  /// Uploads to Storage under `<clerk id>/...`, the folder the bucket rules
  /// allow (spec 0013, AC-5): the logo as `<id>/<name>`, the documents as
  /// `<id>/<application id>/id-<name>` or `business-<name>`. A visitor's three
  /// photos go to `visitor-documents` under the anonymous session id, as
  /// `<session id>/<application id>/<kind>-<name>` (spec 0014, AC-9).
  @override
  Future<String> uploadPhoto({
    required String applicationId,
    required SellerApplicationPhoto photo,
    required Uint8List bytes,
    required String extension,
    bool asVisitor = false,
  }) async {
    final userId = await currentSessionUserId(_client);
    if (userId == null) {
      throw const SellerApplicationException(
        SellerApplicationFailure.noSession,
      );
    }
    final name = '${_randomName()}.$extension';
    final (bucket, path) = asVisitor
        ? (
            'visitor-documents',
            '$userId/$applicationId/${_visitorKind(photo)}-$name',
          )
        : switch (photo) {
            SellerApplicationPhoto.logo => ('store-logos', '$userId/$name'),
            SellerApplicationPhoto.idDocument => (
              'application-documents',
              '$userId/$applicationId/id-$name',
            ),
            SellerApplicationPhoto.businessDocument => (
              'application-documents',
              '$userId/$applicationId/business-$name',
            ),
          };
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );
      return path;
    } catch (error) {
      debugPrint('seller application upload to $bucket failed: $error');
      throw const SellerApplicationException(SellerApplicationFailure.failed);
    }
  }
}

/// The file name prefix of a visitor's photo, the `<kind>` in
/// `<session id>/<application id>/<kind>-<name>` that the submit function
/// checks (spec 0014, AC-8).
String _visitorKind(SellerApplicationPhoto photo) => switch (photo) {
  SellerApplicationPhoto.logo => 'logo',
  SellerApplicationPhoto.idDocument => 'id',
  SellerApplicationPhoto.businessDocument => 'business',
};

/// A random file name part, 12 bytes as hex. A new one per upload attempt, so
/// no file is ever overwritten (the buckets give clients no update or delete).
String _randomName() {
  final random = Random.secure();
  return List.generate(
    12,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// The function raises its reason as the whole error message. Public so a
/// test can pin each mapping.
SellerApplicationFailure sellerApplicationFailureFor(String message) {
  const reasons = {
    'no_session': SellerApplicationFailure.noSession,
    'no_profile': SellerApplicationFailure.noProfile,
    'already_seller': SellerApplicationFailure.alreadySeller,
    'already_open': SellerApplicationFailure.alreadyOpen,
    'invalid_field': SellerApplicationFailure.invalidField,
    'username_taken': SellerApplicationFailure.usernameTaken,
    'missing_document': SellerApplicationFailure.missingDocument,
    'file_not_found': SellerApplicationFailure.fileNotFound,
    'use_account': SellerApplicationFailure.useAccount,
  };
  for (final entry in reasons.entries) {
    if (message.contains(entry.key)) return entry.value;
  }
  return SellerApplicationFailure.failed;
}
