/// Who is buying and how to reach them, given at checkout (spec 0009).
/// [phone] is the whole number with its dial code, like `+21650460604`.
class ContactInfo {
  const ContactInfo({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;
  final String phone;

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
  };

  ContactInfo copyWith({String? name, String? email, String? phone}) {
    return ContactInfo(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ContactInfo &&
      other.name == name &&
      other.email == email &&
      other.phone == phone;

  @override
  int get hashCode => Object.hash(name, email, phone);
}
