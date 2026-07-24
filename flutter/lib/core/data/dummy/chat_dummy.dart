import '../../models/mention_model.dart';

class DummyChatMessage {
  final String senderId;
  final String content;
  final String time;
  final List<MentionModel> mentions;

  const DummyChatMessage({
    required this.senderId,
    required this.content,
    required this.time,
    this.mentions = const [],
  });
}

final List<DummyChatMessage> dummyChatMessages = [
  const DummyChatMessage(
    senderId: 'coach_1',
    content: 'Hey @tyler_b, saw your film from last Friday. Outstanding pocket awareness! Are you available for a phone call this Thursday afternoon?',
    time: '10:15 AM',
    mentions: [
      MentionModel(uid: 'user_1', username: 'tyler_b')
    ],
  ),
  const DummyChatMessage(
    senderId: 'user',
    content: 'Thank you Coach @coach_miller! Yes, absolutely. I am available anytime after 4:00 PM CST once training wraps up.',
    time: '10:20 AM',
    mentions: [
      MentionModel(uid: 'coach_1', username: 'coach_miller')
    ],
  ),
  const DummyChatMessage(
    senderId: 'coach_1',
    content: 'Great! Let\'s lock in 4:30 PM CST. I\'ll call your number listed on your profile.',
    time: '10:22 AM',
  ),
];
