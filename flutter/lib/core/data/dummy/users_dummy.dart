class DummyUser {
  final String id;
  final String name;
  final String avatar;
  final String sport;
  final String position;
  final String state;
  final String city;
  final String classYear;
  final bool verified;
  final String bio;
  final Map<String, String> stats;
  final List<Map<String, String>> achievements;

  const DummyUser({
    required this.id,
    required this.name,
    required this.avatar,
    required this.sport,
    required this.position,
    required this.state,
    required this.city,
    required this.classYear,
    required this.verified,
    required this.bio,
    required this.stats,
    required this.achievements,
  });
}

final List<DummyUser> dummyUsers = [
  const DummyUser(
    id: 'user_1',
    name: 'Tyler Brooks',
    avatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&q=80&w=200&h=200',
    sport: 'Football',
    position: 'Quarterback (QB)',
    state: 'TX',
    city: 'Dallas',
    classYear: '2026',
    verified: true,
    bio: '6\'3" | 205 lbs | 4.0 GPA. Dual-threat quarterback with elite arm strength and field vision. Looking for a college program focused on excellence and team development.',
    stats: {
      'Passing Yards': '3,450',
      'Touchdowns': '38',
      '40-Yard Dash': '4.52s',
      'Passer Rating': '142.3',
      'Max Squat': '285 lbs',
      'Max Bench': '215 lbs',
    },
    achievements: [
      {'title': 'GPA: 4.0', 'subtitle': 'Top 5% of graduating class', 'icon': 'school'},
      {'title': 'All-State First Team QB', 'subtitle': 'Voted by Texas HS Football Association', 'icon': 'emoji_events'},
      {'title': 'NCAA ID: #2409581', 'subtitle': 'Fully cleared & verified eligibility status', 'icon': 'verified_user'},
    ],
  ),
  const DummyUser(
    id: 'user_2',
    name: 'Sarah Jenkins',
    avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=200&h=200',
    sport: 'Soccer',
    position: 'Striker (ST)',
    state: 'CA',
    city: 'San Diego',
    classYear: '2027',
    verified: true,
    bio: 'Dynamic forward with exceptional dribbling speed and finishing ability. Captain of Varsity team and club team. Multi-year All-Conference selection.',
    stats: {
      'Goals': '24',
      'Assists': '12',
      'Shot Accuracy': '68%',
      'Sprints/Match': '32',
    },
    achievements: [
      {'title': 'All-State Forward', 'subtitle': 'California Soccer Coaches Poll', 'icon': 'emoji_events'},
      {'title': 'Club Championship MVP', 'subtitle': 'Led San Diego Surf to national finals', 'icon': 'sports'},
    ],
  ),
  const DummyUser(
    id: 'user_3',
    name: 'Marcus Thompson',
    avatar: 'https://images.unsplash.com/photo-1544651397-887117144036?auto=format&fit=crop&q=80&w=200&h=200',
    sport: 'Basketball',
    position: 'Point Guard (PG)',
    state: 'FL',
    city: 'Miami',
    classYear: '2027',
    verified: false,
    bio: 'Elite playmaker with excellent court vision, lock-down defensive skills, and a high basketball IQ. Average 18 PPG and 6 APG. College programs, film link is in bio!',
    stats: {
      'PPG': '18.4',
      'APG': '6.2',
      'Steals/Game': '2.3',
      'Free Throw %': '86%',
    },
    achievements: [
      {'title': 'All-Metro PG', 'subtitle': 'Miami Herald High School Sports Awards', 'icon': 'emoji_events'},
    ],
  ),
];
