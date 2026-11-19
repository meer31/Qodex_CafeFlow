class UserModel {
  final int? id;
  final String username;
  final String name;
  final String role; // Admin, Cashier, Manager
  final String pin;

  UserModel({
    this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.pin,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role,
      'pin': pin,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      pin: map['pin'] as String,
    );
  }
}
