/// Where a seller application stands (spec 0013). Only an admin moves it, from
/// [reviewing] to [approved] or [rejected], and both are final for that row.
enum SellerApplicationStatus { reviewing, approved, rejected }

/// One request to become a seller (spec 0013), as read from the
/// `seller_applications` table. [applicantId] is null for a visitor's
/// application that was attached to the account but not claimed yet (spec
/// 0014): the claim fills it. The ID and business document paths are kept so
/// the model matches the row, but no screen shows or links them: they are
/// personal data and stay private.
class SellerApplication {
  const SellerApplication({
    required this.id,
    this.applicantId,
    required this.status,
    required this.storeName,
    required this.username,
    this.bio,
    required this.location,
    this.websiteUrl,
    this.contactPhone,
    this.contactEmail,
    this.logoPath,
    required this.idDocumentPath,
    this.businessDocumentPath,
    this.rejectionReason,
    this.reviewedAt,
    required this.createdAt,
  });

  final String id;
  final String? applicantId;
  final SellerApplicationStatus status;
  final String storeName;
  final String username;
  final String? bio;
  final String location;
  final String? websiteUrl;
  final String? contactPhone;
  final String? contactEmail;

  /// Path in the public `store-logos` bucket, null when no logo was added.
  final String? logoPath;

  /// Path in the private `application-documents` bucket.
  final String idDocumentPath;
  final String? businessDocumentPath;

  /// Why it was rejected. Set only when [status] is
  /// [SellerApplicationStatus.rejected].
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  factory SellerApplication.fromJson(Map<String, dynamic> json) {
    return SellerApplication(
      id: json['id'] as String,
      applicantId: json['applicantId'] as String?,
      status: SellerApplicationStatus.values.byName(json['status'] as String),
      storeName: json['storeName'] as String,
      username: json['username'] as String,
      bio: json['bio'] as String?,
      location: json['location'] as String,
      websiteUrl: json['websiteUrl'] as String?,
      contactPhone: json['contactPhone'] as String?,
      contactEmail: json['contactEmail'] as String?,
      logoPath: json['logoPath'] as String?,
      idDocumentPath: json['idDocumentPath'] as String,
      businessDocumentPath: json['businessDocumentPath'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'applicantId': applicantId,
    'status': status.name,
    'storeName': storeName,
    'username': username,
    'bio': bio,
    'location': location,
    'websiteUrl': websiteUrl,
    'contactPhone': contactPhone,
    'contactEmail': contactEmail,
    'logoPath': logoPath,
    'idDocumentPath': idDocumentPath,
    'businessDocumentPath': businessDocumentPath,
    'rejectionReason': rejectionReason,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  SellerApplication copyWith({
    SellerApplicationStatus? status,
    String? storeName,
    String? username,
    String? bio,
    String? location,
    String? websiteUrl,
    String? contactPhone,
    String? contactEmail,
    String? logoPath,
    String? idDocumentPath,
    String? businessDocumentPath,
    String? rejectionReason,
    DateTime? reviewedAt,
  }) {
    return SellerApplication(
      id: id,
      applicantId: applicantId,
      status: status ?? this.status,
      storeName: storeName ?? this.storeName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      logoPath: logoPath ?? this.logoPath,
      idDocumentPath: idDocumentPath ?? this.idDocumentPath,
      businessDocumentPath: businessDocumentPath ?? this.businessDocumentPath,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt,
    );
  }
}
