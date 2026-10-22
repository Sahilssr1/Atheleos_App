import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ath_icons.dart';
import '../../../upload/presentation/controllers/post_upload_controller.dart';

class HomeUploadBanner extends ConsumerWidget {
  const HomeUploadBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(postUploadProvider);

    if (uploadState.status == PostUploadStatus.idle) {
      return const SizedBox.shrink();
    }

    final isCompleted = uploadState.status == PostUploadStatus.completed;
    final isError = uploadState.status == PostUploadStatus.error;
    final isProcessing = uploadState.status == PostUploadStatus.processing;
    final isUploading = uploadState.status == PostUploadStatus.uploading;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
              : isError
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : AppTheme.primaryColor.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Media preview thumbnail or icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFF222222),
                  child: !uploadState.isVideo &&
                          uploadState.thumbnailPath != null &&
                          File(uploadState.thumbnailPath!).existsSync()
                      ? Image.file(
                          File(uploadState.thumbnailPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            AthIcons.photo,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        )
                      : Icon(
                          uploadState.isVideo ? AthIcons.videoCamera : AthIcons.cloudArrowUp,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and status info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isCompleted
                              ? 'Highlight Published!'
                              : isError
                                  ? 'Upload Failed'
                                  : isProcessing
                                      ? 'Processing Highlight...'
                                      : 'Uploading Highlight...',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isCompleted
                                ? const Color(0xFF4CAF50)
                                : isError
                                    ? Colors.redAccent
                                    : Colors.white,
                          ),
                        ),
                        if (isUploading || isProcessing) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${(uploadState.progress * 100).toInt()}%',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isError
                          ? (uploadState.errorMessage ?? 'Please check internet and retry')
                          : isCompleted
                              ? 'Now live on feed'
                              : (uploadState.caption?.isNotEmpty == true
                                  ? uploadState.caption!
                                  : 'Publishing to Atheleos...'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),

              // Action button (dismiss or close)
              if (isCompleted)
                IconButton(
                  icon: const Icon(AthIcons.checkCircle, color: Color(0xFF4CAF50), size: 20),
                  onPressed: () {
                    ref.read(postUploadProvider.notifier).dismiss();
                  },
                )
              else if (isError)
                IconButton(
                  icon: const Icon(AthIcons.xMark, color: Colors.white54, size: 18),
                  onPressed: () {
                    ref.read(postUploadProvider.notifier).dismiss();
                  },
                )
              else
                IconButton(
                  icon: const Icon(AthIcons.xMark, color: Colors.white30, size: 16),
                  onPressed: () {
                    ref.read(postUploadProvider.notifier).dismiss();
                  },
                ),
            ],
          ),

          // Progress bar
          if (isUploading || isProcessing) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: uploadState.progress > 0 ? uploadState.progress : null,
                minHeight: 4,
                backgroundColor: const Color(0xFF262626),
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
