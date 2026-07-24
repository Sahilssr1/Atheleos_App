import '../../domain/models/profile_model.dart';
import '../../domain/repositories/profile_repository.dart';

class DummyProfileRepository implements ProfileRepository {
  // In-memory cache for profiles so state changes persist within the app session
  final List<ProfileModel> _profiles = [
    // 5 Athletes
    const ProfileModel(
      id: 'user_1',
      name: 'Tyler Brooks',
      username: 'tyler_b',
      avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: true,
      sport: 'Football',
      primaryPosition: 'Quarterback',
      clubOrAcademy: 'Dallas Elite Academy',
      city: 'Dallas',
      state: 'TX',
      bio: 'Dual-threat quarterback with elite arm strength and field vision. Captain of the Varsity team. Focus on high team morale and offensive speed.',
      followersCount: 1240,
      followingCount: 342,
      postsCount: 14,
      clipsCount: 8,
      achievements: [
        'All-State First Team QB (Voted by Texas HS Football Association)',
        'State Semifinals MVP (350 passing yards, 4 touchdowns)',
        'Honor Roll - Outstanding Scholar'
      ],
      certifications: [],
      website: 'https://tylerbrooks.athletesites.com',
      socialLinks: {
        'Instagram': '@tyler_b',
        'Twitter': '@tylerb_qb',
      },
      resumeFileName: 'Tyler_Brooks_Athletic_CV.pdf',
      height: 191.0, // cm (~6'3")
      weight: 93.0, // kg (~205 lbs)
      mediaGallery: [
        'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&q=80&w=800',
        'https://images.unsplash.com/photo-1541252260730-0412e8e2108e?auto=format&fit=crop&q=80&w=800',
        'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&q=80&w=800',
      ],
    ),
    const ProfileModel(
      id: 'user_2',
      name: 'Sarah Jenkins',
      username: 'sarah_j',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1508847154043-be12a26c86c1?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: true,
      sport: 'Soccer',
      primaryPosition: 'Striker',
      clubOrAcademy: 'San Diego Surf SC',
      city: 'San Diego',
      state: 'CA',
      bio: 'Dynamic forward with exceptional dribbling speed and clinical finishing. Captain of Varsity and San Diego regional selection teams. High work rate.',
      followersCount: 980,
      followingCount: 215,
      postsCount: 22,
      clipsCount: 12,
      achievements: [
        'All-State Forward (California Soccer Coaches Poll)',
        'Club Championship MVP',
        'Top Goalscorer of Surf Cup 2025'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Instagram': '@sarah_jenks',
      },
      resumeFileName: null,
      height: 170.0,
      weight: 60.0,
      mediaGallery: [
        'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&q=80&w=800',
      ],
    ),
    const ProfileModel(
      id: 'user_3',
      name: 'Marcus Thompson',
      username: 'marcus_t',
      avatarUrl: 'https://images.unsplash.com/photo-1544651397-887117144036?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: false,
      sport: 'Basketball',
      primaryPosition: 'Point Guard',
      clubOrAcademy: 'Miami Hoopstars',
      city: 'Miami',
      state: 'FL',
      bio: 'Elite playmaker with exceptional court vision, lock-down defensive skills, and high basketball IQ. Average 18 PPG and 6 APG.',
      followersCount: 1840,
      followingCount: 510,
      postsCount: 35,
      clipsCount: 19,
      achievements: [
        'All-Metro First Team PG (Miami Herald High School Sports Awards)',
        'State Runner-up 2025'
      ],
      certifications: [],
      website: 'https://marcusthompson.com',
      socialLinks: {
        'Instagram': '@m_thompson_hoops',
        'TikTok': '@marcus_t_clips',
      },
      resumeFileName: 'Marcus_Thompson_CV.pdf',
      height: 188.0,
      weight: 82.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_4',
      name: 'Elena Rostova',
      username: 'elena_r',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1502224562085-639556652f33?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: true,
      sport: 'Track & Field',
      primaryPosition: 'Sprinter (100m/200m)',
      clubOrAcademy: 'Austin Speed Club',
      city: 'Austin',
      state: 'TX',
      bio: '100m and 200m specialist. Focused on mechanics, explosive starts, and high-speed endurance. Junior Olympic Qualifier.',
      followersCount: 2100,
      followingCount: 450,
      postsCount: 18,
      clipsCount: 5,
      achievements: [
        'TX State 100m Silver Medalist',
        'AAU Junior Olympic 100m Finalist'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Instagram': '@elena_runs',
      },
      resumeFileName: null,
      height: 172.0,
      weight: 58.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_5',
      name: 'Jake Harper',
      username: 'jake_h',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1530541930197-ff16ac917b0e?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: false,
      sport: 'Baseball',
      primaryPosition: 'Pitcher',
      clubOrAcademy: 'NorCal Baseball Club',
      city: 'Sacramento',
      state: 'CA',
      bio: 'LHP with 4-seam fastball (92mph), slider, and circle changeup. Command-oriented with a high strikeout ratio.',
      followersCount: 640,
      followingCount: 180,
      postsCount: 8,
      clipsCount: 4,
      achievements: [
        'All-League Pitcher of the Year',
        'Perfect Game Showcase Invitee'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Twitter': '@jakeharper_lhp',
      },
      resumeFileName: null,
      height: 193.0,
      weight: 88.0,
      mediaGallery: [],
    ),

    // 2 Coaches
    const ProfileModel(
      id: 'coach_1',
      name: 'Coach David Miller',
      username: 'coach_miller',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&q=80&w=800',
      role: 'Coach',
      verified: true,
      sport: 'Football',
      primaryPosition: 'Head Coach / offensive Coordinator',
      clubOrAcademy: 'Lone Star Football Academy',
      city: 'Austin',
      state: 'TX',
      bio: 'Former Division 1 Football Coach with 15+ years of experience developing elite high school and collegiate athletes. Passionate about quarterback passing mechanics and zone blocking schemes.',
      followersCount: 4200,
      followingCount: 820,
      postsCount: 54,
      clipsCount: 12,
      achievements: [
        'Developed 8 NFL Draft selections',
        '3x State Championship Coach',
        'Coached Elite 11 regional standouts'
      ],
      certifications: [
        'USA Football Level 3 Certified Coach',
        'NCAA Division 1 Coaching Compliance Certificate',
        'First Aid / CPR Certified'
      ],
      experienceYears: 15,
      website: 'https://lonestarfootball.academy',
      socialLinks: {
        'Twitter': '@coach_miller_tx',
      },
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'coach_2',
      name: 'Coach Maria Santos',
      username: 'coach_maria',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1508847154043-be12a26c86c1?auto=format&fit=crop&q=80&w=800',
      role: 'Coach',
      verified: true,
      sport: 'Soccer',
      primaryPosition: 'Director of Coaching',
      clubOrAcademy: 'Barcelona Elite Academy US',
      city: 'Miami',
      state: 'FL',
      bio: 'UEFA B Licensed Coach and former professional Spanish league player. Over 10 years of youth academy experience, specializing in tactical midfield systems and defensive discipline.',
      followersCount: 3100,
      followingCount: 450,
      postsCount: 41,
      clipsCount: 8,
      achievements: [
        'Florida State Cup Champion 2024',
        'Former Professional Player in Liga F'
      ],
      certifications: [
        'UEFA B Coaching License',
        'USSF A License',
        'Tactical Analysis Diploma'
      ],
      experienceYears: 10,
      website: 'https://barcaeliteus.com',
      socialLinks: {
        'Instagram': '@mariasantos_coach',
      },
      mediaGallery: [],
    ),

    // 2 Brands/Federations
    const ProfileModel(
      id: 'brand_1',
      name: 'Under Armour Next',
      username: 'uanext',
      avatarUrl: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1541252260730-0412e8e2108e?auto=format&fit=crop&q=80&w=800',
      role: 'Brand',
      verified: true,
      sport: 'All',
      primaryPosition: '',
      clubOrAcademy: '',
      city: 'Baltimore',
      state: 'MD',
      bio: 'Supporting the next generation of elite athletes. Discover events, sports combines, gear, and connect with UA mentors. Empowering athletes to achieve their ultimate potential.',
      followersCount: 25400,
      followingCount: 120,
      postsCount: 184,
      clipsCount: 56,
      achievements: [
        'Sponsors of Elite High School Showcases',
        'Provided over \$1M in youth sports grants and training gear'
      ],
      certifications: [],
      website: 'https://next.underarmour.com',
      socialLinks: {
        'Instagram': '@uanext',
        'Twitter': '@uanext_official',
      },
      industry: 'Sports Apparel & Events',
      organizationName: 'Under Armour Next',
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'brand_2',
      name: 'Texas HS Coaches Association',
      username: 'thsca_coaches',
      avatarUrl: 'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&q=80&w=800',
      role: 'Federation',
      verified: true,
      sport: 'All',
      primaryPosition: '',
      clubOrAcademy: '',
      city: 'Austin',
      state: 'TX',
      bio: 'The official federation for Texas high school coaches and student-athletes. Dedicated to promoting high school sports excellence, safety guidelines, and leadership skills.',
      followersCount: 18200,
      followingCount: 85,
      postsCount: 112,
      clipsCount: 18,
      achievements: [
        'Organizers of the annual Coaching School & Convention',
        'Supports 20,000+ active coaches across Texas high schools'
      ],
      certifications: [],
      website: 'https://www.thsca.com',
      socialLinks: {
        'Twitter': '@thsca_coaches',
      },
      industry: 'High School Sports Federation',
      organizationName: 'THSCA',
      mediaGallery: [],
    ),
  ];

  @override
  Future<ProfileModel?> getProfileById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _profiles.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ProfileModel>> getAllProfiles() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.from(_profiles);
  }

  @override
  Future<void> updateProfile(ProfileModel profile) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      _profiles[index] = profile;
    } else {
      _profiles.add(profile);
    }
  }
}
