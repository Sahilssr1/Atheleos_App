import 'package:cloud_firestore/cloud_firestore.dart';

class SportsService {
  static const List<String> supportedSports = [
    'Arm Wrestling',
    'Artistic Swimming',
    'Archery',
    'Athletics (Track & Field)',
    'Badminton',
    'Baseball',
    'Basketball',
    'Billiards & Snooker',
    'Bodybuilding',
    'Boxing',
    'Brazilian Jiu-Jitsu',
    'Bridge',
    'Canoeing',
    'Chess',
    'Cricket',
    'Cross Country',
    'Cycling',
    'Diving',
    'Equestrian',
    'Fencing',
    'Football',
    'Golf',
    'Gymnastics',
    'Handball',
    'Hockey',
    'Ice Hockey',
    'Ice Skating',
    'Judo',
    'Kabaddi',
    'Karate',
    'Kayaking',
    'Kendo',
    'Kho Kho',
    'Kickboxing',
    'Lawn Bowls',
    'Mallakhamb',
    'Marathon',
    'MMA',
    'Mountaineering',
    'Muay Thai',
    'Netball',
    'Pencak Silat',
    'Pickleball',
    'Polo',
    'Powerlifting',
    'Race Walking',
    'Roller Skating',
    'Rowing',
    'Rugby',
    'Sailing',
    'Sepak Takraw',
    'Shooting',
    'Skateboarding',
    'Skiing',
    'Snowboarding',
    'Soft Tennis',
    'Softball',
    'Sport Climbing',
    'Squash',
    'Surfing',
    'Swimming',
    'Table Tennis',
    'Taekwondo',
    'Tenni-koit',
    'Tennis',
    'Throwball',
    'Triathlon',
    'Tug of War',
    'Volleyball',
    'Water Polo',
    'Weightlifting',
    'Wrestling',
    'Wushu',
    'Yogasana',
  ];

  static const Map<String, List<String>> defaultHierarchy = {
    'combat': [
      'Boxing',
      'Wrestling',
      'Judo',
      'MMA',
      'Karate',
      'Taekwondo',
      'Muay Thai',
      'Kickboxing',
      'Brazilian Jiu-Jitsu',
      'Arm Wrestling',
      'Wushu',
      'Kendo',
      'Pencak Silat',
    ],
    'endurance': [
      'Athletics',
      'Athletics (Track & Field)',
      'Cross Country',
      'Marathon',
      'Triathlon',
      'Cycling',
      'Swimming',
      'Rowing',
      'Canoeing',
      'Kayaking',
      'Race Walking',
      'Artistic Swimming',
    ],
    'fitness': [
      'Weightlifting',
      'Powerlifting',
      'CrossFit',
      'Bodybuilding',
      'Gymnastics',
      'Yogasana',
      'Mallakhamb',
    ],
    'outdoor': [
      'Sport Climbing',
      'Mountaineering',
      'Hiking',
      'Skateboarding',
      'Skiing',
      'Snowboarding',
      'Surfing',
      'Diving',
      'Sailing',
      'Roller Skating',
      'Ice Skating',
      'Ice Hockey',
    ],
    'racquet': [
      'Badminton',
      'Tennis',
      'Table Tennis',
      'Squash',
      'Padel',
      'Pickleball',
      'Soft Tennis',
      'Tenni-koit',
    ],
    'skill': [
      'Archery',
      'Shooting',
      'Fencing',
      'Golf',
      'Billiards & Snooker',
      'Chess',
      'Bridge',
      'Equestrian',
      'Lawn Bowls',
    ],
    'team': [
      'Football',
      'Cricket',
      'Hockey',
      'Basketball',
      'Volleyball',
      'Rugby',
      'Handball',
      'Baseball',
      'Kabaddi',
      'Kho Kho',
      'Netball',
      'Polo',
      'Sepak Takraw',
      'Softball',
      'Throwball',
      'Tug of War',
      'Water Polo',
    ],
  };

  static const List<String> canonicalCategoryOrder = [
    'Combat',
    'Team',
    'Athletics',
    'Racquet',
    'Adventure',
    'Strength & Fitness',
    'Target',
  ];

  static const Map<String, String> categoryAliases = {
    'combat': 'Combat',
    'team': 'Team',
    'endurance': 'Athletics',
    'athletics': 'Athletics',
    'racquet': 'Racquet',
    'racquet & precision': 'Racquet',
    'outdoor': 'Adventure',
    'adventure': 'Adventure',
    'fitness': 'Strength & Fitness',
    'strength & fitness': 'Strength & Fitness',
    'skill': 'Target',
    'target': 'Target',
  };

  static Map<String, List<String>> _liveHierarchy = Map.from(defaultHierarchy);

  static Map<String, List<String>> get liveHierarchy => _liveHierarchy;

  static void updateHierarchy(Map<String, List<String>> newHierarchy) {
    if (newHierarchy.isNotEmpty) {
      _liveHierarchy = Map.from(newHierarchy);
    }
  }

  static List<String> getCategories() {
    final available = <String>{};
    for (final key in _liveHierarchy.keys) {
      final canonical = categoryAliases[key.toLowerCase()] ??
          (key.isNotEmpty ? key[0].toUpperCase() + key.substring(1) : key);
      available.add(canonical);
    }
    // Return in consistent CATEGORY_ORDER matching D:\Atheleos
    final ordered = canonicalCategoryOrder.where((c) => available.contains(c)).toList();
    if (ordered.isNotEmpty) {
      for (final a in available) {
        if (!ordered.contains(a)) ordered.add(a);
      }
      return ordered;
    }
    return canonicalCategoryOrder;
  }

  static List<String> getSportsForCategory(String category) {
    final key = category.toLowerCase().trim();
    final direct = _liveHierarchy[key] ?? defaultHierarchy[key];
    if (direct != null && direct.isNotEmpty) return direct;

    // Check alias mappings (e.g. Strength & Fitness -> fitness, Athletics -> endurance, Adventure -> outdoor)
    for (final entry in categoryAliases.entries) {
      if (entry.value.toLowerCase() == key || entry.key == key) {
        final aliasMatch = _liveHierarchy[entry.key] ??
            defaultHierarchy[entry.key] ??
            _liveHierarchy[entry.value.toLowerCase()] ??
            defaultHierarchy[entry.value.toLowerCase()];
        if (aliasMatch != null && aliasMatch.isNotEmpty) return aliasMatch;
      }
    }
    return [];
  }

  static List<String> getSports() {
    final all = <String>{};
    for (final list in _liveHierarchy.values) {
      all.addAll(list);
    }
    all.addAll(supportedSports);
    final sorted = all.toList()..sort();
    return sorted;
  }

  static Future<void> loadFromBackend() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('system_data').doc('sports_hierarchy').get();
      if (doc.exists && doc.data() != null) {
        final result = <String, List<String>>{};
        doc.data()!.forEach((k, v) {
          if (v is List) {
            result[k.toLowerCase()] = v.map((e) => e.toString()).toList();
          }
        });
        if (result.isNotEmpty) {
          updateHierarchy(result);
        }
      }
    } catch (_) {}
  }
}

