import 'dart:math';
import 'dart:typed_data';

import 'package:shopscroll_shared/models/seller_application.dart';

import '../../models/seller_application_request.dart';
import '../../providers/network_delay.dart';
import '../seller_application_repository.dart';

/// Keeps applications in memory for the run of the app, starting empty so the
/// screen opens on its empty state. Refuses the same bad input as the
/// `submit_seller_application` SQL function (field rules, one reviewing
/// application, same id is a retry, and for a visitor the name, email and
/// phone rules of `submit_visitor_application`). It cannot check files or other people's
/// usernames, and nothing ever approves or rejects, there is no admin here.
class MockSellerApplicationRepository implements SellerApplicationRepository {
  static const _applicantId = 'mock-buyer';
  static final _usernamePattern = RegExp(r'^[a-z0-9_.]{3,30}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phonePattern = RegExp(r'^\+[1-9][0-9]{6,14}$');

  final List<SellerApplication> _applications = [];

  @override
  Future<List<SellerApplication>> getMyApplications() async {
    await Future.delayed(mockNetworkDelay);
    return List.of(_applications.reversed);
  }

  @override
  Future<String> submit(SellerApplicationRequest request) async {
    await Future.delayed(mockNetworkDelay);

    for (final application in _applications) {
      if (application.id == request.id) return application.id;
    }
    if (_applications.any(
      (a) => a.status == SellerApplicationStatus.reviewing,
    )) {
      throw const SellerApplicationException(
        SellerApplicationFailure.alreadyOpen,
      );
    }

    final storeName = request.storeName.trim();
    if (storeName.length < 2 ||
        storeName.length > 60 ||
        !_usernamePattern.hasMatch(request.username) ||
        request.location.trim().isEmpty ||
        (request.bio?.length ?? 0) > 280) {
      throw const SellerApplicationException(
        SellerApplicationFailure.invalidField,
      );
    }
    final applicant = request.applicant;
    if (applicant != null &&
        (applicant.name.trim().length < 2 ||
            applicant.name.trim().length > 60 ||
            !_emailPattern.hasMatch(applicant.email.trim()) ||
            !_phonePattern.hasMatch(applicant.phone.trim()))) {
      throw const SellerApplicationException(
        SellerApplicationFailure.invalidField,
      );
    }
    if (request.idDocumentPath.trim().isEmpty) {
      throw const SellerApplicationException(
        SellerApplicationFailure.missingDocument,
      );
    }

    _applications.add(
      SellerApplication(
        id: request.id,
        applicantId: _applicantId,
        status: SellerApplicationStatus.reviewing,
        storeName: storeName,
        username: request.username,
        bio: request.bio,
        location: request.location.trim(),
        websiteUrl: request.websiteUrl,
        contactPhone: request.contactPhone,
        contactEmail: request.contactEmail,
        logoPath: request.logoPath,
        idDocumentPath: request.idDocumentPath,
        businessDocumentPath: request.businessDocumentPath,
        createdAt: DateTime.now(),
      ),
    );
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
    await Future.delayed(mockNetworkDelay);
    final name = '${Random().nextInt(1 << 32).toRadixString(16)}.$extension';
    if (asVisitor) {
      final kind = switch (photo) {
        SellerApplicationPhoto.logo => 'logo',
        SellerApplicationPhoto.idDocument => 'id',
        SellerApplicationPhoto.businessDocument => 'business',
      };
      return '$_applicantId/$applicationId/$kind-$name';
    }
    return switch (photo) {
      SellerApplicationPhoto.logo => '$_applicantId/$name',
      SellerApplicationPhoto.idDocument =>
        '$_applicantId/$applicationId/id-$name',
      SellerApplicationPhoto.businessDocument =>
        '$_applicantId/$applicationId/business-$name',
    };
  }
}
