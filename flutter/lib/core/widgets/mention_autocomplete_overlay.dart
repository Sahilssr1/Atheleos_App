import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/profile/domain/models/profile_model.dart';
import '../../features/profile/presentation/controllers/profile_controller.dart';

class MentionAutocompleteOverlay extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget child;

  const MentionAutocompleteOverlay({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.child,
  });

  @override
  ConsumerState<MentionAutocompleteOverlay> createState() => _MentionAutocompleteOverlayState();
}

class _MentionAutocompleteOverlayState extends ConsumerState<MentionAutocompleteOverlay> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  String? _lastQuery;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _hideOverlay();
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      _hideOverlay();
    } else {
      _onTextChanged();
    }
  }

  void _onTextChanged() {
    if (!widget.focusNode.hasFocus) {
      _hideOverlay();
      return;
    }

    final query = _getMentionQuery();
    if (query == null) {
      _hideOverlay();
      return;
    }

    if (query == _lastQuery && _overlayEntry != null) {
      return;
    }
    _lastQuery = query;

    final profiles = ref.read(profileListProvider).valueOrNull ?? [];
    final matchedUsers = profiles.where((user) {
      return user.username.toLowerCase().contains(query.toLowerCase()) ||
          user.name.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (matchedUsers.isEmpty) {
      _hideOverlay();
      return;
    }

    _showOverlay(matchedUsers, query);
  }

  String? _getMentionQuery() {
    final selection = widget.controller.selection;
    if (selection.baseOffset <= 0) return null;

    final text = widget.controller.text;
    final textBeforeCursor = text.substring(0, selection.baseOffset);

    // Find the start of the current word being typed
    final lastWhitespace = textBeforeCursor.lastIndexOf(RegExp(r'\s'));
    final currentWord = lastWhitespace == -1
        ? textBeforeCursor
        : textBeforeCursor.substring(lastWhitespace + 1);

    if (currentWord.startsWith('@')) {
      return currentWord.substring(1);
    }
    return null;
  }

  void _showOverlay(List<ProfileModel> matchedUsers, String query) {
    _hideOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: MediaQuery.of(context).size.width - 32, // Match parent padding width
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            // Draw dropdown list directly underneath the input textfield target
            offset: const Offset(0, 52),
            child: Material(
              elevation: 8,
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white12),
              ),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: matchedUsers.length,
                  itemBuilder: (context, index) {
                    final user = matchedUsers[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(user.avatarUrl),
                        radius: 16,
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '@${user.username}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () => _selectUser(user, query),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _selectUser(ProfileModel user, String query) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final textAfterCursor = text.substring(selection.baseOffset);

    final lastWhitespace = textBeforeCursor.lastIndexOf(RegExp(r'\s'));
    final replaceStart = lastWhitespace == -1 ? 0 : lastWhitespace + 1;

    final newTextBeforeCursor = textBeforeCursor.substring(0, replaceStart) + '@${user.username} ';

    widget.controller.text = newTextBeforeCursor + textAfterCursor;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newTextBeforeCursor.length),
    );

    _hideOverlay();
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _lastQuery = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: widget.child,
    );
  }
}
