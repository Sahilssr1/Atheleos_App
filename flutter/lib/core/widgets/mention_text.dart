import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/profile/presentation/controllers/profile_controller.dart';
import '../models/mention_model.dart';
import '../theme/app_theme.dart';

class MentionText extends ConsumerStatefulWidget {
  final String text;
  final List<MentionModel> mentions;
  final TextStyle? style;
  final TextStyle? mentionStyle;

  const MentionText({
    super.key,
    required this.text,
    this.mentions = const [],
    this.style,
    this.mentionStyle,
  });

  @override
  ConsumerState<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends ConsumerState<MentionText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return Text('', style: widget.style);
    }

    // Clear previous recognizers before rebuild
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final RegExp mentionRegex = RegExp(r'@([a-zA-Z0-9_\.]+)');
    final matches = mentionRegex.allMatches(widget.text);

    if (matches.isEmpty) {
      return Text(widget.text, style: widget.style);
    }

    final List<InlineSpan> spans = [];
    int lastIdx = 0;

    final defaultStyle = widget.style ?? const TextStyle(color: Colors.white, fontSize: 13);
    final linkStyle = widget.mentionStyle ?? const TextStyle(
      color: AppTheme.primaryColor,
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );

    for (final match in matches) {
      // Append text preceding the match
      if (match.start > lastIdx) {
        spans.add(TextSpan(
          text: widget.text.substring(lastIdx, match.start),
          style: defaultStyle,
        ));
      }

      final token = match.group(0)!;
      final cleanUsername = token.substring(1).trim().toLowerCase();

      // 1. Look up explicit mention mapping list
      var mapping = widget.mentions.firstWhere(
        (m) => m.username.toLowerCase() == cleanUsername,
        orElse: () => const MentionModel(uid: '', username: ''),
      );

      // 2. Dynamic Fallback: Query all profiles if no explicit model mapping list is available (e.g. Bios, Stories)
      if (mapping.uid.isEmpty) {
        final allProfiles = ref.read(profileListProvider).valueOrNull ?? [];
        try {
          final matchedProfile = allProfiles.firstWhere(
            (p) => p.username.toLowerCase() == cleanUsername,
          );
          mapping = MentionModel(uid: matchedProfile.id, username: matchedProfile.username);
        } catch (_) {}
      }

      if (mapping.uid.isNotEmpty) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            context.push('/profile/${mapping.uid}');
          };
        _recognizers.add(recognizer);

        spans.add(TextSpan(
          text: token,
          style: linkStyle,
          recognizer: recognizer,
        ));
      } else {
        // Plain text if mention doesn't match an actual registered UID
        spans.add(TextSpan(
          text: token,
          style: defaultStyle,
        ));
      }

      lastIdx = match.end;
    }

    // Append any remaining text
    if (lastIdx < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(lastIdx),
        style: defaultStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
