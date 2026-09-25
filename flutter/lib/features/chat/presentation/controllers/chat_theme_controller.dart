import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/cache_manager.dart';

class ChatThemeItem {
  final String id;
  final String name;
  final List<Color> backgroundGradient;
  final List<Color> bubbleGradient;
  final Color receivedBubbleColor;
  final Color ownTextColor;
  final Color accentColor;
  final Color appBarColor;
  final String emoji;

  const ChatThemeItem({
    required this.id,
    required this.name,
    required this.backgroundGradient,
    required this.bubbleGradient,
    required this.receivedBubbleColor,
    this.ownTextColor = Colors.black,
    required this.accentColor,
    required this.appBarColor,
    required this.emoji,
  });
}

const List<ChatThemeItem> kAvailableChatThemes = [
  ChatThemeItem(
    id: 'gold',
    name: 'Atheleos Gold',
    backgroundGradient: [Color(0xFF000000), Color(0xFF0D0D0D), Color(0xFF000000)],
    bubbleGradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
    receivedBubbleColor: Color(0xFF181818),
    appBarColor: Color(0xFF000000),
    ownTextColor: Colors.black,
    accentColor: Color(0xFFF59E0B),
    emoji: '🏆',
  ),
  ChatThemeItem(
    id: 'sunset',
    name: 'Sunset Horizon',
    backgroundGradient: [Color(0xFF1C0A1F), Color(0xFF2E1026), Color(0xFF150818)],
    bubbleGradient: [Color(0xFFFF5E36), Color(0xFFFF9500)],
    receivedBubbleColor: Color(0xFF2D142F),
    appBarColor: Color(0xFF1A0B1E),
    ownTextColor: Colors.white,
    accentColor: Color(0xFFFF5E36),
    emoji: '🌅',
  ),
  ChatThemeItem(
    id: 'cyber',
    name: 'Cyber Neon',
    backgroundGradient: [Color(0xFF051221), Color(0xFF0B243B), Color(0xFF040E1B)],
    bubbleGradient: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
    receivedBubbleColor: Color(0xFF0E2B47),
    appBarColor: Color(0xFF07192C),
    ownTextColor: Colors.black,
    accentColor: Color(0xFF00F2FE),
    emoji: '⚡',
  ),
  ChatThemeItem(
    id: 'amethyst',
    name: 'Midnight Amethyst',
    backgroundGradient: [Color(0xFF120722), Color(0xFF1F0E3B), Color(0xFF0D0519)],
    bubbleGradient: [Color(0xFFA855F7), Color(0xFF6366F1)],
    receivedBubbleColor: Color(0xFF261347),
    appBarColor: Color(0xFF130824),
    ownTextColor: Colors.white,
    accentColor: Color(0xFFA855F7),
    emoji: '🔮',
  ),
  ChatThemeItem(
    id: 'emerald',
    name: 'Emerald Forest',
    backgroundGradient: [Color(0xFF051711), Color(0xFF0B2A1F), Color(0xFF04120D)],
    bubbleGradient: [Color(0xFF10B981), Color(0xFF059669)],
    receivedBubbleColor: Color(0xFF0F3528),
    appBarColor: Color(0xFF071E16),
    ownTextColor: Colors.white,
    accentColor: Color(0xFF10B981),
    emoji: '🌿',
  ),
  ChatThemeItem(
    id: 'ocean',
    name: 'Ocean Breeze',
    backgroundGradient: [Color(0xFF041726), Color(0xFF08263E), Color(0xFF03111C)],
    bubbleGradient: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    receivedBubbleColor: Color(0xFF0D3252),
    appBarColor: Color(0xFF061F33),
    ownTextColor: Colors.white,
    accentColor: Color(0xFF0EA5E9),
    emoji: '🌊',
  ),
  ChatThemeItem(
    id: 'cherry',
    name: 'Cherry Blossom',
    backgroundGradient: [Color(0xFF1D0917), Color(0xFF2F0F25), Color(0xFF160711)],
    bubbleGradient: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    receivedBubbleColor: Color(0xFF34142B),
    appBarColor: Color(0xFF1D0A18),
    ownTextColor: Colors.white,
    accentColor: Color(0xFFEC4899),
    emoji: '🌸',
  ),
  ChatThemeItem(
    id: 'crimson',
    name: 'Crimson Fire',
    backgroundGradient: [Color(0xFF1D0707), Color(0xFF2D0E0E), Color(0xFF140505)],
    bubbleGradient: [Color(0xFFEF4444), Color(0xFFB91C1C)],
    receivedBubbleColor: Color(0xFF301212),
    appBarColor: Color(0xFF1C0808),
    ownTextColor: Colors.white,
    accentColor: Color(0xFFEF4444),
    emoji: '🔥',
  ),
  ChatThemeItem(
    id: 'monochrome',
    name: 'Stealth Charcoal',
    backgroundGradient: [Color(0xFF000000), Color(0xFF0F0F0F), Color(0xFF000000)],
    bubbleGradient: [Color(0xFF333333), Color(0xFF222222)],
    receivedBubbleColor: Color(0xFF181818),
    appBarColor: Color(0xFF000000),
    ownTextColor: Colors.white,
    accentColor: Color(0xFFA1A1AA),
    emoji: '🌑',
  ),
];

class ChatThemeNotifier extends StateNotifier<ChatThemeItem> {
  final String roomId;

  ChatThemeNotifier(this.roomId) : super(kAvailableChatThemes.first) {
    _loadTheme();
  }

  void _loadTheme() {
    try {
      final savedId = CacheManager().prefs.getString('chat_theme_$roomId');
      if (savedId != null) {
        final match = kAvailableChatThemes.firstWhere(
          (t) => t.id == savedId,
          orElse: () => kAvailableChatThemes.first,
        );
        state = match;
      }
    } catch (_) {}
  }

  Future<void> setTheme(String themeId) async {
    final match = kAvailableChatThemes.firstWhere(
      (t) => t.id == themeId,
      orElse: () => kAvailableChatThemes.first,
    );
    state = match;
    try {
      await CacheManager().prefs.setString('chat_theme_$roomId', themeId);
    } catch (_) {}
  }
}

final chatThemeProvider = StateNotifierProvider.family<ChatThemeNotifier, ChatThemeItem, String>(
  (ref, roomId) => ChatThemeNotifier(roomId),
);
