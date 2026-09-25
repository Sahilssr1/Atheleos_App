import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sports_service.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../../../clips/presentation/controllers/clips_controller.dart';
import '../controllers/search_controller.dart';
import '../../../clips/presentation/screens/clips_screen.dart';
import '../../../../core/widgets/app_avatar.dart';

import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/network_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  static const List<String> supportedStates = [
    'All', 'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA',
    'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY',
    'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX',
    'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
  ];

  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchActive = false;

  // Filter state for user search
  final TextEditingController _cityController = TextEditingController();
  final ScrollController _exploreScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isSearchActive = _searchFocusNode.hasFocus || _searchController.text.isNotEmpty;
        });
      }
    });
    _exploreScrollController.addListener(() {
      if (_exploreScrollController.position.pixels >= _exploreScrollController.position.maxScrollExtent - 200) {
        ref.read(clipsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _cityController.dispose();
    _exploreScrollController.dispose();
    super.dispose();
  }

  String _getThumbnailUrl(PostModel post) {
    if (post.media.isEmpty) return '';
    final media = post.media.first;
    // For videos, use the thumbnail if available
    if (media.thumbnailUrl != null && media.thumbnailUrl!.isNotEmpty) {
      return media.thumbnailUrl!;
    }
    // For Cloudinary videos, generate a thumbnail
    if (media.mediaUrl.contains('cloudinary.com') && media.mediaUrl.contains('/video/upload/')) {
      var url = media.mediaUrl.replaceAll('/video/upload/', '/video/upload/w_400,h_600,c_limit,so_0/');
      final lastDot = url.lastIndexOf('.');
      if (lastDot != -1) {
        url = '${url.substring(0, lastDot)}.jpg';
      }
      return url;
    }
    return media.mediaUrl;
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _onClipTap(PostModel clip) {
    if (clip.media.isNotEmpty) {
      final currentClips = ref.read(clipsProvider).valueOrNull ?? [];
      final mediaClips = currentClips.where((c) => c.media.isNotEmpty).toList();
      int initialIndex = mediaClips.indexWhere((c) => c.id == clip.id);
      if (initialIndex == -1) {
        initialIndex = 0;
        mediaClips.insert(0, clip);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelsViewerScreen(
            clips: mediaClips,
            initialIndex: initialIndex,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clipsAsync = ref.watch(clipsProvider);
    final isOnline = ref.watch(networkServiceProvider.select((net) => net.isOnline));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search Bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isSearchActive
                              ? AppTheme.primaryColor.withOpacity(0.4)
                              : Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (val) {
                          ref.read(searchFiltersProvider.notifier).setQuery(val);
                          setState(() {
                            _isSearchActive = val.isNotEmpty || _searchFocusNode.hasFocus;
                          });
                        },
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search athletes, coaches, brands, federations...',
                          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: _isSearchActive ? AppTheme.primaryColor : Colors.white30,
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    ref.read(searchFiltersProvider.notifier).setQuery('');
                                    setState(() { _isSearchActive = _searchFocusNode.hasFocus; });
                                  },
                                  child: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  if (_isSearchActive) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                        ref.read(searchFiltersProvider.notifier).setQuery('');
                        setState(() { _isSearchActive = false; });
                      },
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Content: either search results or explore grid ──────
            Expanded(
              child: _isSearchActive
                  ? _buildSearchResults(isOnline)
                  : _buildExploreGrid(clipsAsync, isOnline),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // EXPLORE GRID — Instagram-style grid of video clip thumbnails
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildExploreGrid(AsyncValue<List<PostModel>> clipsAsync, bool isOnline) {
    List<PostModel> clips = [];
    bool isLoading = false;
    bool hasError = false;

    clipsAsync.when(
      loading: () => isLoading = true,
      error: (err, stack) => hasError = true,
      data: (data) => clips = data,
    );

    // Cache Explore data when online
    if (isOnline && clips.isNotEmpty) {
      Future.microtask(() {
        try {
          CacheManager().saveExplore(clips.map((c) => c.toMap()).toList());
        } catch (_) {}
      });
    }

    // Fallback to cache if offline and no memory data loaded
    if (clips.isEmpty && !isOnline) {
      try {
        final cached = CacheManager().loadExplore();
        clips = cached.map((map) => PostModel.fromMap(map)).toList();
        if (clips.isNotEmpty) {
          isLoading = false;
          hasError = false;
        }
      } catch (_) {}
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (hasError && clips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text('Could not load content', style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => ref.invalidate(clipsProvider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Retry', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }
    return _buildExploreGridContent(clips);
  }

  Widget _buildExploreGridContent(List<PostModel> clips) {
    if (clips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined, size: 56, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 16),
            Text('No clips to explore yet',
                style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Upload a video to get started!',
                style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      backgroundColor: const Color(0xFF141414),
      onRefresh: () async {
        await ref.read(clipsProvider.notifier).refresh();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          const double spacing = 2.0;
          // Width of standard 1-column cell
          final double itemWidth = (totalWidth - (spacing * 2)) / 3;
          // Height of standard 1-column cell (slightly vertical for reels aspect)
          final double itemHeight = itemWidth * 1.3;
          // Large cell width spans 2 columns
          final double largeWidth = (itemWidth * 2) + spacing;
          // Large cell height spans 2 standard rows
          final double largeHeight = (itemHeight * 2) + spacing;

          final int totalClips = clips.length;
          final int blockCount = (totalClips / 6).ceil();

          return ListView.builder(
            controller: _exploreScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: spacing),
            itemCount: blockCount + 1,
            itemBuilder: (context, blockIndex) {
              if (blockIndex == blockCount) {
                final notifier = ref.watch(clipsProvider.notifier);
                if (notifier.hasMore) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryColor),
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No more clips to explore.',
                        style: GoogleFonts.inter(color: Colors.white.withOpacity(0.3), fontSize: 12),
                      ),
                    ),
                  );
                }
              }

              final int baseIdx = blockIndex * 6;
              final List<PostModel> blockClips = [];
              for (int i = 0; i < 6; i++) {
                if (baseIdx + i < totalClips) {
                  blockClips.add(clips[baseIdx + i]);
                }
              }

              // If block is incomplete and has fewer than 3 items, render standard row
              if (blockClips.length < 3) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: spacing),
                  child: Row(
                    children: blockClips.map((clip) {
                      return Padding(
                        padding: const EdgeInsets.only(right: spacing),
                        child: _buildGridItem(clip, itemWidth, itemHeight),
                      );
                    }).toList(),
                  ),
                );
              }

              // Alternating patterns like Instagram Explore
              final isEvenPattern = blockIndex % 2 == 0;

              return Column(
                children: [
                  // Row 1 & 2: Large Reel combo (left/right staggered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: spacing),
                    child: SizedBox(
                      height: largeHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: isEvenPattern
                            ? [
                                // Left side: 2 standard stacked vertically
                                SizedBox(
                                  width: itemWidth,
                                  child: Column(
                                    children: [
                                      _buildGridItem(blockClips[0], itemWidth, itemHeight),
                                      const SizedBox(height: spacing),
                                      if (blockClips.length > 1)
                                        _buildGridItem(blockClips[1], itemWidth, itemHeight)
                                      else
                                        SizedBox(width: itemWidth, height: itemHeight),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: spacing),
                                // Right side: 1 large reel
                                if (blockClips.length > 2)
                                  _buildGridItem(blockClips[2], largeWidth, largeHeight)
                                else
                                  SizedBox(width: largeWidth, height: largeHeight),
                              ]
                            : [
                                // Left side: 1 large reel
                                _buildGridItem(blockClips[0], largeWidth, largeHeight),
                                const SizedBox(width: spacing),
                                // Right side: 2 standard stacked vertically
                                SizedBox(
                                  width: itemWidth,
                                  child: Column(
                                    children: [
                                      if (blockClips.length > 1)
                                        _buildGridItem(blockClips[1], itemWidth, itemHeight)
                                      else
                                        SizedBox(width: itemWidth, height: itemHeight),
                                      const SizedBox(height: spacing),
                                      if (blockClips.length > 2)
                                        _buildGridItem(blockClips[2], itemWidth, itemHeight)
                                      else
                                        SizedBox(width: itemWidth, height: itemHeight),
                                    ],
                                  ),
                                ),
                              ],
                      ),
                    ),
                  ),
                  // Row 3: 3 standard items side by side
                  if (blockClips.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: spacing),
                      child: SizedBox(
                        height: itemHeight,
                        child: Row(
                          children: [
                            _buildGridItem(blockClips[3], itemWidth, itemHeight),
                            const SizedBox(width: spacing),
                            if (blockClips.length > 4)
                              _buildGridItem(blockClips[4], itemWidth, itemHeight)
                            else
                              SizedBox(width: itemWidth, height: itemHeight),
                            const SizedBox(width: spacing),
                            if (blockClips.length > 5)
                              _buildGridItem(blockClips[5], itemWidth, itemHeight)
                            else
                              SizedBox(width: itemWidth, height: itemHeight),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Explore Grid Item Builder ─────────────────────────────────────
  Widget _buildGridItem(PostModel clip, double width, double height) {
    final thumbnailUrl = _getThumbnailUrl(clip);
    return GestureDetector(
      onTap: () => _onClipTap(clip),
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFF141414),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            if (thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                memCacheWidth: 360,
                memCacheHeight: 360,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF141414),
                  child: const Center(
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF181818),
                  child: const Center(
                    child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 32),
                  ),
                ),
              )
            else
              Container(
                color: const Color(0xFF181818),
                child: const Center(
                  child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 32),
                ),
              ),

            // Bottom gradient overlay
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Play icon + views count
            Positioned(
              bottom: 6, left: 6,
              child: Row(
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(clip.views),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Sport tag (top right)
            if (clip.sport.isNotEmpty)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    clip.sport,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SEARCH RESULTS — User profiles with advanced filters
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSearchResults(bool isOnline) {
    final filters = ref.watch(searchFiltersProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final sportsList = ['All', ...SportsService.supportedSports];
    final rolesList = ['All', 'Athlete', 'Coach', 'Brand', 'Federation'];

    // If query is empty, show search history and suggested users
    if (filters.query.isEmpty) {
      final history = CacheManager().loadSearchHistory();
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      CacheManager().saveSearchHistory([]);
                    });
                  },
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.inter(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: history.map((q) => GestureDetector(
                onTap: () {
                  _searchController.text = q;
                  ref.read(searchFiltersProvider.notifier).setQuery(q);
                },
                child: Chip(
                  label: Text(q, style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                  backgroundColor: const Color(0xFF141414),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFF262626)),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'Suggested Users',
            style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),
          resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
            error: (err, stack) => const Text('No suggestions available'),
            data: (users) {
              final suggested = users.take(5).toList();
              if (suggested.isEmpty) {
                return const Text('Search for your first athlete!');
              }
              return Column(
                children: suggested.map((user) => _buildUserCard(user)).toList(),
              );
            },
          ),
        ],
      );
    }

    return Column(
      children: [
        // ── Filter chips row ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  label: filters.sport == 'All' ? 'Sport' : filters.sport,
                  isActive: filters.sport != 'All',
                  onTap: () => _showFilterSheet(
                    title: 'Select Sport',
                    options: sportsList,
                    selected: filters.sport,
                    onSelected: (val) => ref.read(searchFiltersProvider.notifier).setSport(val),
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: filters.role == 'All' ? 'Role' : filters.role,
                  isActive: filters.role != 'All',
                  onTap: () => _showFilterSheet(
                    title: 'Select Role',
                    options: rolesList,
                    selected: filters.role,
                    onSelected: (val) => ref.read(searchFiltersProvider.notifier).setRole(val),
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: filters.state == 'All' ? 'State' : filters.state,
                  isActive: filters.state != 'All',
                  onTap: () => _showFilterSheet(
                    title: 'Select State',
                    options: SearchScreen.supportedStates,
                    selected: filters.state,
                    onSelected: (val) => ref.read(searchFiltersProvider.notifier).setStateCode(val),
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Verified',
                  isActive: filters.onlyVerified,
                  icon: Icons.verified,
                  onTap: () => ref.read(searchFiltersProvider.notifier).setOnlyVerified(!filters.onlyVerified),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Results ──────────────────────────────────────────────
        Expanded(
          child: resultsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            error: (err, stack) => Center(
              child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
            ),
            data: (users) {
              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_outlined, size: 48, color: Colors.white.withOpacity(0.15)),
                      const SizedBox(height: 12),
                      Text('No profiles found',
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Try adjusting your search or filters',
                          style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length + 1, // +1 for header
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${users.length} result${users.length != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  final athlete = users[index - 1];
                  return _buildUserCard(athlete);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(ProfileModel athlete) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // Save query/name to search history
            final history = CacheManager().loadSearchHistory();
            history.remove(athlete.name);
            history.insert(0, athlete.name);
            CacheManager().saveSearchHistory(history.take(10).toList());

            // Save profile details to profile cache to support instant loading
            CacheManager().saveProfile(athlete.id, athlete.toMap());

            context.push('/profile/${athlete.id}');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              children: [
                // Avatar
                AppAvatar(
                  imageUrl: athlete.avatarUrl,
                  radius: 24,
                  role: athlete.role,
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              athlete.name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (athlete.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 15, color: AppTheme.primaryColor),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${athlete.sport} • ${athlete.primaryPosition}',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (athlete.city.isNotEmpty || athlete.state.isNotEmpty)
                        Text(
                          [athlete.city, athlete.state].where((s) => s.isNotEmpty).join(', '),
                          style: GoogleFonts.inter(color: Colors.white30, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    athlete.role,
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Filter chip widget ──────────────────────────────────────────
  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor.withOpacity(0.15) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primaryColor.withOpacity(0.5) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isActive ? AppTheme.primaryColor : Colors.white54),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? AppTheme.primaryColor : Colors.white60,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (!isActive && icon == null) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white.withOpacity(0.3)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Filter bottom sheet ──────────────────────────────────────────
  void _showFilterSheet({
    required String title,
    required List<String> options,
    required String selected,
    required void Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF262626)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const Divider(color: Colors.white10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option == selected;
                  return ListTile(
                    title: Text(
                      option,
                      style: GoogleFonts.inter(
                        color: isSelected ? AppTheme.primaryColor : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20)
                        : null,
                    onTap: () {
                      onSelected(option);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
