class User {
  final String id;
  final String? phone;
  final String? email;
  final String displayName;
  final String? avatarUrl;
  final String? coverUrl;
  final String? gender; // MALE, FEMALE, UNKNOWN
  final DateTime? dob;
  final String? bio;
  final String? statusMessage;
  final String? statusMessageType;
  final String? qrCodeUrl;
  final String? region;
  final bool isVerified;
  final bool isOfficialAccount;
  final int followerCount;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? friendshipStatus; // NONE, FRIEND, PENDING_SENT, PENDING_RECEIVED, BLOCKED__BY_ME, etc.

  User({
    required this.id,
    this.phone,
    this.email,
    required this.displayName,
    this.avatarUrl,
    this.coverUrl,
    this.gender,
    this.dob,
    this.bio,
    this.statusMessage,
    this.statusMessageType,
    this.qrCodeUrl,
    this.region,
    this.isVerified = false,
    this.isOfficialAccount = false,
    this.followerCount = 0,
    this.isOnline = false,
    this.lastSeen,
    this.friendshipStatus,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    phone: json['phone'],
    email: json['email'],
    displayName: json['displayName'] ?? json['display_name'] ?? '',
    avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
    coverUrl: json['coverUrl'] ?? json['cover_url'],
    gender: json['gender'],
    dob: json['dob'] != null ? DateTime.parse(json['dob']) : null,
    bio: json['bio'],
    statusMessage: json['statusMessage'] ?? json['status_message'],
    statusMessageType: json['statusMessageType'],
    qrCodeUrl: json['qrCodeUrl'],
    region: json['region'],
    isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
    isOfficialAccount: json['isOfficialAccount'] ?? false,
    followerCount: json['followerCount'] ?? 0,
    isOnline: json['isOnline'] ?? false,
    lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'].toString()) : null,
    friendshipStatus: json['friendshipStatus'] ?? json['friendship_status'],
  );

  User copyWith({
    String? id,
    String? phone,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? coverUrl,
    String? gender,
    DateTime? dob,
    String? bio,
    String? statusMessage,
    String? statusMessageType,
    String? qrCodeUrl,
    String? region,
    bool? isVerified,
    bool? isOfficialAccount,
    int? followerCount,
    bool? isOnline,
    DateTime? lastSeen,
    String? friendshipStatus,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      bio: bio ?? this.bio,
      statusMessage: statusMessage ?? this.statusMessage,
      statusMessageType: statusMessageType ?? this.statusMessageType,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      region: region ?? this.region,
      isVerified: isVerified ?? this.isVerified,
      isOfficialAccount: isOfficialAccount ?? this.isOfficialAccount,
      followerCount: followerCount ?? this.followerCount,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      friendshipStatus: friendshipStatus ?? this.friendshipStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'coverUrl': coverUrl,
    'gender': gender,
    'dob': dob?.toIso8601String(),
    'bio': bio,
    'statusMessage': statusMessage,
    'friendshipStatus': friendshipStatus,
  };
}
