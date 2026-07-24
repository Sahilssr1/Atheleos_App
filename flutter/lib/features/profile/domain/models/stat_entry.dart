// ─────────────────────────────────────────────────────────────────────────────
// StatEntry — A single sport-agnostic statistic entry.
//
// Design goals:
//   • No hardcoded fields per sport — every sport uses the same model.
//   • `value` is always stored as a String for maximum flexibility. The `type`
//     field drives display formatting on the UI layer.
//   • `id` is a UUID assigned at creation time so the list can be reordered,
//     edited, and deleted by identity without index fragility.
//   • Future-ready: storing `name` + `type` together allows a backend query to
//     GROUP BY sport + name and surface popular suggestions to new users.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// The set of statistic types the system supports.
/// Adding a new type here automatically propagates it to the UI drop-down.
enum StatType {
  number,     // Integer count         e.g. 35
  decimal,    // Float value           e.g. 8.5
  text,       // Free-form string      e.g. #14
  percentage, // Percentage            e.g. 78%
  time,       // Duration / pace       e.g. 10.3s
  weight,     // Mass with unit        e.g. 160 kg
  distance,   // Distance with unit    e.g. 7.2 m
  date,       // Calendar date         e.g. Jan 2025
}

extension StatTypeX on StatType {
  /// Human-readable label shown in the drop-down.
  String get label {
    switch (this) {
      case StatType.number:     return 'Number';
      case StatType.decimal:    return 'Decimal';
      case StatType.text:       return 'Text';
      case StatType.percentage: return 'Percentage';
      case StatType.time:       return 'Time';
      case StatType.weight:     return 'Weight';
      case StatType.distance:   return 'Distance';
      case StatType.date:       return 'Date';
    }
  }

  /// Hint shown inside the value input field for this type.
  String get valueHint {
    switch (this) {
      case StatType.number:     return 'e.g. 35';
      case StatType.decimal:    return 'e.g. 8.5';
      case StatType.text:       return 'e.g. #14 or Elite';
      case StatType.percentage: return 'e.g. 78 (will show as 78%)';
      case StatType.time:       return 'e.g. 10.3s or 1:24.5';
      case StatType.weight:     return 'e.g. 160 kg or 350 lbs';
      case StatType.distance:   return 'e.g. 7.2 m or 23 ft';
      case StatType.date:       return 'e.g. Jan 2025';
    }
  }

  /// Serialize to the Firestore string key.
  String get key => name; // uses the enum name directly

  /// Format a raw value string for display.
  String formatValue(String raw) {
    switch (this) {
      case StatType.percentage: return raw.endsWith('%') ? raw : '$raw%';
      default:                  return raw;
    }
  }
}

/// Parse a Firestore string key back to a [StatType].
StatType statTypeFromKey(String? key) {
  return StatType.values.firstWhere(
    (t) => t.key == key,
    orElse: () => StatType.text,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// StatEntry model
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class StatEntry {
  final String id;       // UUID — stable identity for reorder/edit/delete
  final String name;     // Statistic label, e.g. "Wins"
  final StatType type;   // Drives formatting & keyboard type
  final String value;    // Raw value always stored as String

  const StatEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
  });

  /// The formatted display value (e.g. "78%" for percentage type).
  String get displayValue => type.formatValue(value);

  StatEntry copyWith({
    String? id,
    String? name,
    StatType? type,
    String? value,
  }) {
    return StatEntry(
      id:    id    ?? this.id,
      name:  name  ?? this.name,
      type:  type  ?? this.type,
      value: value ?? this.value,
    );
  }

  /// Serialize to a Firestore-compatible map.
  Map<String, dynamic> toMap() => {
    'id':    id,
    'name':  name,
    'type':  type.key,
    'value': value,
  };

  /// Deserialize from a Firestore document map.
  factory StatEntry.fromMap(Map<String, dynamic> map) {
    return StatEntry(
      id:    map['id']    as String? ?? '',
      name:  map['name']  as String? ?? '',
      type:  statTypeFromKey(map['type'] as String?),
      value: map['value'].toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is StatEntry && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StatEntry(id: $id, name: $name, type: ${type.key}, value: $value)';
}
