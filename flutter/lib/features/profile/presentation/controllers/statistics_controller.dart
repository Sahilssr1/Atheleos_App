import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/models/stat_entry.dart';
import 'profile_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State class — wraps the list with a loading flag for async saves.
// ─────────────────────────────────────────────────────────────────────────────

class StatisticsState {
  final List<StatEntry> stats;
  final bool isSaving;
  final String? error;

  const StatisticsState({
    this.stats = const [],
    this.isSaving = false,
    this.error,
  });

  StatisticsState copyWith({
    List<StatEntry>? stats,
    bool? isSaving,
    String? error,
  }) {
    return StatisticsState(
      stats: stats ?? this.stats,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

class StatisticsController extends StateNotifier<StatisticsState> {
  final Ref _ref;
  final ProfileModel _profile;

  StatisticsController(this._ref, this._profile)
      : super(StatisticsState(stats: List.from(_profile.statistics)));

  // ── Internal helpers ────────────────────────────────────────────────────

  Future<void> _persist(List<StatEntry> updated) async {
    state = state.copyWith(stats: updated, isSaving: true);
    try {
      final updatedProfile = _profile.copyWith(statistics: updated);
      await _ref.read(profileListProvider.notifier).updateProfile(updatedProfile);
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  // ── Public CRUD API ─────────────────────────────────────────────────────

  /// Add a new statistic to the end of the list.
  Future<void> addStatistic(StatEntry entry) async {
    final updated = [...state.stats, entry];
    await _persist(updated);
  }

  /// Replace an existing statistic matched by [entry.id].
  Future<void> editStatistic(StatEntry entry) async {
    final updated = state.stats
        .map((s) => s.id == entry.id ? entry : s)
        .toList();
    await _persist(updated);
  }

  /// Remove the statistic with [id].
  Future<void> deleteStatistic(String id) async {
    final updated = state.stats.where((s) => s.id != id).toList();
    await _persist(updated);
  }

  /// Move a stat from [oldIndex] to [newIndex] (called by ReorderableListView).
  Future<void> reorderStatistics(int oldIndex, int newIndex) async {
    final list = List<StatEntry>.from(state.stats);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await _persist(list);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider — family keyed by profile ID so each profile gets its own instance.
// ─────────────────────────────────────────────────────────────────────────────

final statisticsControllerProvider = StateNotifierProvider.family<
    StatisticsController, StatisticsState, ProfileModel>(
  (ref, profile) => StatisticsController(ref, profile),
);
