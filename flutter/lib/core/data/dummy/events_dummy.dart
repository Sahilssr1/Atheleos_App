class DummyEvent {
  final String id;
  final String title;
  final String organizer;
  final String sport;
  final String type;
  final String location;
  final String date;
  final String description;
  final int registeredCount;
  final bool isRegistered;

  const DummyEvent({
    required this.id,
    required this.title,
    required this.organizer,
    required this.sport,
    required this.type,
    required this.location,
    required this.date,
    required this.description,
    required this.registeredCount,
    required this.isRegistered,
  });

  DummyEvent copyWith({
    bool? isRegistered,
    int? registeredCount,
  }) {
    return DummyEvent(
      id: id,
      title: title,
      organizer: organizer,
      sport: sport,
      type: type,
      location: location,
      date: date,
      description: description,
      registeredCount: registeredCount ?? this.registeredCount,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }
}

final List<DummyEvent> dummyEvents = [
  const DummyEvent(
    id: 'event_1',
    title: 'Texas Gridiron Elite Combine',
    organizer: 'Lone Star Recruiting Group',
    sport: 'Football',
    type: 'Combine',
    location: 'AT&T Stadium, Dallas TX',
    date: 'July 15, 2026',
    description: 'The premier showcase for high school athletes looking to measure verified athletic benchmarks (40-yard dash, vertical jump, shuttle, broad jump) in front of college scouts and recruiters.',
    registeredCount: 184,
    isRegistered: false,
  ),
  const DummyEvent(
    id: 'event_2',
    title: 'National Underclassmen Basketball Camp',
    organizer: 'Hoops Prospect Association',
    sport: 'Basketball',
    type: 'Camp',
    location: 'Austin Convention Center, Austin TX',
    date: 'August 3, 2026',
    description: 'Three days of high-intensity basketball instruction, 5-on-5 scrimmages, and recruiting seminars led by former NCAA coaches. Film package included with registration.',
    registeredCount: 92,
    isRegistered: true,
  )
];
