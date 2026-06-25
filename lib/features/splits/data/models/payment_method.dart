class PaymentMethod {
  final String label;
  final String value;

  const PaymentMethod({required this.label, required this.value});

  Map<String, String> toMap() => {'label': label, 'value': value};

  factory PaymentMethod.fromMap(Map<String, dynamic> map) => PaymentMethod(
        label: map['label'] as String,
        value: map['value'] as String,
      );
}
