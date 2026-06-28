enum MessageStatus {
  sent,
  delivered,
  read;

  static MessageStatus fromJson(String value) {
    return switch (value) {
      'SENT' => MessageStatus.sent,
      'DELIVERED' => MessageStatus.delivered,
      'READ' => MessageStatus.read,
      _ => MessageStatus.sent,
    };
  }
}

class ConversationUser {
  const ConversationUser({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? avatarUrl;

  factory ConversationUser.fromJson(Map<String, dynamic> json) {
    return ConversationUser(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class LastMessage {
  const LastMessage({
    required this.id,
    this.content,
    this.photoUrl,
    required this.senderId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String? content;
  final String? photoUrl;
  final String senderId;
  final MessageStatus status;
  final DateTime createdAt;

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      id: json['id'] as String,
      content: json['content'] as String?,
      photoUrl: json['photoUrl'] as String?,
      senderId: json['senderId'] as String,
      status: MessageStatus.fromJson(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
  });

  final String id;
  final ConversationUser otherUser;
  final LastMessage? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      otherUser: ConversationUser.fromJson(
        json['otherUser'] as Map<String, dynamic>,
      ),
      lastMessage: json['lastMessage'] != null
          ? LastMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.photoUrl,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final String? photoUrl;
  final MessageStatus status;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String?,
      photoUrl: json['photoUrl'] as String?,
      status: MessageStatus.fromJson(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class MessagesPage {
  const MessagesPage({
    required this.messages,
    this.nextCursor,
    required this.hasMore,
  });

  final List<Message> messages;
  final String? nextCursor;
  final bool hasMore;

  factory MessagesPage.fromJson(Map<String, dynamic> json) {
    return MessagesPage(
      messages: (json['messages'] as List<dynamic>)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool,
    );
  }
}

class MarkReadResult {
  const MarkReadResult({
    required this.readUpToMessageId,
    required this.updatedCount,
  });

  final String readUpToMessageId;
  final int updatedCount;

  factory MarkReadResult.fromJson(Map<String, dynamic> json) {
    return MarkReadResult(
      readUpToMessageId: json['readUpToMessageId'] as String,
      updatedCount: json['updatedCount'] as int,
    );
  }
}
