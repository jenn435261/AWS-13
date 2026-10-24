import 'role.dart';

class AppUser {
  const AppUser({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final Role role;

  AppUser copyWith({String? name, Role? role}) =>
      AppUser(id: id, name: name ?? this.name, role: role ?? this.role);
}
