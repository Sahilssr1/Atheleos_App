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

  static Map<String, List<String>> _liveHierarchy = Map.from(defaultHierarchy);

  static Map<String, List<String>> get liveHierarchy => _liveHierarchy;

  static void updateHierarchy(Map<String, List<String>> newHierarchy) {
    if (newHierarchy.isNotEmpty) {
      _liveHierarchy = Map.from(newHierarchy);
    }
  }

  static List<String> getCategories() {
    return _liveHierarchy.keys.map((k) {
      if (k.isEmpty) return k;
      return k[0].toUpperCase() + k.substring(1);
    }).toList();
  }

  static List<String> getSportsForCategory(String category) {
    final key = category.toLowerCase().trim();
    return _liveHierarchy[key] ?? defaultHierarchy[key] ?? [];
  }

  static List<String> getSports() {
    return supportedSports;
  }
}
