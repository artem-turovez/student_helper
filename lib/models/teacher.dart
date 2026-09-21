class Teacher {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String telegram;
  final String? photoUrl;
  final String department;
  final List<String> groupIds;

  const Teacher({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.telegram,
    required this.photoUrl,
    required this.department,
    required this.groupIds,
  });

  factory Teacher.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return Teacher(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      telegram: data['telegram'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      department:
          data['department'] as String? ?? '',
      groupIds: List<String>.from(
        data['groupIds'] ?? const [],
      ),
    );
  }
}