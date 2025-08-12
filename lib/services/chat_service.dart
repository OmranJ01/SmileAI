import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/messages.dart';
import '../services/notification_service.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // IMPROVED: Get messages stream with better real-time updates and force refresh capability
  static Stream<List<Message>> getMessagesStream({
    required String userId1,
    required String userId2,
    int limit = 50,
    bool forceRefresh = false,
  }) {
    print('Setting up IMPROVED messages stream for $userId1 <-> $userId2 (forceRefresh: $forceRefresh)');
    
    // Create query with additional filter to force fresh data
    Query query = _firestore
        .collection('messages')
        .where('participants', arrayContains: userId1)
        .orderBy('timestamp', descending: true)
        .limit(limit);
    
    // Add a small delay to ensure we get fresh data from Firestore
    return Stream.fromFuture(
      Future.delayed(Duration(milliseconds: forceRefresh ? 500 : 100))
    ).asyncExpand((_) => 
      query.snapshots(includeMetadataChanges: true)
    ).map((snapshot) {
      print('Firebase snapshot received: ${snapshot.docs.length} documents (fromCache: ${snapshot.metadata.isFromCache})');
      
      // Skip cached data when force refreshing
      if (forceRefresh && snapshot.metadata.isFromCache) {
        print('Skipping cached data during force refresh');
        return <Message>[];
      }
      
      final messages = <Message>[];
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final participants = List<String>.from(data['participants'] ?? []);
          
          // Check if this message is between the two users
          if (participants.contains(userId2)) {
            // Check if message is deleted for everyone
            final isDeletedForEveryone = data['isDeleted'] ?? false;
            
            // Check if message is deleted for current user
            final deletedBy = List<String>.from(data['deletedBy'] ?? []);
            final isDeletedForUser = deletedBy.contains(userId1);
            
            // Only include message if it's not deleted for everyone and not deleted for current user
            if (!isDeletedForEveryone && !isDeletedForUser) {
              final message = Message.fromMap(data, doc.id);
              messages.add(message);
            }
          }
        } catch (e) {
          print('Error parsing message ${doc.id}: $e');
        }
      }
      
      // Sort messages by timestamp (newest first for the stream)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('Processed ${messages.length} valid messages for conversation $userId1 <-> $userId2');
      return messages;
    });
  }

  // FORCE GET MESSAGES - Bypasses cache completely
  static Future<List<Message>> forceGetMessages({
    required String userId1,
    required String userId2,
    int limit = 50,
  }) async {
    try {
      print('🔥 FORCE GETTING messages from Firestore (bypassing cache)...');
      
      // Force fresh data from server
      final query = await _firestore
          .collection('messages')
          .where('participants', arrayContains: userId1)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get(GetOptions(source: Source.server)); // Force server fetch
      
      final messages = <Message>[];
      
      for (final doc in query.docs) {
        try {
          final data = doc.data();
          final participants = List<String>.from(data['participants'] ?? []);
          
          // Check if this message is between the two users
          if (participants.contains(userId2)) {
            // Check if message is deleted for everyone
            final isDeletedForEveryone = data['isDeleted'] ?? false;
            
            // Check if message is deleted for current user
            final deletedBy = List<String>.from(data['deletedBy'] ?? []);
            final isDeletedForUser = deletedBy.contains(userId1);
            
            // Only include message if it's not deleted for everyone and not deleted for current user
            if (!isDeletedForEveryone && !isDeletedForUser) {
              final message = Message.fromMap(data, doc.id);
              messages.add(message);
            }
          }
        } catch (e) {
          print('Error parsing message ${doc.id}: $e');
        }
      }
      
      // Sort messages by timestamp (newest first)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('🔥 FORCE FETCHED ${messages.length} fresh messages from server');
      return messages;
    } catch (e) {
      print('Error force getting messages: $e');
      return [];
    }
  }

  // Get older messages for pagination
  static Future<List<Message>> getOlderMessages({
    required String userId1,
    required String userId2,
    Timestamp? beforeTimestamp,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore
          .collection('messages')
          .where('participants', arrayContains: userId1)
          .orderBy('timestamp', descending: true);

      // Use timestamp-based pagination if provided
      if (beforeTimestamp != null) {
        query = query.where('timestamp', isLessThan: beforeTimestamp);
      } else if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);
      
      // Force server fetch for pagination too
      final snapshot = await query.get(GetOptions(source: Source.server));
      
      final messages = <Message>[];
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final participants = List<String>.from(data['participants'] ?? []);
          
          // Check if this message is between the two users
          if (participants.contains(userId2)) {
            // Check if message is deleted for everyone
            final isDeletedForEveryone = data['isDeleted'] ?? false;
            
            // Check if message is deleted for current user
            final deletedBy = List<String>.from(data['deletedBy'] ?? []);
            final isDeletedForUser = deletedBy.contains(userId1);
            
            // Only include message if it's not deleted for everyone and not deleted for current user
            if (!isDeletedForEveryone && !isDeletedForUser) {
              final message = Message.fromMap(data, doc.id);
              messages.add(message);
            }
          }
        } catch (e) {
          print('Error parsing older message ${doc.id}: $e');
        }
      }

      // Sort messages by timestamp (oldest first for pagination)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      print('Loaded ${messages.length} older messages for conversation $userId1 <-> $userId2');
      return messages;
    } catch (e) {
      print('Error getting older messages: $e');
      return [];
    }
  }

  // FORCE GET LAST MESSAGE - Bypasses cache
  static Future<Message?> getLastMessage({
    required String userId1,
    required String userId2,
  }) async {
    try {
      print('🔥 FORCE GETTING last message from server...');
      
      final query = await _firestore
          .collection('messages')
          .where('participants', arrayContains: userId1)
          .orderBy('timestamp', descending: true)
          .limit(10) // Get a few recent messages to ensure we find one
          .get(GetOptions(source: Source.server)); // Force server fetch

      for (final doc in query.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        
        if (participants.contains(userId2)) {
          final isDeletedForEveryone = data['isDeleted'] ?? false;
          final deletedBy = List<String>.from(data['deletedBy'] ?? []);
          final isDeletedForUser = deletedBy.contains(userId1);
          
          if (!isDeletedForEveryone && !isDeletedForUser) {
            final message = Message.fromMap(data, doc.id);
            print('🔥 FORCE FETCHED last message: ${message.content.substring(0, message.content.length > 30 ? 30 : message.content.length)}...');
            return message;
          }
        }
      }

      print('🔥 No last message found');
      return null;
    } catch (e) {
      print('Error force getting last message: $e');
      return null;
    }
  }

  // FORCE GET UNREAD COUNT - Bypasses cache
  static Future<int> getUnreadMessageCount({
    required String senderId,
    required String recipientId,
  }) async {
    try {
      print('🔥 FORCE GETTING unread count from server...');
      
      final query = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('recipientId', isEqualTo: recipientId)
          .where('read', isEqualTo: false)
          .where('isDeleted', isEqualTo: false)
          .get(GetOptions(source: Source.server)); // Force server fetch

      final count = query.size;
      print('🔥 FORCE FETCHED unread count: $count');
      return count;
    } catch (e) {
      print('Error force getting unread count: $e');
      return 0;
    }
  }

  // Get real-time unread count stream
  static Stream<int> getUnreadCountStream({
    required String senderId,
    required String recipientId,
  }) {
    return _firestore
        .collection('messages')
        .where('senderId', isEqualTo: senderId)
        .where('recipientId', isEqualTo: recipientId)
        .where('read', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .snapshots(includeMetadataChanges: false) // Don't include metadata changes for count
        .map((snapshot) {
          final count = snapshot.size;
          print('Unread count for $senderId -> $recipientId: $count');
          return count;
        });
  }

  // 🚀 BASIC: Send message (without notification)
  static Future<bool> sendMessage({
    required String senderId,
    required String recipientId,
    required String content,
  }) async {
    try {
      print('📤 Sending message from $senderId to $recipientId: $content');
      
      // Create message data with server timestamp
      final messageData = {
        'senderId': senderId,
        'recipientId': recipientId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'isDeleted': false,
        'participants': [senderId, recipientId],
        'editedAt': null,
        'deletedBy': [],
      };

      // Send message to Firestore
      final docRef = await _firestore.collection('messages').add(messageData);
      print('✅ Message sent successfully with ID: ${docRef.id}');
      
      // Add a small delay to ensure message is written
      await Future.delayed(Duration(milliseconds: 100));
      
      return true;
    } catch (e) {
      print('❌ Error sending message: $e');
      return false;
    }
  }

  // 🔔 ENHANCED: Send message with SIMPLE notification using new service
  static Future<bool> sendMessageWithNotification({
    required String senderId,
    required String recipientId,
    required String content,
    required String senderName,
  }) async {
    try {
      print('📤 Sending message with notification: $senderId -> $recipientId');
      
      // 1. Send the message first
      final messageSuccess = await sendMessage(
        senderId: senderId,
        recipientId: recipientId,
        content: content,
      );
      
      if (!messageSuccess) {
        throw Exception('Failed to send message');
      }
      
      // 2. 🔔 Send notification using the SIMPLE notification service
      await NotificationService.sendMessageNotification(
        recipientId: recipientId,
        senderId: senderId,
        senderName: senderName,
        messageContent: content,
      );
      
      print('🎉 Message and notification sent successfully!');
      return true;
      
    } catch (e) {
      print('❌ Error sending message with notification: $e');
      return false;
    }
  }

  // 🚀 ENHANCED: Send message with automatic notification (alias for consistency)
  static Future<bool> sendMessageWithAutoNotification({
    required String senderId,
    required String recipientId,
    required String content,
    required String senderName,
  }) async {
    return await sendMessageWithNotification(
      senderId: senderId,
      recipientId: recipientId,
      content: content,
      senderName: senderName,
    );
  }

  // IMPROVED: Mark messages as read (simplified)
  static Future<bool> markMessagesAsRead({
    required String senderId,
    required String recipientId,
  }) async {
    try {
      print('📖 Marking messages as read: $senderId -> $recipientId');
      
      // First get fresh unread messages from server
      final query = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('recipientId', isEqualTo: recipientId)
          .where('read', isEqualTo: false)
          .where('isDeleted', isEqualTo: false)
          .get(GetOptions(source: Source.server)); // Force server fetch

      print('Found ${query.docs.length} unread messages to mark as read');

      if (query.docs.isEmpty) {
        print('No unread messages found');
        return true;
      }

      final batch = _firestore.batch();
      
      for (final doc in query.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ Successfully marked ${query.docs.length} messages as read');
      
      return true;
    } catch (e) {
      print('❌ Error marking messages as read: $e');
      return false;
    }
  }

  // Mark specific messages as read
  static Future<bool> batchMarkAsRead({required List<String> messageIds}) async {
    try {
      final batch = _firestore.batch();
      
      for (final messageId in messageIds) {
        final docRef = _firestore.collection('messages').doc(messageId);
        batch.update(docRef, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      
      // Add a small delay to ensure the update is processed
      await Future.delayed(Duration(milliseconds: 200));
      
      return true;
    } catch (e) {
      print('Error batch marking as read: $e');
      return false;
    }
  }

  // Delete a message
  static Future<bool> deleteMessage({
    required String messageId,
    required String deletedBy,
    required bool deleteForEveryone,
  }) async {
    try {
      final docRef = _firestore.collection('messages').doc(messageId);
      
      if (deleteForEveryone) {
        await docRef.update({
          'isDeleted': true,
          'content': 'This message was deleted',
          'deletedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.update({
          'deletedBy': FieldValue.arrayUnion([deletedBy]),
        });
      }
      
      // Add a small delay to ensure the update is processed
      await Future.delayed(Duration(milliseconds: 200));
      
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // Delete multiple messages
  static Future<bool> deleteMultipleMessages({
    required List<String> messageIds,
    required String deletedBy,
    required bool deleteForEveryone,
  }) async {
    try {
      final batch = _firestore.batch();
      
      for (final messageId in messageIds) {
        final docRef = _firestore.collection('messages').doc(messageId);
        
        if (deleteForEveryone) {
          batch.update(docRef, {
            'isDeleted': true,
            'content': 'This message was deleted',
            'deletedAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.update(docRef, {
            'deletedBy': FieldValue.arrayUnion([deletedBy]),
          });
        }
      }
      
      await batch.commit();
      
      // Add a small delay to ensure the update is processed
      await Future.delayed(Duration(milliseconds: 200));
      
      return true;
    } catch (e) {
      print('Error deleting multiple messages: $e');
      return false;
    }
  }

  // Update message content
  static Future<bool> updateMessage({
    required String messageId,
    required String newContent,
  }) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'content': newContent,
        'editedAt': FieldValue.serverTimestamp(),
      });
      
      // Add a small delay to ensure the update is processed
      await Future.delayed(Duration(milliseconds: 200));
      
      return true;
    } catch (e) {
      print('Error updating message: $e');
      return false;
    }
  }

  // Search messages
  static Future<List<Message>> searchMessages({
    required String userId1,
    required String userId2,
    required String searchQuery,
  }) async {
    try {
      // Force server fetch for search
      final query = await _firestore
          .collection('messages')
          .where('participants', arrayContains: userId1)
          .orderBy('timestamp', descending: true)
          .limit(1000)
          .get(GetOptions(source: Source.server));

      final messages = <Message>[];
      
      for (final doc in query.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final content = data['content'] as String? ?? '';
        
        if (participants.contains(userId2) && 
            content.toLowerCase().contains(searchQuery.toLowerCase()) &&
            !(data['isDeleted'] ?? false)) {
          messages.add(Message.fromMap(data, doc.id));
        }
      }

      return messages;
    } catch (e) {
      print('Error searching messages: $e');
      return [];
    }
  }

  // Clear chat history
  static Future<bool> clearChatHistory({
    required String userId1,
    required String userId2,
  }) async {
    try {
      // Force server fetch to get all messages
      final query = await _firestore
          .collection('messages')
          .where('participants', arrayContains: userId1)
          .get(GetOptions(source: Source.server));

      final batch = _firestore.batch();
      
      for (final doc in query.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        
        if (participants.contains(userId2)) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
      
      // Add a small delay to ensure the deletion is processed
      await Future.delayed(Duration(milliseconds: 500));
      
      return true;
    } catch (e) {
      print('Error clearing chat history: $e');
      return false;
    }
  }
}