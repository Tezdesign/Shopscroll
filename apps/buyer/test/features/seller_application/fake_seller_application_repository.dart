import 'dart:async';
import 'dart:typed_data';

import 'package:marketplace_app/data/models/seller_application_request.dart';
import 'package:marketplace_app/data/repositories/seller_application_repository.dart';
import 'package:shopscroll_shared/models/seller_application.dart';

/// A repository that records what the screens send. [submitError] and
/// [uploadError] make the next calls fail, [gate] holds a submit open so a
/// test can tap twice while it is in flight.
class FakeSellerApplicationRepository implements SellerApplicationRepository {
  FakeSellerApplicationRepository({this.applications = const []});

  List<SellerApplication> applications;
  SellerApplicationException? submitError;
  Object? uploadError;
  Completer<void>? gate;

  final submitted = <SellerApplicationRequest>[];
  final uploads = <SellerApplicationPhoto>[];

  @override
  Future<List<SellerApplication>> getMyApplications() async => applications;

  /// For each upload, whether it was the visitor path.
  final visitorUploads = <bool>[];

  @override
  Future<String> submit(SellerApplicationRequest request) async {
    await gate?.future;
    final error = submitError;
    if (error != null) throw error;
    submitted.add(request);
    return request.id;
  }

  @override
  Future<String> uploadPhoto({
    required String applicationId,
    required SellerApplicationPhoto photo,
    required Uint8List bytes,
    required String extension,
    bool asVisitor = false,
  }) async {
    final error = uploadError;
    if (error != null) throw error;
    uploads.add(photo);
    visitorUploads.add(asVisitor);
    return 'user/$applicationId/${photo.name}-${uploads.length}.$extension';
  }
}
