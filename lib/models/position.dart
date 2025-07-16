class Position {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int userId;

  Position({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.userId,
  });

  factory Position.fromJson(Map<String, dynamic> json) => Position(
    id: json['id'],
    name: json['name'],
    latitude: json['latitude'],
    longitude: json['longitude'],
    userId: json['user_id'],
  );
}