import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/profile/presentation/controllers/profile_controller.dart';
import '../models/mention_model.dart';
import '../theme/app_theme.dart';

/// Instagram-style expandable and collapsible caption widget.
///
/// If a caption exceeds [trimLength] characters or [trimLines] lines,
/// it displays a truncated preview with an inline clickable "... more" button.
/// Tapping "... more" expands the full caption with light haptic feedback.
/// Tapping " less" collapses it back (if [showCollapseButton] is true).
///
/// Retains full support for clickable `@mentions`, opening the referenced user profile.
class ExpandableCaption extends ConsumerStatefulWidget {
  final String text;
  final List<MentionModel> mentions;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final TextStyle? actionStyle;
  final int trimLines;
  final int trimLength;
  final bool showCollapseButton;
  final VoidCallback? onExpand;

  const ExpandableCaption({
    super.key,
    required this.text,
    this.mentions = const [],
    this.style,
    this.mentionStyle,
    this.actionStyle,
    this.trimLines = 2,
    this.trimLength = 95,
    this.showCollapseButton = true,
    this.onExpand,
  });

  @override
  ConsumerState<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends ConsumerState<ExpandableCaption> {
  bool _isExpanded = false;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  bool _checkExceedsLimit() {
    if (widget.text.length > widget.trimLength) return true;
    final lines = widget.text.split('\n');
    return lines.length > widget.trimLines;
  }

  String _calculateTruncatedText() {
    int cutoff = widget.text.length;
    final lines = widget.text.split('\n');
    if (lines.length > widget.trimLines) {
      int charCount = 0;
      for (int i = 0; i < widget.trimLines; i++) {
        charCount += lines[i].length + 1;
      }
      cutoff = (charCount - 1).clamp(0, widget.text.length);
    }
    if (cutoff > widget.trimLength) {
      cutoff = widget.trimLength;
    }
    // Snap to nearest preceding space to avoid chopping words
    final spaceIdx = widget.text.lastIndexOf(' ', cutoff);
    if (spaceIdx != -1 && spaceIdx > (cutoff * 0.65)) {
      cutoff = spaceIdx;
    }
    return widget.text.substring(0, cutoff).trimRight();
  }

  List<InlineSpan> _buildSpans(String targetText, TextStyle defaultStyle, TextStyle linkStyle) {
    final RegExp mentionRegex = RegExp(r'@([a-zA-Z0-9_\.]+)');
    final matches = mentionRegex.allMatches(targetText);

    if (matches.isEmpty) {
      return [TextSpan(text: targetText, style: defaultStyle)];
    }

    final List<InlineSpan> spans = [];
    int lastIdx = 0;

    for (final match in matches) {
      if (match.start > lastIdx) {
        spans.add(TextSpan(
          text: targetText.substring(lastIdx, match.start),
          style: defaultStyle,
        ));
      }

      final token = match.group(0)!;
      final cleanUsername = token.substring(1).trim().toLowerCase();

      var mapping = widget.mentions.firstWhere(
        (m) => m.username.toLowerCase() == cleanUsername,
        orElse: () => const MentionModel(uid: '', username: ''),
      );

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
        spans.add(TextSpan(
          text: token,
          style: defaultStyle,
        ));
      }

      lastIdx = match.end;
    }

    if (lastIdx < targetText.length) {
      spans.add(TextSpan(
        text: targetText.substring(lastIdx),
        style: defaultStyle,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    _clearRecognizers();

    final defaultStyle = widget.style ?? const TextStyle(color: Colors.white, fontSize: 13);
    final linkStyle = widget.mentionStyle ??
        const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        );
    final actionStyle = widget.actionStyle ??
        TextStyle(
          color: Colors.white.withValues(alpha: 0.60),
          fontWeight: FontWeight.w700,
          fontSize: (widget.style?.fontSize ?? 13),
        );

    final isTooLong = _checkExceedsLimit();

    if (!isTooLong) {
      final spans = _buildSpans(widget.text, defaultStyle, linkStyle);
      return RichText(
        text: TextSpan(children: spans),
      );
    }

    final displayText = _isExpanded ? widget.text : _calculateTruncatedText();
    final spans = _buildSpans(displayText, defaultStyle, linkStyle);

    if (!_isExpanded) {
      final expandRecognizer = TapGestureRecognizer()
        ..onTap = () {
          HapticFeedback.lightImpact();
          setState(() => _isExpanded = true);
          widget.onExpand?.call();
        };
      _recognizers.add(expandRecognizer);

      spans.add(TextSpan(
        text: ' ...more',
        style: actionStyle,
        recognizer: expandRecognizer,
      ));
    } else if (widget.showCollapseButton) {
      final collapseRecognizer = TapGestureRecognizer()
        ..onTap = () {
          HapticFeedback.lightImpact();
          setState(() => _isExpanded = false);
        };
      _recognizers.add(collapseRecognizer);

      spans.add(TextSpan(
        text: '  less',
        style: actionStyle,
        recognizer: collapseRecognizer,
      ));
    }

    final richTextWidget = RichText(
      text: TextSpan(children: spans),
    );

    // If collapsed, tapping the text area expands it as well (Instagram behavior)
    if (!_isExpanded) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _isExpanded = true);
          widget.onExpand?.call();
        },
        child: richTextWidget,
      );
    }

    return richTextWidget;
  }
}
