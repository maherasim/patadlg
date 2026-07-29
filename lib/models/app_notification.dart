class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.message,
    this.from,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as int,
        type: json['type'] as String? ?? '',
        message: json['message'] as String? ?? '',
        from: json['from'] as String?,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  final int id;
  final String type;
  final String message;
  final String? from;
  final bool read;
  final DateTime createdAt;
}
