class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    this.bio,
    this.facility,
    this.address,
    this.stableName,
    this.avatarUrl,
    this.inviteCode,
    this.canBeTrainer = false,
    this.canBeRider = false,
    this.defaultDurationMinutes = 45,
    this.defaultCapacity = 3,
    this.defaultSlotMode = 'single',
    this.defaultRepeat = 'Einmalig',
    this.bookingLeadHours = 12,
    this.reminderHours = 2,
    this.allowRequests = false,
  });

  final String id;
  final String role; // 'trainer' | 'rider' — which view is currently active
  final String fullName;
  final String? bio;
  final String? facility; // trainer: display name of their venue
  final String? address; // trainer: postal address, for "In Karten öffnen"
  final String? stableName; // rider: home stable
  final String? avatarUrl;
  final String? inviteCode;

  /// Whether this account has activated the trainer/rider role at all —
  /// independent of [role], which is only which one is *currently shown*.
  /// A profile with both true can switch between the two.
  final bool canBeTrainer;
  final bool canBeRider;

  final int defaultDurationMinutes;
  final int defaultCapacity;
  final String defaultSlotMode; // 'single' | 'range' — trainer slot-form default
  final String defaultRepeat; // 'Einmalig' | 'Wöchentlich' | '14-tägig'
  final int bookingLeadHours;
  final int reminderHours;
  final bool allowRequests; // trainer: let linked riders request unlisted times

  bool get isTrainer => role == 'trainer';
  bool get hasDualRole => canBeTrainer && canBeRider;

  /// Public link to this trainer's profile — opens the Galoppal website,
  /// which forwards straight into the app (Universal/App Link) if it's
  /// installed, or to the store + a preview otherwise.
  String get inviteLink =>
      inviteCode == null ? '' : 'https://galoppal.de/t/$inviteCode';

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      role: map['role'] as String,
      fullName: map['full_name'] as String? ?? '',
      bio: map['bio'] as String?,
      facility: map['facility'] as String?,
      address: map['address'] as String?,
      stableName: map['stable_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      inviteCode: map['invite_code'] as String?,
      canBeTrainer: map['is_trainer'] as bool? ?? false,
      canBeRider: map['is_rider'] as bool? ?? false,
      defaultDurationMinutes:
          (map['default_duration_minutes'] as num?)?.toInt() ?? 45,
      defaultCapacity: (map['default_capacity'] as num?)?.toInt() ?? 3,
      defaultSlotMode: map['default_slot_mode'] as String? ?? 'single',
      defaultRepeat: map['default_repeat'] as String? ?? 'Einmalig',
      bookingLeadHours: (map['booking_lead_hours'] as num?)?.toInt() ?? 12,
      reminderHours: (map['reminder_hours'] as num?)?.toInt() ?? 2,
      allowRequests: map['allow_requests'] as bool? ?? false,
    );
  }

  Profile copyWith({
    String? role,
    String? bio,
    String? facility,
    String? address,
    String? stableName,
    String? avatarUrl,
    String? inviteCode,
    bool? canBeTrainer,
    bool? canBeRider,
    int? defaultDurationMinutes,
    int? defaultCapacity,
    String? defaultSlotMode,
    String? defaultRepeat,
    int? bookingLeadHours,
    int? reminderHours,
    bool? allowRequests,
  }) {
    return Profile(
      id: id,
      role: role ?? this.role,
      fullName: fullName,
      bio: bio ?? this.bio,
      facility: facility ?? this.facility,
      address: address ?? this.address,
      stableName: stableName ?? this.stableName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      inviteCode: inviteCode ?? this.inviteCode,
      canBeTrainer: canBeTrainer ?? this.canBeTrainer,
      canBeRider: canBeRider ?? this.canBeRider,
      defaultDurationMinutes:
          defaultDurationMinutes ?? this.defaultDurationMinutes,
      defaultCapacity: defaultCapacity ?? this.defaultCapacity,
      defaultSlotMode: defaultSlotMode ?? this.defaultSlotMode,
      defaultRepeat: defaultRepeat ?? this.defaultRepeat,
      bookingLeadHours: bookingLeadHours ?? this.bookingLeadHours,
      reminderHours: reminderHours ?? this.reminderHours,
      allowRequests: allowRequests ?? this.allowRequests,
    );
  }
}
