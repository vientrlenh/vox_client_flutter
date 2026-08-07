class SchoolClass {
  final String id;
  final String name;
  final String? status;

  const SchoolClass({required this.id, required this.name, this.status});

  factory SchoolClass.fromJson(Map<String, dynamic> json) {
    return SchoolClass(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String?,
    );
  }
}
