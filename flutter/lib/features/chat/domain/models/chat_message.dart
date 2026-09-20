class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final String? storyMediaUrl;
  final String? storyId;
  final Map<String, String> reactions; // key: userId, value: emoji character

  // Rich messaging fields
  final String type; // 'text', 'emoji', 'gif', 'shared_post', 'shared_reel', 'shared_profile', 'shared_event', 'image'
  final String? conversationId;
  final String? referencedPostId;
  final String? referencedReelId;
  final String? referencedUserId;
  final String? referencedEventId;
  final String? gifProvider;
  final String? gifUrl;
  final String? gifId;
  final String messageState; // 'sending', 'sent', 'delivered', 'seen', 'failed'
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  // Discrete local and delivery state tracking
  final String? localState; // 'LOCAL_PENDING', 'UPLOADING', 'READY_TO_SEND', 'SENT', 'FAILED'
  final String? deliveryState; // 'PENDING', 'SENT', 'DELIVERED', 'READ'
  final double uploadProgress;
  final String? localFilePath;

  // Swipe-to-Reply & Quoting support
  final String? replyToMessageId;
  final String? replyToSenderName;
  final String? replyToContent;

  // Forwarding support
  final bool isForwarded;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.storyMediaUrl,
    this.storyId,
    this.reactions = const {},
    this.type = 'text',
    this.conversationId,
    this.referencedPostId,
    this.referencedReelId,
    this.referencedUserId,
    this.referencedEventId,
    this.gifProvider,
    this.gifUrl,
    this.gifId,
    this.messageState = 'sent',
    this.updatedAt,
    this.deletedAt,
    this.localState,
    this.deliveryState,
    this.uploadProgress = 0.0,
    this.localFilePath,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToContent,
    this.isForwarded = false,
  });

  bool get isFailed => messageState == 'failed' || localState == 'FAILED';
  bool get isSending => messageState == 'sending' || localState == 'LOCAL_PENDING' || localState == 'UPLOADING';
  bool get isSent => messageState == 'sent' || localState == 'SENT';
  bool get isDelivered => messageState == 'delivered' || deliveryState == 'DELIVERED';
  bool get isSeen => messageState == 'seen' || deliveryState == 'READ';

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    String? storyMediaUrl,
    String? storyId,
    Map<String, String>? reactions,
    String? type,
    String? conversationId,
    String? referencedPostId,
    String? referencedReelId,
    String? referencedUserId,
    String? referencedEventId,
    String? gifProvider,
    String? gifUrl,
    String? gifId,
    String? messageState,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? localState,
    String? deliveryState,
    double? uploadProgress,
    String? localFilePath,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToContent,
    bool? isForwarded,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      storyMediaUrl: storyMediaUrl ?? this.storyMediaUrl,
      storyId: storyId ?? this.storyId,
      reactions: reactions ?? this.reactions,
      type: type ?? this.type,
      conversationId: conversationId ?? this.conversationId,
      referencedPostId: referencedPostId ?? this.referencedPostId,
      referencedReelId: referencedReelId ?? this.referencedReelId,
      referencedUserId: referencedUserId ?? this.referencedUserId,
      referencedEventId: referencedEventId ?? this.referencedEventId,
      gifProvider: gifProvider ?? this.gifProvider,
      gifUrl: gifUrl ?? this.gifUrl,
      gifId: gifId ?? this.gifId,
      messageState: messageState ?? this.messageState,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      localState: localState ?? this.localState,
      deliveryState: deliveryState ?? this.deliveryState,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      localFilePath: localFilePath ?? this.localFilePath,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToContent: replyToContent ?? this.replyToContent,
      isForwarded: isForwarded ?? this.isForwarded,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'storyMediaUrl': storyMediaUrl,
      'storyId': storyId,
      'reactions': reactions,
      'type': type,
      'conversationId': conversationId,
      'referencedPostId': referencedPostId,
      'referencedReelId': referencedReelId,
      'referencedUserId': referencedUserId,
      if (referencedEventId != null) 'referencedEventId': referencedEventId,
      'gifProvider': gifProvider,
      'gifUrl': gifUrl,
      'gifId': gifId,
      'messageState': messageState,
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      if (localState != null) 'localState': localState,
      if (deliveryState != null) 'deliveryState': deliveryState,
      if (localFilePath != null) 'localFilePath': localFilePath,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      if (replyToContent != null) 'replyToContent': replyToContent,
      if (isForwarded) 'isForwarded': isForwarded,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    final rawReactions = map['reactions'];
    final parsedReactions = <String, String>{};
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        parsedReactions[key.toString()] = value.toString();
      });
    }

    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      storyMediaUrl: map['storyMediaUrl'],
      storyId: map['storyId'],
      reactions: parsedReactions,
      type: map['type'] ?? 'text',
      conversationId: map['conversationId'],
      referencedPostId: map['referencedPostId'],
      referencedReelId: map['referencedReelId'],
      referencedUserId: map['referencedUserId'],
      referencedEventId: map['referencedEventId'],
      gifProvider: map['gifProvider'],
      gifUrl: map['gifUrl'],
      gifId: map['gifId'],
      messageState: map['messageState'] ?? 'sent',
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
      deletedAt: map['deletedAt'] != null ? DateTime.tryParse(map['deletedAt'].toString()) : null,
      localState: map['localState'],
      deliveryState: map['deliveryState'],
      localFilePath: map['localFilePath'],
      replyToMessageId: map['replyToMessageId'],
      replyToSenderName: map['replyToSenderName'],
      replyToContent: map['replyToContent'],
      isForwarded: map['isForwarded'] == true,
    );
  }
}
