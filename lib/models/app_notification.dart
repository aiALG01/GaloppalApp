class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.slotId,
  });

  final String id;
  final String userId;
  final String kind; // 'clock' | 'cal' | 'user'
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? slotId;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      kind: map['kind'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      slotId: map['slot_id'] as String?,
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    userId: userId,
    kind: kind,
    title: title,
    body: body,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    slotId: slotId,
  );

  /// Coarse relative-time label matching the prototype's "vor 12 Min" style.
  String relativeLabel() {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'jetzt';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std';
    if (diff.inDays == 1) return 'Gestern';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    return '${createdAt.day}.${createdAt.month}.${createdAt.year}';
  }
}
