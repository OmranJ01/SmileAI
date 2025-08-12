import 'package:cloud_firestore/cloud_firestore.dart';

class MyNotification {
  final String id;
  final String userId;
  final String? title;
  final String message;
  final String? type;
  final Map<String, dynamic>? data;
  final Timestamp timestamp;
  final bool read;
  final Timestamp? readAt;
  final bool? urgent;
  final String? createdBy;

  MyNotification({
    required this.id,
    required this.userId,
    this.title,
    required this.message,
    this.type,
    this.data,
    required this.timestamp,
    required this.read,
    this.readAt,
    this.urgent,
    this.createdBy,
  });

  factory MyNotification.fromMap(Map<String, dynamic> map, String id) {
    return MyNotification(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'],
      message: map['message'] ?? '',
      type: map['type'],
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
      timestamp: map['timestamp'] ?? Timestamp.now(),
      read: map['read'] ?? false,
      readAt: map['readAt'],
      urgent: map['urgent'],
      createdBy: map['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'data': data,
      'timestamp': timestamp,
      'read': read,
      'readAt': readAt,
      'urgent': urgent,
      'createdBy': createdBy,
    };
  }

  MyNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    Map<String, dynamic>? data,
    Timestamp? timestamp,
    bool? read,
    Timestamp? readAt,
    bool? urgent,
    String? createdBy,
  }) {
    return MyNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      urgent: urgent ?? this.urgent,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Getters for convenience
  bool get isUrgent => urgent ?? false;
  bool get hasData => data != null && data!.isNotEmpty;
  
  DateTime get dateTime => timestamp.toDate();
  DateTime? get readDateTime => readAt?.toDate();
  
  String get typeDisplayName {
    switch (type) {
      case 'message':
        return 'Message';
      case 'appointment':
        return 'Appointment';
      case 'assignment':
        return 'Assignment';
      case 'promotion':
        return 'Promotion';
      case 'reminder':
        return 'Reminder';
      case 'system':
        return 'System';
      default:
        return 'Notification';
    }
  }
  
  // Check if notification is recent (within last hour)
  bool get isRecent {
    final now = DateTime.now();
    final notificationTime = timestamp.toDate();
    return now.difference(notificationTime).inHours < 1;
  }
  
  // Check if notification is from today
  bool get isFromToday {
    final now = DateTime.now();
    final notificationDate = timestamp.toDate();
    return notificationDate.day == now.day &&
           notificationDate.month == now.month &&
           notificationDate.year == now.year;
  }
  
  // Get formatted time string
  String get formattedTime {
    final notificationTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(notificationTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final month = notificationTime.month;
      final day = notificationTime.day;
      final monthNames = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${monthNames[month]} $day';
    }
  }
  
  // Extract specific data fields
  String? get senderId => data?['senderId'];
  String? get senderName => data?['senderName'];
  String? get messageContent => data?['messageContent'];
  String? get appointmentId => data?['appointmentId'];
  String? get doctorName => data?['doctorName'];
  String? get assignmentType => data?['assignmentType'];
  String? get assignedToName => data?['assignedToName'];
  String? get newRole => data?['newRole'];
  String? get medicationName => data?['medicationName'];
  String? get reminderTime => data?['reminderTime'];
  
  @override
  String toString() {
    return 'MyNotification(id: $id, userId: $userId, message: $message, type: $type, read: $read)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MyNotification && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}