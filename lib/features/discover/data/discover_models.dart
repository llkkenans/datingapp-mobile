class DiscoverAuthor {
  const DiscoverAuthor({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? avatarUrl;

  factory DiscoverAuthor.fromJson(Map<String, dynamic> json) {
    return DiscoverAuthor(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class DiscoverPost {
  const DiscoverPost({
    required this.id,
    required this.author,
    this.caption,
    this.photoUrl,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
  });

  final String id;
  final DiscoverAuthor author;
  final String? caption;
  final String? photoUrl;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool liked;

  factory DiscoverPost.fromJson(Map<String, dynamic> json) {
    return DiscoverPost(
      id: json['id'] as String,
      author: DiscoverAuthor.fromJson(json['author'] as Map<String, dynamic>),
      caption: json['caption'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      likeCount: json['likeCount'] as int,
      commentCount: json['commentCount'] as int,
      liked: json['liked'] as bool,
    );
  }

  DiscoverPost copyWith({
    bool? liked,
    int? likeCount,
    int? commentCount,
  }) {
    return DiscoverPost(
      id: id,
      author: author,
      caption: caption,
      photoUrl: photoUrl,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      liked: liked ?? this.liked,
    );
  }
}

class DiscoverComment {
  const DiscoverComment({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final DiscoverAuthor author;
  final String content;
  final DateTime createdAt;

  factory DiscoverComment.fromJson(Map<String, dynamic> json) {
    return DiscoverComment(
      id: json['id'] as String,
      author: DiscoverAuthor.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class FeedPage {
  const FeedPage({
    required this.items,
    this.nextCursor,
  });

  final List<DiscoverPost> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  factory FeedPage.fromJson(Map<String, dynamic> json) {
    return FeedPage(
      items: (json['items'] as List<dynamic>)
          .map((e) => DiscoverPost.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class CommentPage {
  const CommentPage({
    required this.items,
    this.nextCursor,
  });

  final List<DiscoverComment> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  factory CommentPage.fromJson(Map<String, dynamic> json) {
    return CommentPage(
      items: (json['items'] as List<dynamic>)
          .map((e) => DiscoverComment.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}
