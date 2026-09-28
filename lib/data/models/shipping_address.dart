/// Where an order is delivered (spec 0009). The country is fixed to Tunisia
/// for now, the design has no country field. [note] is optional.
class ShippingAddress {
  const ShippingAddress({
    this.country = 'Tunisia',
    required this.city,
    required this.address,
    required this.zip,
    this.note = '',
  });

  final String country;
  final String city;
  final String address;
  final String zip;
  final String note;

  /// The one line the Checkout and the confirmation show: `18 rue, menzah, 0000`.
  String get line => '$address, $city, $zip';

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      country: json['country'] as String? ?? 'Tunisia',
      city: json['city'] as String,
      address: json['address'] as String,
      zip: json['zip'] as String,
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'country': country,
    'city': city,
    'address': address,
    'zip': zip,
    'note': note,
  };

  ShippingAddress copyWith({
    String? country,
    String? city,
    String? address,
    String? zip,
    String? note,
  }) {
    return ShippingAddress(
      country: country ?? this.country,
      city: city ?? this.city,
      address: address ?? this.address,
      zip: zip ?? this.zip,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShippingAddress &&
      other.country == country &&
      other.city == city &&
      other.address == address &&
      other.zip == zip &&
      other.note == note;

  @override
  int get hashCode => Object.hash(country, city, address, zip, note);
}
