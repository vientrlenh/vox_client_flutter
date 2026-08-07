class Profile {
  final String id;
  final String email;
  final String phone;
  final String? fullName;
  final String? gender;
  final String? dateOfBirth;
  final String? address;
  final String? avatarUrl;
  final String? schoolId;
  final String? schoolName;
  final String? role;
  final String? roleCode;

  const Profile({
    required this.id,
    required this.email,
    required this.phone,
    this.fullName,
    this.gender,
    this.dateOfBirth,
    this.address,
    this.avatarUrl,
    this.schoolId,
    this.schoolName,
    this.role,
    this.roleCode,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final roles = json['roles'] as List<dynamic>?;
    final firstRole = roles != null && roles.isNotEmpty
        ? roles.first as Map<String, dynamic>
        : null;
    final school = json['school'] as Map<String, dynamic>?;
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      fullName: json['fullName'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      address: json['address'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      schoolId: school?['id'] as String?,
      schoolName: school?['name'] as String?,
      role: (firstRole?['name'] as String?) ?? (firstRole?['code'] as String?),
      roleCode: firstRole?['code'] as String?,
    );
  }
}
