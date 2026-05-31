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

  factory User.fromJson(Map<String, dynamic> json) {
    // Support multiple field name variations
    final id = json['id']?.toString() ?? '';
    final displayName = json['displayName']?.toString() ?? 
                       json['display_name']?.toString() ?? 
                       json['name']?.toString() ?? 
                       json['username']?.toString() ?? 
                       'User';
    
    // Support multiple avatar field names
    final avatarValue = json['avatarUrl'] ?? 
                        json['avatar_url'] ?? 
                        json['avatar'] ?? 
                        json['profilePicture'] ?? 
                        json['profile_picture'] ?? 
                        json['photoUrl'] ?? 
                        json['photo_url'] ?? 
                        json['imageUrl'] ?? 
                        json['image_url'];
    
    final coverValue = json['coverUrl'] ?? 
                       json['cover_url'] ?? 
                       json['cover'] ?? 
                       json['backgroundUrl'];
    
    return User(
      id: id,
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      displayName: displayName,
      avatarUrl: avatarValue?.toString(),
      coverUrl: coverValue?.toString(),
      gender: json['gender']?.toString(),
      dob: json['dob'] != null ? DateTime.parse(json['dob'].toString()) : null,
      bio: json['bio']?.toString(),
      statusMessage: json['statusMessage']?.toString() ?? json['status_message']?.toString(),
      statusMessageType: json['statusMessageType']?.toString(),
      qrCodeUrl: json['qrCodeUrl']?.toString(),
      region: json['region']?.toString(),
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      isOfficialAccount: json['isOfficialAccount'] ?? json['is_official_account'] ?? false,
      followerCount: json['followerCount'] ?? json['follower_count'] ?? 0,
      isOnline: json['isOnline'] ?? json['is_online'] ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'].toString()) : null,
      friendshipStatus: json['friendshipStatus']?.toString() ?? json['friendship_status']?.toString(),
    );
  }

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
