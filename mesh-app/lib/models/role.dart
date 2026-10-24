/// Ordered lowest to highest: each role can do everything the ones before it can.
enum Role {
  client('Client'),
  manager('Manager'),
  admin('Admin');

  const Role(this.label);

  final String label;

  bool atLeast(Role other) => index >= other.index;
}
