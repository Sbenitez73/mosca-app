class SplitContact {
  final String name;
  final String? phone;

  const SplitContact({required this.name, this.phone});

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};

  factory SplitContact.fromMap(Map<String, dynamic> map) => SplitContact(
        name: map['name'] as String,
        phone: map['phone'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is SplitContact && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(name, phone);
}
