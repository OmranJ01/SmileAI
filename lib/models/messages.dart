import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final Timestamp timestamp;
  final bool read;
  final bool isDeleted;
  final List<String> participants;
  final Timestamp? editedAt;
  final List<String> deletedBy;
  final Timestamp? readAt;

  Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.timestamp,
    required this.read,
    required this.isDeleted,
    required this.participants,
    this.editedAt,
    required this.deletedBy,
    this.readAt,
  });

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      read: map['read'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      participants: List<String>.from(map['participants'] ?? []),
      editedAt: map['editedAt'],
      deletedBy: List<String>.from(map['deletedBy'] ?? []),
      readAt: map['readAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'recipientId': recipientId,
      'content': content,
      'timestamp': timestamp,
      'read': read,
      'isDeleted': isDeleted,
      'participants': participants,
      'editedAt': editedAt,
      'deletedBy': deletedBy,
      'readAt': readAt,
    };
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? content,
    Timestamp? timestamp,
    bool? read,
    bool? isDeleted,
    List<String>? participants,
    Timestamp? editedAt,
    List<String>? deletedBy,
    Timestamp? readAt,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      isDeleted: isDeleted ?? this.isDeleted,
      participants: participants ?? this.participants,
      editedAt: editedAt ?? this.editedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      readAt: readAt ?? this.readAt,
    );
  }

  // Getter to check if message was edited
  bool get isEdited => editedAt != null;
  
  // Getter to check if message is deleted for a specific user
  bool isDeletedForUser(String userId) {
    return isDeleted || deletedBy.contains(userId);
  }
  
  // Getter to format read status
  String get readStatus {
    if (!read) return 'sent';
    if (readAt != null) {
      final readTime = readAt!.toDate();
      final now = DateTime.now();
      final difference = now.difference(readTime);
      
      if (difference.inMinutes < 1) {
        return 'read just now';
      } else if (difference.inHours < 1) {
        return 'read ${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return 'read ${difference.inHours}h ago';
      } else {
        return 'read ${difference.inDays}d ago';
      }
    }
    return 'read';
  }
  
  // Getter to check if message is from today
  bool get isFromToday {
    final messageDate = timestamp.toDate();
    final now = DateTime.now();
    return messageDate.day == now.day &&
           messageDate.month == now.month &&
           messageDate.year == now.year;
  }
  
  // Getter to check if message is recent (within last hour)
  bool get isRecent {
    final messageTime = timestamp.toDate();
    final now = DateTime.now();
    return now.difference(messageTime).inHours < 1;
  }
  
  @override
  String toString() {
    return 'Message(id: $id, senderId: $senderId, recipientId: $recipientId, content: $content, read: $read, isDeleted: $isDeleted)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}