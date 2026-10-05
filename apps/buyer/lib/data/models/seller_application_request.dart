/// The private contact details of a person who applies without an account
/// (spec 0014, AC-7). The team uses them to reach the applicant. They are never
/// copied to a profile and never used to find an account.
class ApplicantContact {
  const ApplicantContact({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;

  /// International format, `+` and the country code first, as the country
  /// picker produces it.
  final String phone;
}

/// What `POST /seller-applications` carries (spec 0013): the form fields and
/// the paths of the files the wizard already uploaded. [id] is made once per
/// application, so sending it again (a retry, a double tap) returns the same
/// application instead of a second one (AC-1). Optional fields left empty are
/// sent as null. [applicant] is set only when a visitor with no account
/// applies (spec 0014).
class SellerApplicationRequest {
  const SellerApplicationRequest({
    required this.id,
    required this.storeName,
    required this.username,
    required this.location,
    required this.idDocumentPath,
    this.bio,
    this.websiteUrl,
    this.contactPhone,
    this.contactEmail,
    this.logoPath,
    this.businessDocumentPath,
    this.applicant,
  });

  final String id;
  final String storeName;
  final String username;
  final String location;
  final String idDocumentPath;
  final String? bio;
  final String? websiteUrl;
  final String? contactPhone;
  final String? contactEmail;
  final String? logoPath;
  final String? businessDocumentPath;
  final ApplicantContact? applicant;
}
