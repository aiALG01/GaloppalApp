/// An in-app feature proposal any signed-in user can post and up-/downvote.
class FeatureRequest {
  const FeatureRequest({
    required this.id,
    required this.authorId,
    required this.title,
    required this.createdAt,
    this.description,
    this.authorName,
  });

  final String id;
  final String authorId;
  final String title;
  final String? description;
  final DateTime createdAt;
  final String? authorName;

  factory FeatureRequest.fromMap(Map<String, dynamic> map) {
    final author = map['author'] as Map<String, dynamic>?;
    return FeatureRequest(
      id: map['id'] as String,
      authorId: map['author_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      authorName: author?['full_name'] as String?,
    );
  }
}
