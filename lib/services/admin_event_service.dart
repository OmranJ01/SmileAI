import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class AdminEventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create admin event that notifies all users
  static Future<String> createAdminEvent({
    required String adminId,
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    bool isAllDay = false,
  }) async {
    try {
      // Create the admin event
      final eventRef = await _firestore.collection('admin_events').add({
        'adminId': adminId,
        'title': title,
        'description': description,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'location': location,
        'isAllDay': isAllDay,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get all approved users to send notifications
      final usersQuery = await _firestore
          .collection('users')
          .where('approved', isEqualTo: true)
          .get();

      // Send notification to all users
      final batch = _firestore.batch();
      for (final userDoc in usersQuery.docs) {
        final userId = userDoc.id;
        
        // Skip the admin who created the event
        if (userId == adminId) continue;

        // Create notification for each user
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': userId,
          'title': 'New Event: $title',
          'message': 'Admin has scheduled a new event: $description',
          'type': 'admin_event',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'eventId': eventRef.id,
            'eventTitle': title,
            'startTime': Timestamp.fromDate(startTime),
            'endTime': Timestamp.fromDate(endTime),
          },
        });
      }

      // Commit all notifications at once
      await batch.commit();

      print('Admin event created and notifications sent to ${usersQuery.docs.length - 1} users');
      return eventRef.id;
    } catch (e) {
      print('Error creating admin event: $e');
      throw e;
    }
  }

  // Update admin event
  static Future<void> updateAdminEvent({
    required String eventId,
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    bool isAllDay = false,
  }) async {
    try {
      await _firestore.collection('admin_events').doc(eventId).update({
        'title': title,
        'description': description,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'location': location,
        'isAllDay': isAllDay,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Optionally send update notifications to all users
      final usersQuery = await _firestore
          .collection('users')
          .where('approved', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final userDoc in usersQuery.docs) {
        final userId = userDoc.id;
        
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': userId,
          'title': 'Event Updated: $title',
          'message': 'An admin event has been updated: $description',
          'type': 'admin_event_update',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'eventId': eventId,
            'eventTitle': title,
            'startTime': Timestamp.fromDate(startTime),
            'endTime': Timestamp.fromDate(endTime),
          },
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error updating admin event: $e');
      throw e;
    }
  }

  // Delete admin event
  static Future<void> deleteAdminEvent(String eventId) async {
    try {
      // Get event details before deletion for notification
      final eventDoc = await _firestore.collection('admin_events').doc(eventId).get();
      final eventData = eventDoc.data();
      
      if (eventData == null) return;

      // Delete the event
      await _firestore.collection('admin_events').doc(eventId).delete();

      // Send deletion notifications to all users
      final usersQuery = await _firestore
          .collection('users')
          .where('approved', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final userDoc in usersQuery.docs) {
        final userId = userDoc.id;
        
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': userId,
          'title': 'Event Cancelled: ${eventData['title']}',
          'message': 'An admin event has been cancelled: ${eventData['description']}',
          'type': 'admin_event_cancelled',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'eventId': eventId,
            'eventTitle': eventData['title'],
          },
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error deleting admin event: $e');
      throw e;
    }
  }

  // Get all admin events
  static Stream<QuerySnapshot> getAdminEvents() {
    return _firestore
        .collection('admin_events')
        .orderBy('startTime', descending: false)
        .snapshots();
  }

  // Get admin events for a specific date range
  static Future<List<Map<String, dynamic>>> getAdminEventsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final query = await _firestore
          .collection('admin_events')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('startTime')
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting admin events for date range: $e');
      return [];
    }
  }

  // Check if user is admin
  static Future<bool> isUserAdmin(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['role'] == 'admin' && userData?['approved'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }
}