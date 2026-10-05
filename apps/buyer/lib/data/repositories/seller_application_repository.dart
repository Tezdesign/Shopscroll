import 'dart:typed_data';

import 'package:shopscroll_shared/models/seller_application.dart';

import '../models/seller_application_request.dart';

/// Why [SellerApplicationRepository.submit] failed (spec 0013). One value per
/// error the `submit_seller_application` SQL function raises, so the wizard
/// can say what to fix. [failed] is any other failure, like no network.
enum SellerApplicationFailure {
  noSession,
  noProfile,
  alreadySeller,
  alreadyOpen,
  invalidField,
  usernameTaken,
  missingDocument,
  fileNotFound,

  /// A signed in account tried the visitor path (spec 0014).
  useAccount,
  failed,
}

class SellerApplicationException implements Exception {
  const SellerApplicationException(this.reason);

  final SellerApplicationFailure reason;

  @override
  String toString() => 'SellerApplicationException($reason)';
}

/// Which photo [SellerApplicationRepository.uploadPhoto] stores: the logo goes
/// to the public `store-logos` bucket, the two documents to the private
/// `application-documents` bucket (spec 0013). A visitor's three photos all go
/// to the private `visitor-documents` bucket (spec 0014).
enum SellerApplicationPhoto { logo, idDocument, businessDocument }

/// Access to the signed in person's own seller applications. See
/// product_repository.dart for the mock/Supabase swap pattern.
abstract class SellerApplicationRepository {
  /// As if fetched from `GET /seller-applications`: the caller's own
  /// applications, newest first. Empty when there are none.
  Future<List<SellerApplication>> getMyApplications();

  /// As if sent to `POST /seller-applications` (or, with
  /// [SellerApplicationRequest.applicant], to `POST /visitor-applications`).
  /// Creates the application as `reviewing` and returns its id. Sending the same
  /// [SellerApplicationRequest.id] again returns that id and changes nothing.
  /// Throws a [SellerApplicationException] when nothing was created.
  Future<String> submit(SellerApplicationRequest request);

  /// As if sent to `POST /seller-applications/:id/files`. Stores one photo
  /// under the caller's own folder and returns its path, to pass to [submit].
  /// [extension] is `jpg` or `png`. With [asVisitor] the photo goes to the
  /// visitor's own session folder (spec 0014). Every call stores under a new random
  /// name, so a retry or a replaced photo never overwrites a file. Throws a
  /// [SellerApplicationException] when the upload fails.
  Future<String> uploadPhoto({
    required String applicationId,
    required SellerApplicationPhoto photo,
    required Uint8List bytes,
    required String extension,
    bool asVisitor = false,
  });
}
