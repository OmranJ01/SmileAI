import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notifications.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send a notification to a specific user
  static Future<bool> sendNotification({
    required String userId,
    required String message,
    String? title,
    String type = 'general',
    Map<String, dynamic>? data,
    bool urgent = false,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'urgent': urgent,
        'createdBy': _auth.currentUser?.uid,
      });

      print('Notification sent successfully to user: $userId');
      return true;
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  // Send bulk notifications to multiple users
  static Future<bool> sendBulkNotifications({
    required List<String> userIds,
    required String message,
    String? title,
    String type = 'general',
    Map<String, dynamic>? data,
    bool urgent = false,
  }) async {
    try {
      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();
      final createdBy = _auth.currentUser?.uid;

      for (final userId in userIds) {
        final docRef = _firestore.collection('notifications').doc();
        batch.set(docRef, {
          'userId': userId,
          'title': title,
          'message': message,
          'type': type,
          'data': data ?? {},
          'timestamp': timestamp,
          'read': false,
          'urgent': urgent,
          'createdBy': createdBy,
        });
      }

      await batch.commit();
      print('Bulk notifications sent to ${userIds.length} users');
      return true;
    } catch (e) {
      print('Error sending bulk notifications: $e');
      return false;
    }
  }

  // Message notification
  static Future<bool> sendMessageNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String messageContent,
  }) async {
    return await sendNotification(
      userId: recipientId,
      title: 'New Message',
      message: '$senderName sent you a message',
      type: 'message',
      data: {
        'senderId': senderId,
        'senderName': senderName,
        'messageContent': messageContent.length > 50 
            ? '${messageContent.substring(0, 50)}...' 
            : messageContent,
      },
    );
  }

  // Appointment notification
  static Future<bool> sendAppointmentNotification({
    required String userId,
    required String title,
    required String message,
    required DateTime appointmentTime,
    String? doctorName,
    String? appointmentId,
  }) async {
    return await sendNotification(
      userId: userId,
      title: title,
      message: message,
      type: 'appointment',
      data: {
        'appointmentTime': appointmentTime.toIso8601String(),
        'doctorName': doctorName,
        'appointmentId': appointmentId,
      },
      urgent: true,
    );
  }

  // Assignment notification
  static Future<bool> sendAssignmentNotification({
    required String userId,
    required String assignmentType, // 'mentor', 'doctor', etc.
    required String assignedToName,
    String? assignedById,
    String? assignedByName,
  }) async {
    return await sendNotification(
      userId: userId,
      title: 'New Assignment',
      message: 'You have been assigned to $assignedToName as your $assignmentType',
      type: 'assignment',
      data: {
        'assignmentType': assignmentType,
        'assignedToName': assignedToName,
        'assignedById': assignedById,
        'assignedByName': assignedByName,
      },
    );
  }

  // Promotion notification
  static Future<bool> sendPromotionNotification({
    required String userId,
    required String newRole,
    String? promotedBy,
  }) async {
    return await sendNotification(
      userId: userId,
      title: 'Congratulations!',
      message: 'You have been promoted to $newRole',
      type: 'promotion',
      data: {
        'newRole': newRole,
        'promotedBy': promotedBy,
      },
      urgent: true,
    );
  }

  // Medication reminder notification
  static Future<bool> sendMedicationReminder({
    required String userId,
    required String medicationName,
    required String time,
  }) async {
    return await sendNotification(
      userId: userId,
      title: 'Medication Reminder',
      message: 'Time to take your $medicationName',
      type: 'reminder',
      data: {
        'medicationName': medicationName,
        'reminderTime': time,
      },
      urgent: true,
    );
  }

  // System notification
  static Future<bool> sendSystemNotification({
    required String userId,
    required String message,
    String? title,
    String subType = 'general',
  }) async {
    return await sendNotification(
      userId: userId,
      title: title ?? 'System Notification',
      message: message,
      type: 'system',
      data: {
        'subType': subType,
      },
    );
  }

  // 🔧 NEW: Get unread message count from a specific sender
  static Future<int> getUnreadMessageCountFromSender({
    required String userId,
    required String senderId,
  }) async {
    try {
      QuerySnapshot unreadMessages = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('recipientId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      return unreadMessages.size;
    } catch (e) {
      print('Error getting unread message count from sender: $e');
      return 0;
    }
  }

  // 🔧 NEW: Get total unread message count for a user
  static Future<int> getUnreadMessageCount(String userId) async {
    try {
      QuerySnapshot unreadMessages = await _firestore
          .collection('messages')
          .where('recipientId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      return unreadMessages.size;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }

  // 🔧 NEW: Mark messages as read
  static Future<bool> markMessagesAsRead({
    required String userId,
    required String senderId,
  }) async {
    try {
      QuerySnapshot unreadMessages = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('recipientId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      WriteBatch batch = _firestore.batch();
      
      for (QueryDocumentSnapshot doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error marking messages as read: $e');
      return false;
    }
  }

  // Mark a notification as read
  static Future<bool> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  // Mark multiple notifications as read
  static Future<bool> markAllAsRead(List<String> notificationIds) async {
    try {
      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();

      for (final id in notificationIds) {
        final docRef = _firestore.collection('notifications').doc(id);
        batch.update(docRef, {
          'read': true,
          'readAt': timestamp,
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error marking notifications as read: $e');
      return false;
    }
  }

  // Delete a notification
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  // Clear all notifications for a user
  static Future<bool> clearAllNotifications(List<String> notificationIds) async {
    try {
      final batch = _firestore.batch();

      for (final id in notificationIds) {
        final docRef = _firestore.collection('notifications').doc(id);
        batch.delete(docRef);
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error clearing notifications: $e');
      return false;
    }
  }

  // Get notifications stream for real-time updates
  static Stream<List<MyNotification>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MyNotification.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Get unread notification count
  static Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      return snapshot.size;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Get unread count stream for real-time updates
  static Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  // Get notifications by type
  static Future<List<MyNotification>> getNotificationsByType(
    String userId,
    String type,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => MyNotification.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting notifications by type: $e');
      return [];
    }
  }

  // Clean up old notifications (older than 30 days)
  static Future<bool> cleanupOldNotifications(String userId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleaned up ${snapshot.docs.length} old notifications');
      return true;
    } catch (e) {
      print('Error cleaning up old notifications: $e');
      return false;
    }
  }

  // Send notification to all users with a specific role
  static Future<bool> sendRoleBasedNotification({
    required String role,
    required String message,
    String? title,
    String type = 'system',
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all users with the specified role
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();

      final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();

      return await sendBulkNotifications(
        userIds: userIds,
        message: message,
        title: title,
        type: type,
        data: data,
      );
    } catch (e) {
      print('Error sending role-based notification: $e');
      return false;
    }
  }

  // Schedule a notification for later (basic implementation)
  static Future<bool> scheduleNotification({
    required String userId,
    required String message,
    required DateTime scheduledTime,
    String? title,
    String type = 'reminder',
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('scheduled_notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'sent': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
      });

      return true;
    } catch (e) {
      print('Error scheduling notification: $e');
      return false;
    }
  }

  // Process scheduled notifications (would typically run on a server/cloud function)
  static Future<void> processScheduledNotifications() async {
    try {
      final now = Timestamp.now();
      
      final snapshot = await _firestore
          .collection('scheduled_notifications')
          .where('sent', isEqualTo: false)
          .where('scheduledTime', isLessThanOrEqualTo: now)
          .get();

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Send the notification
        await sendNotification(
          userId: data['userId'],
          title: data['title'],
          message: data['message'],
          type: data['type'],
          data: Map<String, dynamic>.from(data['data'] ?? {}),
        );

        // Mark as sent
        batch.update(doc.reference, {'sent': true});
      }

      await batch.commit();
      print('Processed ${snapshot.docs.length} scheduled notifications');
    } catch (e) {
      print('Error processing scheduled notifications: $e');
    }
  }

  // Get notification statistics for a user
  static Future<Map<String, dynamic>> getNotificationStats(String userId) async {
    try {
      final allNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      // Count by type
      final typeCount = <String, int>{};
      for (final doc in allNotifications.docs) {
        final type = doc.data()['type'] as String? ?? 'general';
        typeCount[type] = (typeCount[type] ?? 0) + 1;
      }

      return {
        'total': allNotifications.size,
        'unread': unreadNotifications.size,
        'read': allNotifications.size - unreadNotifications.size,
        'byType': typeCount,
      };
    } catch (e) {
      print('Error getting notification stats: $e');
      return {
        'total': 0,
        'unread': 0,
        'read': 0,
        'byType': <String, int>{},
      };
    }
  }
}