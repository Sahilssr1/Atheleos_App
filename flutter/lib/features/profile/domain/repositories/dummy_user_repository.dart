import '../../domain/models/profile_model.dart';
import '../../domain/repositories/user_repository.dart';

class DummyUserRepository implements UserRepository {
  // In-memory list of 28 users: 15 Athletes, 5 Coaches, 5 Brands, 3 Federations
  final List<ProfileModel> _users = [
    // === 15 ATHLETES ===
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
      height: 191.0,
      weight: 93.0,
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
    const ProfileModel(
      id: 'user_6',
      name: 'Chloe Bennett',
      username: 'chloe_b',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: true,
      sport: 'Volleyball',
      primaryPosition: 'Outside Hitter',
      clubOrAcademy: 'Chicago Windy City VBC',
      city: 'Chicago',
      state: 'IL',
      bio: 'High-flying outside hitter with a 10-foot reach. Powerful spikes and solid defensive blocks. 3-year Varsity starter.',
      followersCount: 1450,
      followingCount: 290,
      postsCount: 19,
      clipsCount: 6,
      achievements: [
        'All-Metro First Team (Chicago Tribune)',
        'Windy City Classic Tournament MVP 2025'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Instagram': '@chloe_volleys',
      },
      height: 185.0,
      weight: 70.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_7',
      name: 'Lamar Jackson Jr.',
      username: 'lamar_jr',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1562088287-bde35a1ea917?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: false,
      sport: 'Football',
      primaryPosition: 'Wide Receiver',
      clubOrAcademy: 'Atlanta Speed Academy',
      city: 'Atlanta',
      state: 'GA',
      bio: 'Explosive wide receiver with 4.4s 40-yard dash. Exceptional route running, great catch radius, and physical play style.',
      followersCount: 1750,
      followingCount: 420,
      postsCount: 25,
      clipsCount: 14,
      achievements: [
        'All-Region WR First Team',
        'Georgia state track finalist (200m sprint)'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Twitter': '@lamar_jr_wr',
      },
      height: 188.0,
      weight: 85.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_8',
      name: 'Emily Chen',
      username: 'emily_c',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: true,
      sport: 'Tennis',
      primaryPosition: 'Singles Player',
      clubOrAcademy: 'Silicon Valley Tennis Academy',
      city: 'San Jose',
      state: 'CA',
      bio: 'Aggressive baseline player with a powerful forehand and high-percentage first serves. Nationally ranked Top 50 U18.',
      followersCount: 1210,
      followingCount: 195,
      postsCount: 30,
      clipsCount: 11,
      achievements: [
        'NorCal Junior Sectionals Champion',
        'USTA National L2 Finalist'
      ],
      certifications: [],
      website: 'https://emilychentennis.com',
      socialLinks: {
        'Instagram': '@emily_tennis_chen',
      },
      height: 173.0,
      weight: 62.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_9',
      name: 'Carlos Mendez',
      username: 'carlos_m',
      avatarUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1431324155629-1a6edd1d141d?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: false,
      sport: 'Soccer',
      primaryPosition: 'Midfielder',
      clubOrAcademy: 'LA Galaxy Youth Academy',
      city: 'Los Angeles',
      state: 'CA',
      bio: 'Playmaking central midfielder. High tactical intelligence, short passing mastery, and creative playmaker.',
      followersCount: 2200,
      followingCount: 380,
      postsCount: 45,
      clipsCount: 20,
      achievements: [
        'MLS NEXT Cup Best XI Midfielder',
        'LA Galaxy Academy Captain'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Instagram': '@carlos_m_mid',
      },
      height: 178.0,
      weight: 71.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_10',
      name: 'Justin Reyes',
      username: 'justin_r',
      avatarUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1519766304817-4f37bda74a27?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: true,
      sport: 'Basketball',
      primaryPosition: 'Shooting Guard',
      clubOrAcademy: 'Brooklyn United Hoops',
      city: 'Brooklyn',
      state: 'NY',
      bio: 'Pure sharpshooter with deep three-point range and strong defensive hustle. Lead league in 3PT% (46%).',
      followersCount: 1590,
      followingCount: 310,
      postsCount: 21,
      clipsCount: 9,
      achievements: [
        'NYC PSAL Scoring Champion (22.5 PPG)',
        'All-City First Team Guard'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Instagram': '@justin_reyes_hoops',
      },
      height: 196.0,
      weight: 88.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_11',
      name: 'Sophia Martinez',
      username: 'sophia_m',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1502224562085-639556652f33?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: true,
      sport: 'Softball',
      primaryPosition: 'Shortstop',
      clubOrAcademy: 'Arizona Thunder',
      city: 'Phoenix',
      state: 'AZ',
      bio: 'Defensive powerhouse at shortstop with quick release and outstanding range. Leadoff batter with .480 OBP.',
      followersCount: 880,
      followingCount: 190,
      postsCount: 12,
      clipsCount: 5,
      achievements: [
        'Arizona Gatorade Player of the Year Nominee',
        'All-State First Team SS'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Instagram': '@sophia_mart_sb',
      },
      height: 168.0,
      weight: 59.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_12',
      name: 'Derek Vance',
      username: 'derek_v',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1530541930197-ff16ac917b0e?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: false,
      sport: 'Lacrosse',
      primaryPosition: 'Midfielder',
      clubOrAcademy: 'Baltimore Elite Lax Club',
      city: 'Baltimore',
      state: 'MD',
      bio: 'Two-way midfielder with heavy shot and outstanding physical conditioning. Groundball specialist and faceoff asset.',
      followersCount: 790,
      followingCount: 160,
      postsCount: 15,
      clipsCount: 6,
      achievements: [
        'MIAA All-Conference Midfielder',
        'Under Armour All-America Underclass Select'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Instagram': '@derek_v_lax',
      },
      height: 183.0,
      weight: 80.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_13',
      name: 'Hannah Taylor',
      username: 'hannah_t',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1508847154043-be12a26c86c1?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: true,
      sport: 'Swimming',
      primaryPosition: 'Freestyle (50m/100m)',
      clubOrAcademy: 'Colorado Aquatic Club',
      city: 'Denver',
      state: 'CO',
      bio: 'Sprint freestyle specialist. Focused on explosive dive starts and underwater kicking power. Olympic Trials Qualifier.',
      followersCount: 1150,
      followingCount: 220,
      postsCount: 14,
      clipsCount: 4,
      achievements: [
        'Colorado State 50 Free Champion',
        'Junior Nationals Finalist'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Instagram': '@hannah_swims_fast',
      },
      height: 175.0,
      weight: 63.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_14',
      name: 'Mason Davies',
      username: 'mason_d',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: false,
      sport: 'Wrestling',
      primaryPosition: '170 lbs weight class',
      clubOrAcademy: 'Iowa Iron Grappling',
      city: 'Des Moines',
      state: 'IA',
      bio: 'Highly disciplined wrestler specializing in double leg takedowns and technical pins. Career record: 94-8.',
      followersCount: 920,
      followingCount: 185,
      postsCount: 10,
      clipsCount: 3,
      achievements: [
        'Iowa State Championship Silver Medalist',
        'Fargo All-American Greco-Roman'
      ],
      certifications: [],
      website: '',
      socialLinks: {
        'Twitter': '@mason_d_wrestles',
      },
      height: 180.0,
      weight: 77.0,
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'user_15',
      name: 'Olivia Price',
      username: 'olivia_p',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=800',
      role: 'Athlete',
      verified: true,
      sport: 'Gymnastics',
      primaryPosition: 'All-Around Gymnast',
      clubOrAcademy: 'Seattle Gymnastics Elite',
      city: 'Seattle',
      state: 'WA',
      bio: 'Level 10 All-Around competitor. Specialty in uneven bars and floor exercises. High execution scores and creative choreography.',
      followersCount: 1980,
      followingCount: 340,
      postsCount: 28,
      clipsCount: 12,
      achievements: [
        'Region 2 Level 10 Bars Champion',
        'National Qualifier All-Around'
      ],
      certifications: [],
      website: 'https://oliviapricegymnastics.com',
      socialLinks: {
        'Instagram': '@olivia_gymnastics',
      },
      height: 157.0,
      weight: 48.0,
      mediaGallery: [],
    ),

    // === 5 COACHES ===
    const ProfileModel(
      id: 'coach_1',
      name: 'Coach David Miller',
      username: 'coach_miller',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&q=80&w=800',
      role: 'Coach',
      verified: true,
      sport: 'Football',
      primaryPosition: 'Head Coach / Offensive Coordinator',
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
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=200&h=200',
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
    const ProfileModel(
      id: 'coach_3',
      name: 'Coach James Vance',
      username: 'coach_vance',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=800',
      role: 'Coach',
      verified: true,
      sport: 'Basketball',
      primaryPosition: 'Varsity Head Coach',
      clubOrAcademy: 'Indianapolis Hoops Club',
      city: 'Indianapolis',
      state: 'IN',
      bio: 'Dedicated Varsity Head Coach with over 12 years of coaching championship-caliber high school basketball programs.',
      followersCount: 2800,
      followingCount: 390,
      postsCount: 33,
      clipsCount: 7,
      achievements: [
        'Indiana Coach of the Year 2024',
        '2x State Champions (Class 4A)'
      ],
      certifications: [
        'USAB Gold Licensed Coach',
        'NFHS Accredited Interscholastic Coach'
      ],
      experienceYears: 12,
      website: 'https://indyhoops.co',
      socialLinks: {
        'Twitter': '@coachvance_hoops',
      },
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'coach_4',
      name: 'Coach Sarah Thompson',
      username: 'coach_sarah_t',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1502224562085-639556652f33?auto=format&fit=crop&q=80&w=800',
      role: 'Coach',
      verified: true,
      sport: 'Track & Field',
      primaryPosition: 'Sprint & Speed Specialist',
      clubOrAcademy: 'Oregon Speed Club',
      city: 'Eugene',
      state: 'OR',
      bio: 'USATF Level 2 certified sprint coach. Helping athletes master mechanics, acceleration profiles, and maximum velocity.',
      followersCount: 3400,
      followingCount: 510,
      postsCount: 48,
      clipsCount: 15,
      achievements: [
        'Coached 4 Olympic Trials qualifiers',
        'Developed 12 State Champions'
      ],
      certifications: [
        'USATF Level 2 Certified Coach (Sprints)',
        'USTFCCCA Strength and Conditioning Specialist'
      ],
      experienceYears: 14,
      website: 'https://oregonspeed.org',
      socialLinks: {
        'Instagram': '@coach_saraht_speed',
      },
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'coach_5',
      name: 'Coach Robert Chen',
      username: 'coach_robert',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&q=80&w=800',
      role: 'Coach',
      verified: false,
      sport: 'Tennis',
      primaryPosition: 'Elite High Performance Coach',
      clubOrAcademy: 'Vegas Tennis Excellence',
      city: 'Las Vegas',
      state: 'NV',
      bio: 'Former professional ATP player. Offering master-level tactical training and physical conditioning blueprints for elite youth players.',
      followersCount: 1950,
      followingCount: 240,
      postsCount: 29,
      clipsCount: 5,
      achievements: [
        'Coached 3 players to Division 1 scholarships',
        'Former NCAA Singles Champion'
      ],
      certifications: [
        'USPTA Elite Professional Certification',
        'PTR High Performance Diploma'
      ],
      experienceYears: 8,
      website: 'https://vegastennis.com',
      socialLinks: {
        'Twitter': '@coachrobert_tennis',
      },
      mediaGallery: [],
    ),

    // === 5 BRANDS ===
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
      name: 'Nike Elite Youth',
      username: 'nike_eybl',
      avatarUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=800',
      role: 'Brand',
      verified: true,
      sport: 'Basketball & All',
      primaryPosition: '',
      clubOrAcademy: '',
      city: 'Beaverton',
      state: 'OR',
      bio: 'Official page of Nike Elite Youth Basketball League (EYBL). Developing, testing, and supporting elite next-gen athletes globally.',
      followersCount: 54100,
      followingCount: 150,
      postsCount: 310,
      clipsCount: 92,
      achievements: [
        'Organizers of the Nike EYBL Circuit and Peach Jam Tournament',
        'Supports 40+ grassroots organizations nationwide'
      ],
      certifications: [],
      website: 'https://www.nikeeybl.com',
      socialLinks: {
        'Instagram': '@nikeeybl',
        'Twitter': '@nikeeybl',
      },
      industry: 'Athletic Footwear & Sports Development',
      organizationName: 'Nike EYBL',
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'brand_3',
      name: 'Adidas Grassroots',
      username: 'adidas_grassroots',
      avatarUrl: 'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&q=80&w=800',
      role: 'Brand',
      verified: true,
      sport: 'All',
      primaryPosition: '',
      clubOrAcademy: '',
      city: 'Portland',
      state: 'OR',
      bio: 'Creating community through sport. Sponsoring 3SSB circuits and community tournaments to elevate athletic potential at every level.',
      followersCount: 34800,
      followingCount: 110,
      postsCount: 220,
      clipsCount: 45,
      achievements: [
        'Organizers of the Adidas 3SSB basketball circuit',
        'Global creators of community sports pitch facilities'
      ],
      certifications: [],
      website: 'https://adidas.com/grassroots',
      socialLinks: {
        'Instagram': '@adidasgrassroots',
      },
      industry: 'Sports Lifestyle & Performance Wear',
      organizationName: 'Adidas Grassroots',
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'brand_4',
      name: 'Gatorade Performance',
      username: 'gatorade_performance',
      avatarUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1530541930197-ff16ac917b0e?auto=format&fit=crop&q=80&w=800',
      role: 'Brand',
      verified: true,
      sport: 'All',
      primaryPosition: '',
      clubOrAcademy: '',
      city: 'Chicago',
      state: 'IL',
      bio: 'Fueling champions since 1965. Scientifically formulated performance drinks and clinical hydration solutions for extreme athletic output.',
      followersCount: 41200,
      followingCount: 95,
      postsCount: 198,
      clipsCount: 38,
      achievements: [
        'Creators of the Gatorade Sports Science Institute (GSSI)',
        'Sponsors of the Gatorade Player of the Year awards'
      ],
      certifications: [],
      website: 'https://gatorade.com',
      socialLinks: {
        'Twitter': '@gatorade',
      },
      industry: 'Sports Nutrition & Hydration',
      organizationName: 'The Gatorade Company',
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'brand_5',
      name: 'Wilson Sporting Goods',
      username: 'wilson_sports',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1431324155629-1a6edd1d141d?auto=format&fit=crop&q=80&w=800',
      role: 'Brand',
      verified: true,
      sport: 'All',
      primaryPosition: '',
      clubOrAcademy: '',
      city: 'Chicago',
      state: 'IL',
      bio: 'The heart and hand of sport. Crafters of premium performance ball equipment for Tennis, Football, Basketball, Golf, and Soccer.',
      followersCount: 29400,
      followingCount: 105,
      postsCount: 142,
      clipsCount: 22,
      achievements: [
        'Official match ball provider of the NBA and NFL',
        'Official racket and ball of US Open Tennis Championship'
      ],
      certifications: [],
      website: 'https://wilson.com',
      socialLinks: {
        'Instagram': '@wilsonsports',
      },
      industry: 'Sports Equipment Manufacturing',
      organizationName: 'Wilson Sporting Goods',
      mediaGallery: [],
    ),

    // === 3 FEDERATIONS ===
    const ProfileModel(
      id: 'federation_1',
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
    const ProfileModel(
      id: 'federation_2',
      name: 'USA Youth Soccer Federation',
      username: 'usa_youth_soccer',
      avatarUrl: 'https://images.unsplash.com/photo-1508847154043-be12a26c86c1?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&q=80&w=800',
      role: 'Federation',
      verified: true,
      sport: 'Soccer',
      primaryPosition: '',
      clubOrAcademy: '',
      city: 'Colorado Springs',
      state: 'CO',
      bio: 'Developing elite youth soccer across America. Underpinning state youth soccer associations and sanctioning national youth leagues and championships.',
      followersCount: 22100,
      followingCount: 90,
      postsCount: 154,
      clipsCount: 25,
      achievements: [
        'Sanctioning body for the US Youth Soccer National Championship Series',
        'Provides athletic and tactical education for 1.5 million players'
      ],
      certifications: [],
      website: 'https://www.usyouthsoccer.org',
      socialLinks: {
        'Instagram': '@usyouthsoccer',
      },
      industry: 'National Youth Soccer Federation',
      organizationName: 'USYS',
      mediaGallery: [],
    ),
    const ProfileModel(
      id: 'federation_3',
      name: 'AAU National Basketball',
      username: 'aau_basketball',
      avatarUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=200&h=200',
      coverUrl: 'https://images.unsplash.com/photo-1544651397-887117144036?auto=format&fit=crop&q=80&w=200&h=200',
      role: 'Federation',
      verified: true,
      sport: 'Basketball',
      primaryPosition: '',
      clubOrAcademy: '',
      city: 'Orlando',
      state: 'FL',
      bio: 'Amateur Athletic Union (AAU) Basketball department. Sanctioning national tournaments, grade-level championships, and scouting showcases to build college-bound basketball stars.',
      followersCount: 31400,
      followingCount: 140,
      postsCount: 245,
      clipsCount: 52,
      achievements: [
        'Organizers of the AAU Boys & Girls National Championships',
        'Official development partner for professional scouting pipelines'
      ],
      certifications: [],
      website: 'https://www.aaubasketball.org',
      socialLinks: {
        'Instagram': '@aaubasketball',
        'Twitter': '@aaubasketball',
      },
      industry: 'National Amateur Athletic Union Division',
      organizationName: 'Amateur Athletic Union Basketball',
      mediaGallery: [],
    ),
  ];

  @override
  Future<ProfileModel?> getUserById(String id) async {
    // Return matching user or null
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ProfileModel?> getCurrentUser() async {
    // Current user is tyler_b (user_1)
    return getUserById('user_1');
  }

  @override
  Future<List<ProfileModel>> getAllUsers({int limit = 50}) async {
    return _users.take(limit).toList();
  }

  @override
  Future<List<ProfileModel>> getUsersByRole(String role, {int limit = 50}) async {
    return _users
        .where((u) => u.role.toLowerCase() == role.toLowerCase())
        .take(limit)
        .toList();
  }

  @override
  Future<void> updateFollowState(String userId, bool isFollowing) async {
    final index = _users.indexWhere((u) => u.id == userId);
    final myIndex = _users.indexWhere((u) => u.id == 'user_1');

    if (index != -1 && myIndex != -1) {
      final target = _users[index];
      final me = _users[myIndex];

      // Prevent self-following
      if (userId == me.id) return;

      // If state actually changes
      if (target.isFollowing != isFollowing) {
        // Update target followers count
        final newFollowersCount = isFollowing
            ? target.followersCount + 1
            : target.followersCount - 1;

        // Update my following count
        final newFollowingCount = isFollowing
            ? me.followingCount + 1
            : me.followingCount - 1;

        _users[index] = target.copyWith(
          isFollowing: isFollowing,
          followersCount: newFollowersCount,
        );

        _users[myIndex] = me.copyWith(
          followingCount: newFollowingCount,
        );
      }
    }
  }

  @override
  Future<void> updateUser(ProfileModel user) async {
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
    }
  }

  @override
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    final targetIndex = _users.indexWhere((u) => u.id == targetUserId);
    if (targetIndex != -1) {
      final user = _users[targetIndex];
      _users[targetIndex] = user.copyWith(
        followersCount: user.followersCount + 1,
      );
    }
  }

  @override
  Future<void> incrementProfileViews(String uid) async {}

  @override
  Future<void> incrementPortfolioShares(String uid) async {}

  @override
  Future<List<ProfileModel>> searchUsers({
    required String query,
    required String sport,
    required String role,
    required String state,
    required String city,
    required bool onlyVerified,
  }) async {
    return _users.where((user) {
      final matchesQuery = query.isEmpty ||
          user.name.toLowerCase().contains(query.toLowerCase()) ||
          user.username.toLowerCase().contains(query.toLowerCase()) ||
          user.primaryPosition.toLowerCase().contains(query.toLowerCase()) ||
          user.bio.toLowerCase().contains(query.toLowerCase());
      final matchesSport = sport == 'All' || user.sport == sport;
      final matchesRole = role == 'All' || user.role == role;
      final matchesState = state == 'All' || user.state == state;
      final matchesCity = city.isEmpty || user.city.toLowerCase().contains(city.toLowerCase());
      final matchesVerified = !onlyVerified || user.verified;
      return matchesQuery && matchesSport && matchesRole && matchesState && matchesCity && matchesVerified;
    }).toList();
  }
}
