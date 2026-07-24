class DummyNotification {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final String type;
  final String timestamp;
  final bool read;
  final String? targetId;

  const DummyNotification({
    required this.id,
    this.senderId = 'user_1',
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.type,
    required this.timestamp,
    required this.read,
    this.targetId,
  });

  DummyNotification copyWith({bool? read}) {
    return DummyNotification(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      text: text,
      type: type,
      timestamp: timestamp,
      read: read ?? this.read,
      targetId: targetId,
    );
  }
}

final List<DummyNotification> dummyNotifications = [
  const DummyNotification(
    id: 'notif_1',
    senderId: 'user_2',
    senderName: 'Coach David Miller',
    senderAvatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&q=80&w=200&h=200',
    text: 'sent you a direct message regarding your recruitment profile.',
    type: 'message',
    timestamp: 'Just now',
    read: false,
  ),
  const DummyNotification(
    id: 'notif_2',
    senderId: 'user_3',
    senderName: 'Austin Scout Combine',
    senderAvatar: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&q=80&w=200&h=200',
    text: 'invited you to register for the official Elite Underclassmen Showcase.',
    type: 'event',
    timestamp: '2 hours ago',
    read: false,
  ),
  const DummyNotification(
    id: 'notif_3',
    senderId: 'user_4',
    senderName: 'Sarah Jenkins',
    senderAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=200&h=200',
    text: 'liked your recent training drill highlight post.',
    type: 'like',
    timestamp: '1 day ago',
    read: true,
  )
];
