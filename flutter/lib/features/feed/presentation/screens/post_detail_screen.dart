import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/post_model.dart';
import 'user_posts_viewer_screen.dart';

/// Resolves a single post by ID (typically from a notification deep-link) and
/// opens it inside the shared [UserPostsViewerScreen].
///
/// The viewer streams the owner's posts anchored on [postId], so the incoming
/// notification only needs to carry the post ID. An optional [commentId] is
/// forwarded so comment notifications can scroll to the exact comment.
class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final String? commentId;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.commentId,
  });

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  late final Future<PostModel?> _future = _loadPost();

  Future<PostModel?> _loadPost() async {
    final doc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .get();
    if (!doc.exists) return null;
    return PostModel.fromMap({...?doc.data(), 'id': doc.id});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PostModel?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final post = snapshot.data;
        if (post == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This post is no longer available.')),
          );
        }

        return UserPostsViewerScreen.forUser(
          userId: post.userId,
          initialPostId: post.id,
        );
      },
    );
  }
}
