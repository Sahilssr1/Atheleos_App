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
    title: 'National Athletics Championship Trials',
    organizer: 'Athletics Federation of India',
    sport: 'Athletics',
    type: 'Selection Camp',
    location: 'Jawaharlal Nehru Stadium, New Delhi',
    date: '15 July 2026',
    description: 'Official selection trials for sprinters and field athletes. Certified electronic timing across 100m, 200m, long jump, and shot put for state and national squad shortlisting.',
    registeredCount: 184,
    isRegistered: false,
  ),
  const DummyEvent(
    id: 'event_2',
    title: 'All India Youth Basketball Championship',
    organizer: 'Basketball Federation of India',
    sport: 'Basketball',
    type: 'Tournament',
    location: 'Kanteerava Indoor Stadium, Bengaluru',
    date: '3 August 2026',
    description: 'Premier youth basketball tournament featuring top state and academy teams. 5-on-5 competitive format with certified BFI referees and academy scouts.',
    registeredCount: 92,
    isRegistered: true,
  )
];
