import 'package:cloud_firestore/cloud_firestore.dart';

class UserData {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String? photoUrl;
  final bool approved;
  final String? doctorId;
  final String? mentorId;
  final Timestamp createdAt;
  final DateTime? lastActivity;
  final Timestamp? assignedAt;
  final Timestamp? disapprovedAt;
  final int? points; // NEW FIELD ADDED for mentor points
  
  // Additional profile fields
  final String? phone;
  final String? bio;
  final String? location;
  final String? specialty; // For doctors
  final String? education; // For doctors/mentors
  final String? experience; // For doctors/mentors
  final List<String>? languages; // Languages spoken
  final String? timezone;
  
  // Privacy settings
  final bool? showEmail;
  final bool? showPhone;
  final bool? showLocation;
  final bool? allowMessages;
  final bool? allowCalls;
  final bool? allowVideoCall;
  
  // Notification settings
  final bool? emailNotifications;
  final bool? pushNotifications;
  final bool? smsNotifications;
  final bool? messageNotifications;
  final bool? appointmentNotifications;
  
  // Professional info (for doctors/mentors)
  final String? licenseNumber;
  final String? certification;
  final List<String>? availableHours;
  final double? rating;
  final int? totalRatings;
  
  // Account status
  final bool? isOnline;
  final bool? isVerified;
  final bool? isActive;
  final DateTime? lastSeen;
  
  UserData({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.photoUrl,
    required this.approved,
    this.doctorId,
    this.mentorId,
    required this.createdAt,
    this.lastActivity,
    this.assignedAt,
    this.disapprovedAt,
    this.points, // NEW FIELD ADDED
    
    // Additional profile fields
    this.phone,
    this.bio,
    this.location,
    this.specialty,
    this.education,
    this.experience,
    this.languages,
    this.timezone,
    
    // Privacy settings
    this.showEmail,
    this.showPhone,
    this.showLocation,
    this.allowMessages,
    this.allowCalls,
    this.allowVideoCall,
    
    // Notification settings
    this.emailNotifications,
    this.pushNotifications,
    this.smsNotifications,
    this.messageNotifications,
    this.appointmentNotifications,
    
    // Professional info
    this.licenseNumber,
    this.certification,
    this.availableHours,
    this.rating,
    this.totalRatings,
    
    // Account status
    this.isOnline,
    this.isVerified,
    this.isActive,
    this.lastSeen,
  });

  factory UserData.fromMap(Map<String, dynamic> map) {
    return UserData(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'mentee',
      photoUrl: map['photoUrl'],
      approved: map['approved'] ?? false,
      doctorId: map['doctorId'],
      mentorId: map['mentorId'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      lastActivity: map['lastActivity'] != null 
          ? (map['lastActivity'] as Timestamp).toDate() 
          : null,
      assignedAt: map['assignedAt'],
      disapprovedAt: map['disapprovedAt'],
      points: map['points'], // NEW FIELD ADDED
      
      // Additional profile fields
      phone: map['phone'],
      bio: map['bio'],
      location: map['location'],
      specialty: map['specialty'],
      education: map['education'],
      experience: map['experience'],
      languages: map['languages'] != null 
          ? List<String>.from(map['languages']) 
          : null,
      timezone: map['timezone'],
      
      // Privacy settings
      showEmail: map['showEmail'] ?? true,
      showPhone: map['showPhone'] ?? false,
      showLocation: map['showLocation'] ?? false,
      allowMessages: map['allowMessages'] ?? true,
      allowCalls: map['allowCalls'] ?? true,
      allowVideoCall: map['allowVideoCall'] ?? true,
      
      // Notification settings
      emailNotifications: map['emailNotifications'] ?? true,
      pushNotifications: map['pushNotifications'] ?? true,
      smsNotifications: map['smsNotifications'] ?? false,
      messageNotifications: map['messageNotifications'] ?? true,
      appointmentNotifications: map['appointmentNotifications'] ?? true,
      
      // Professional info
      licenseNumber: map['licenseNumber'],
      certification: map['certification'],
      availableHours: map['availableHours'] != null 
          ? List<String>.from(map['availableHours']) 
          : null,
      rating: map['rating']?.toDouble(),
      totalRatings: map['totalRatings'],
      
      // Account status
      isOnline: map['isOnline'] ?? false,
      isVerified: map['isVerified'] ?? false,
      isActive: map['isActive'] ?? true,
      lastSeen: map['lastSeen'] != null 
          ? (map['lastSeen'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'photoUrl': photoUrl,
      'approved': approved,
      'doctorId': doctorId,
      'mentorId': mentorId,
      'createdAt': createdAt,
      'lastActivity': lastActivity != null 
          ? Timestamp.fromDate(lastActivity!) 
          : null,
      'assignedAt': assignedAt,
      'disapprovedAt': disapprovedAt,
      'points': points, // NEW FIELD ADDED
      
      // Additional profile fields
      'phone': phone,
      'bio': bio,
      'location': location,
      'specialty': specialty,
      'education': education,
      'experience': experience,
      'languages': languages,
      'timezone': timezone,
      
      // Privacy settings
      'showEmail': showEmail,
      'showPhone': showPhone,
      'showLocation': showLocation,
      'allowMessages': allowMessages,
      'allowCalls': allowCalls,
      'allowVideoCall': allowVideoCall,
      
      // Notification settings
      'emailNotifications': emailNotifications,
      'pushNotifications': pushNotifications,
      'smsNotifications': smsNotifications,
      'messageNotifications': messageNotifications,
      'appointmentNotifications': appointmentNotifications,
      
      // Professional info
      'licenseNumber': licenseNumber,
      'certification': certification,
      'availableHours': availableHours,
      'rating': rating,
      'totalRatings': totalRatings,
      
      // Account status
      'isOnline': isOnline,
      'isVerified': isVerified,
      'isActive': isActive,
      'lastSeen': lastSeen != null 
          ? Timestamp.fromDate(lastSeen!) 
          : null,
    };
  }
  
  UserData copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? photoUrl,
    bool? approved,
    String? doctorId,
    String? mentorId,
    Timestamp? createdAt,
    DateTime? lastActivity,
    Timestamp? assignedAt,
    Timestamp? disapprovedAt,
    int? points, // NEW FIELD ADDED
    
    // Additional profile fields
    String? phone,
    String? bio,
    String? location,
    String? specialty,
    String? education,
    String? experience,
    List<String>? languages,
    String? timezone,
    
    // Privacy settings
    bool? showEmail,
    bool? showPhone,
    bool? showLocation,
    bool? allowMessages,
    bool? allowCalls,
    bool? allowVideoCall,
    
    // Notification settings
    bool? emailNotifications,
    bool? pushNotifications,
    bool? smsNotifications,
    bool? messageNotifications,
    bool? appointmentNotifications,
    
    // Professional info
    String? licenseNumber,
    String? certification,
    List<String>? availableHours,
    double? rating,
    int? totalRatings,
    
    // Account status
    bool? isOnline,
    bool? isVerified,
    bool? isActive,
    DateTime? lastSeen,
  }) {
    return UserData(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      approved: approved ?? this.approved,
      doctorId: doctorId ?? this.doctorId,
      mentorId: mentorId ?? this.mentorId,
      createdAt: createdAt ?? this.createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
      assignedAt: assignedAt ?? this.assignedAt,
      disapprovedAt: disapprovedAt ?? this.disapprovedAt,
      points: points ?? this.points, // NEW FIELD ADDED
      
      // Additional profile fields
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      specialty: specialty ?? this.specialty,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      languages: languages ?? this.languages,
      timezone: timezone ?? this.timezone,
      
      // Privacy settings
      showEmail: showEmail ?? this.showEmail,
      showPhone: showPhone ?? this.showPhone,
      showLocation: showLocation ?? this.showLocation,
      allowMessages: allowMessages ?? this.allowMessages,
      allowCalls: allowCalls ?? this.allowCalls,
      allowVideoCall: allowVideoCall ?? this.allowVideoCall,
      
      // Notification settings
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      messageNotifications: messageNotifications ?? this.messageNotifications,
      appointmentNotifications: appointmentNotifications ?? this.appointmentNotifications,
      
      // Professional info
      licenseNumber: licenseNumber ?? this.licenseNumber,
      certification: certification ?? this.certification,
      availableHours: availableHours ?? this.availableHours,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      
      // Account status
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
  
  // Getters for convenience
  String get displayName => name;
  
  String get roleDisplayName {
    switch (role) {
      case 'doctor':
        return 'Doctor';
      case 'mentor':
        return 'Mentor';
      case 'mentee':
        return 'Mentee';
      case 'admin':
        return 'Administrator';
      default:
        return 'User';
    }
  }
  
  String get formattedName {
    if (role == 'doctor' && name.isNotEmpty) {
      return 'Dr. $name';
    }
    return name;
  }
  
  bool get hasProfilePhoto => photoUrl != null && photoUrl!.isNotEmpty;
  
  bool get isDoctor => role == 'doctor';
  bool get isMentor => role == 'mentor';
  bool get isMentee => role == 'mentee';
  bool get isAdmin => role == 'admin';
  
  bool get canReceiveMessages => allowMessages ?? true;
  bool get canReceiveCalls => allowCalls ?? true;
  bool get canReceiveVideoCalls => allowVideoCall ?? true;
  
  bool get wasDisapproved => disapprovedAt != null;
  
  String get onlineStatus {
    if (isOnline == true) {
      return 'Online';
    } else if (lastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(lastSeen!);
      
      if (difference.inMinutes < 5) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return 'Last seen long ago';
      }
    }
    return 'Offline';
  }
  
  double get averageRating => rating ?? 0.0;
  int get reviewCount => totalRatings ?? 0;
  
  bool get hasCompleteProfile {
    final requiredFields = <String?>[name, email];
    
    if (isDoctor) {
      requiredFields.addAll([specialty, licenseNumber]);
    } else if (isMentor) {
      requiredFields.addAll([experience]);
    }
    
    return requiredFields.every((field) => field != null && field.isNotEmpty);
  }
  
  @override
  String toString() {
    return 'UserData(uid: $uid, name: $name, email: $email, role: $role)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserData && other.uid == uid;
  }
  
  @override
  int get hashCode => uid.hashCode;
}