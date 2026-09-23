class Teacher {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String telegram;
  final String? photoUrl;
  final String department;
  final List<String> groupIds;

  final bool showEmail;
  final bool showPhone;
  final bool showTelegram;

  const Teacher({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.telegram,
    required this.photoUrl,
    required this.department,
    required this.groupIds,
    required this.showEmail,
    required this.showPhone,
    required this.showTelegram,
  });

  factory Teacher.fromFirestore(String id, Map<String, dynamic> data) {
    return Teacher(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      telegram: data['telegram'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      department: data['department'] as String? ?? '',
      groupIds: List<String>.from(data['groupIds'] ?? const []),
      showEmail: data['showEmail'] as bool? ?? true,
      showPhone: data['showPhone'] as bool? ?? true,
      showTelegram: data['showTelegram'] as bool? ?? true,
    );
  }
}
