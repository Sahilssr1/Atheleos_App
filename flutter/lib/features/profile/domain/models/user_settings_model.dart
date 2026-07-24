import 'package:cloud_firestore/cloud_firestore.dart';

/// Granular privacy toggles — profiles are always public.
/// Only specific fields can be hidden.
class PrivacySettings {
  final bool hideEmail;
  final bool hidePhone;
  final bool hideDob;
  final bool hideHeight;
  final bool hideWeight;
  final bool hidePerformanceRating;
  final bool hidePersonalNotes;

  const PrivacySettings({
    this.hideEmail = false,
    this.hidePhone = false,
    this.hideDob = true, // hidden by default per spec
    this.hideHeight = true,
    this.hideWeight = true,
    this.hidePerformanceRating = false,
    this.hidePersonalNotes = false,
  });

  PrivacySettings copyWith({
    bool? hideEmail,
    bool? hidePhone,
    bool? hideDob,
    bool? hideHeight,
    bool? hideWeight,
    bool? hidePerformanceRating,
    bool? hidePersonalNotes,
  }) {
    return PrivacySettings(
      hideEmail: hideEmail ?? this.hideEmail,
      hidePhone: hidePhone ?? this.hidePhone,
      hideDob: hideDob ?? this.hideDob,
      hideHeight: hideHeight ?? this.hideHeight,
      hideWeight: hideWeight ?? this.hideWeight,
      hidePerformanceRating:
          hidePerformanceRating ?? this.hidePerformanceRating,
      hidePersonalNotes: hidePersonalNotes ?? this.hidePersonalNotes,
    );
  }

  Map<String, dynamic> toMap() => {
        'hideEmail': hideEmail,
        'hidePhone': hidePhone,
        'hideDob': hideDob,
        'hideHeight': hideHeight,
        'hideWeight': hideWeight,
        'hidePerformanceRating': hidePerformanceRating,
        'hidePersonalNotes': hidePersonalNotes,
      };

  factory PrivacySettings.fromMap(Map<String, dynamic> map) {
    return PrivacySettings(
      hideEmail: map['hideEmail'] ?? false,
      hidePhone: map['hidePhone'] ?? false,
      hideDob: map['hideDob'] ?? true,
      hideHeight: map['hideHeight'] ?? true,
      hideWeight: map['hideWeight'] ?? true,
      hidePerformanceRating: map['hidePerformanceRating'] ?? false,
      hidePersonalNotes: map['hidePersonalNotes'] ?? false,
    );
  }
}

/// Messaging access settings.
/// allowedSenders: 'everyone' | 'followers' | 'nobody'
class MessagingSettings {
  final String allowedSenders;
  final bool allowMessageRequests;
  final bool readReceipts;

  const MessagingSettings({
    this.allowedSenders = 'everyone',
    this.allowMessageRequests = true,
    this.readReceipts = true,
  });

  MessagingSettings copyWith({
    String? allowedSenders,
    bool? allowMessageRequests,
    bool? readReceipts,
  }) {
    return MessagingSettings(
      allowedSenders: allowedSenders ?? this.allowedSenders,
      allowMessageRequests: allowMessageRequests ?? this.allowMessageRequests,
      readReceipts: readReceipts ?? this.readReceipts,
    );
  }

  Map<String, dynamic> toMap() => {
        'allowedSenders': allowedSenders,
        'allowMessageRequests': allowMessageRequests,
        'readReceipts': readReceipts,
      };

  factory MessagingSettings.fromMap(Map<String, dynamic> map) {
    final allowedSenders = map['allowedSenders'] == 'verified'
        ? 'followers'
        : map['allowedSenders'] ?? 'everyone';
    return MessagingSettings(
      allowedSenders: allowedSenders,
      allowMessageRequests: map['allowMessageRequests'] ?? true,
      readReceipts: map['readReceipts'] ?? true,
    );
  }
}

/// Per-type push notification toggles + master email toggle.
class NotificationSettings {
  final bool likes;
  final bool comments;
  final bool replies;
  final bool newFollowers;
  final bool directMessages;
  final bool verificationUpdates;
  final bool coachInvitations;
  final bool federationAnnouncements;
  final bool tournamentInvitations;
  final bool eventReminders;
  final bool collaborationRequests;
  final bool mentions;
  final bool emailNotifications;

  const NotificationSettings({
    this.likes = true,
    this.comments = true,
    this.replies = true,
    this.newFollowers = true,
    this.directMessages = true,
    this.verificationUpdates = true,
    this.coachInvitations = true,
    this.federationAnnouncements = true,
    this.tournamentInvitations = true,
    this.eventReminders = true,
    this.collaborationRequests = true,
    this.mentions = true,
    this.emailNotifications = true,
  });

  NotificationSettings copyWith({
    bool? likes,
    bool? comments,
    bool? replies,
    bool? newFollowers,
    bool? directMessages,
    bool? verificationUpdates,
    bool? coachInvitations,
    bool? federationAnnouncements,
    bool? tournamentInvitations,
    bool? eventReminders,
    bool? collaborationRequests,
    bool? mentions,
    bool? emailNotifications,
  }) {
    return NotificationSettings(
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      replies: replies ?? this.replies,
      newFollowers: newFollowers ?? this.newFollowers,
      directMessages: directMessages ?? this.directMessages,
      verificationUpdates: verificationUpdates ?? this.verificationUpdates,
      coachInvitations: coachInvitations ?? this.coachInvitations,
      federationAnnouncements:
          federationAnnouncements ?? this.federationAnnouncements,
      tournamentInvitations:
          tournamentInvitations ?? this.tournamentInvitations,
      eventReminders: eventReminders ?? this.eventReminders,
      collaborationRequests:
          collaborationRequests ?? this.collaborationRequests,
      mentions: mentions ?? this.mentions,
      emailNotifications: emailNotifications ?? this.emailNotifications,
    );
  }

  Map<String, dynamic> toMap() => {
        'likes': likes,
        'comments': comments,
        'replies': replies,
        'newFollowers': newFollowers,
        'directMessages': directMessages,
        'verificationUpdates': verificationUpdates,
        'coachInvitations': coachInvitations,
        'federationAnnouncements': federationAnnouncements,
        'tournamentInvitations': tournamentInvitations,
        'eventReminders': eventReminders,
        'collaborationRequests': collaborationRequests,
        'mentions': mentions,
        'emailNotifications': emailNotifications,
      };

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      likes: map['likes'] ?? true,
      comments: map['comments'] ?? true,
      replies: map['replies'] ?? true,
      newFollowers: map['newFollowers'] ?? true,
      directMessages: map['directMessages'] ?? true,
      verificationUpdates: map['verificationUpdates'] ?? true,
      coachInvitations: map['coachInvitations'] ?? true,
      federationAnnouncements: map['federationAnnouncements'] ?? true,
      tournamentInvitations: map['tournamentInvitations'] ?? true,
      eventReminders: map['eventReminders'] ?? true,
      collaborationRequests: map['collaborationRequests'] ?? true,
      mentions: map['mentions'] ?? true,
      emailNotifications: map['emailNotifications'] ?? true,
    );
  }
}

/// App-level UI preferences (also synced to Firestore).
class AppPreferences {
  final String theme; // 'dark' | 'light' | 'system'
  final String language; // 'en' | 'es' | 'fr' | 'pt'
  final String units; // 'metric' | 'imperial'
  final String timeZone;

  const AppPreferences({
    this.theme = 'dark',
    this.language = 'en',
    this.units = 'metric',
    this.timeZone = 'UTC',
  });

  AppPreferences copyWith({
    String? theme,
    String? language,
    String? units,
    String? timeZone,
  }) {
    return AppPreferences(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      units: units ?? this.units,
      timeZone: timeZone ?? this.timeZone,
    );
  }

  Map<String, dynamic> toMap() => {
        'theme': theme,
        'language': language,
        'units': units,
        'timeZone': timeZone,
      };

  factory AppPreferences.fromMap(Map<String, dynamic> map) {
    return AppPreferences(
      theme: map['theme'] ?? 'dark',
      language: map['language'] ?? 'en',
      units: map['units'] ?? 'metric',
      timeZone: map['timeZone'] ?? 'UTC',
    );
  }
}

/// Root settings model synced to Firestore:
/// /users/{userId}/settings/preferences
class UserSettingsModel {
  final PrivacySettings privacy;
  final MessagingSettings messaging;
  final NotificationSettings notifications;
  final AppPreferences appPreferences;
  final DateTime? updatedAt;

  const UserSettingsModel({
    this.privacy = const PrivacySettings(),
    this.messaging = const MessagingSettings(),
    this.notifications = const NotificationSettings(),
    this.appPreferences = const AppPreferences(),
    this.updatedAt,
  });

  UserSettingsModel copyWith({
    PrivacySettings? privacy,
    MessagingSettings? messaging,
    NotificationSettings? notifications,
    AppPreferences? appPreferences,
    DateTime? updatedAt,
  }) {
    return UserSettingsModel(
      privacy: privacy ?? this.privacy,
      messaging: messaging ?? this.messaging,
      notifications: notifications ?? this.notifications,
      appPreferences: appPreferences ?? this.appPreferences,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'privacy': privacy.toMap(),
        'messaging': messaging.toMap(),
        'notifications': notifications.toMap(),
        'appPreferences': appPreferences.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory UserSettingsModel.fromMap(Map<String, dynamic> map) {
    return UserSettingsModel(
      privacy: PrivacySettings.fromMap(
          Map<String, dynamic>.from(map['privacy'] ?? {})),
      messaging: MessagingSettings.fromMap(
          Map<String, dynamic>.from(map['messaging'] ?? {})),
      notifications: NotificationSettings.fromMap(
          Map<String, dynamic>.from(map['notifications'] ?? {})),
      appPreferences: AppPreferences.fromMap(
          Map<String, dynamic>.from(map['appPreferences'] ?? {})),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Default settings applied to new users
  factory UserSettingsModel.defaults() => const UserSettingsModel();
}
