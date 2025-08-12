import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/user_data.dart';
import 'cloudinary_service.dart';
import '../utils/cloudinary_config.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get user data by ID
  static Future<UserData?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        return UserData.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Get current user data
  static Future<UserData?> getCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;
      
      return await getUserById(currentUser.uid);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Update user data
  static Future<bool> updateUser(UserData userData) async {
    try {
      await _firestore
          .collection('users')
          .doc(userData.uid)
          .update(userData.toMap());
      
      return true;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  // Update user profile photo using Cloudinary
  static Future<String?> updateUserProfilePicture({
    required String userId,
    required dynamic imageData, // File for mobile, Uint8List for web
  }) async {
    try {
      // Store old photo URL for cleanup
      String? oldPhotoUrl;
      
      // Get current user data
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        oldPhotoUrl = doc.data()?['photoUrl'] as String?;
      }
      
      // Upload new image - this will create a unique URL
      final newPhotoUrl = await CloudinaryService.uploadProfilePicture(
        userId: userId,
        imageData: imageData,
      );

      if (newPhotoUrl == null) {
        throw Exception('Failed to upload image to Cloudinary');
      }

      // Update user document with new photo URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'photoUrl': newPhotoUrl});

      // Clean up old image if it exists and is different from new one
      if (oldPhotoUrl != null && 
          oldPhotoUrl.isNotEmpty && 
          oldPhotoUrl != newPhotoUrl &&
          oldPhotoUrl.contains('cloudinary.com')) {
        try {
          // Extract publicId from old URL and delete
          final oldPublicId = CloudinaryService.extractPublicIdFromUrl(oldPhotoUrl);
          if (oldPublicId != null) {
            await _deleteOldCloudinaryImage(oldPublicId);
          }
        } catch (e) {
          print('Warning: Failed to clean up old image: $e');
          // Don't fail the whole operation if cleanup fails
        }
      }

      return newPhotoUrl;
    } catch (e) {
      print('Error updating profile picture: $e');
      return null;
    }
  }
  
  /// Helper method to delete old Cloudinary image
  static Future<void> _deleteOldCloudinaryImage(String publicId) async {
    try {
      if (!CloudinaryConfig.isConfigured) {
        return;
      }
      
      // Generate timestamp and signature for authenticated delete request
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final stringToSign = 'public_id=$publicId&timestamp=$timestamp${CloudinaryConfig.apiSecret}';
      final signature = sha1.convert(utf8.encode(stringToSign)).toString();
      
      // Make delete request
      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/destroy'),
        body: {
          'public_id': publicId,
          'api_key': CloudinaryConfig.apiKey,
          'timestamp': timestamp,
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Old image cleanup: $responseData');
      }
      
    } catch (e) {
      print('Error cleaning up old image: $e');
    }
  }

  // Delete profile photo using Cloudinary
  static Future<bool> deleteProfilePhoto(String userId) async {
    try {
      // Delete from Cloudinary
      await CloudinaryService.deleteProfilePicture(userId);

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'photoUrl': null,
      });

      return true;
    } catch (e) {
      print('Error deleting profile photo: $e');
      return false;
    }
  }

  // Update user privacy settings
  static Future<bool> updatePrivacySettings({
    required String userId,
    bool? showEmail,
    bool? showPhone,
    bool? showLocation,
    bool? allowMessages,
    bool? allowCalls,
    bool? allowVideoCall,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (showEmail != null) updates['showEmail'] = showEmail;
      if (showPhone != null) updates['showPhone'] = showPhone;
      if (showLocation != null) updates['showLocation'] = showLocation;
      if (allowMessages != null) updates['allowMessages'] = allowMessages;
      if (allowCalls != null) updates['allowCalls'] = allowCalls;
      if (allowVideoCall != null) updates['allowVideoCall'] = allowVideoCall;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }

      return true;
    } catch (e) {
      print('Error updating privacy settings: $e');
      return false;
    }
  }

  // Update notification settings
  static Future<bool> updateNotificationSettings({
    required String userId,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? smsNotifications,
    bool? messageNotifications,
    bool? appointmentNotifications,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (emailNotifications != null) updates['emailNotifications'] = emailNotifications;
      if (pushNotifications != null) updates['pushNotifications'] = pushNotifications;
      if (smsNotifications != null) updates['smsNotifications'] = smsNotifications;
      if (messageNotifications != null) updates['messageNotifications'] = messageNotifications;
      if (appointmentNotifications != null) updates['appointmentNotifications'] = appointmentNotifications;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }

      return true;
    } catch (e) {
      print('Error updating notification settings: $e');
      return false;
    }
  }

  // Update online status
  static Future<bool> updateOnlineStatus({
    required String userId,
    required bool isOnline,
  }) async {
    try {
      final updates = {
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).update(updates);
      return true;
    } catch (e) {
      print('Error updating online status: $e');
      return false;
    }
  }

  // Update last activity
  static Future<bool> updateLastActivity(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating last activity: $e');
      return false;
    }
  }

  // Change password
  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      return true;
    } catch (e) {
      print('Error changing password: $e');
      return false;
    }
  }

  // Delete user account
  static Future<bool> deleteUserAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Get user data to delete associated files
      final userData = await getUserById(user.uid);

      // Delete profile photo from storage
      if (userData?.photoUrl != null) {
        try {
          await _storage.refFromURL(userData!.photoUrl!).delete();
        } catch (e) {
          print('Error deleting profile photo: $e');
        }
      }

      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete messages
      await _deleteUserMessages(user.uid);

      // Delete notifications
      await _deleteUserNotifications(user.uid);

      // Delete user account
      await user.delete();

      return true;
    } catch (e) {
      print('Error deleting user account: $e');
      return false;
    }
  }

  // Helper method to delete user messages
  static Future<void> _deleteUserMessages(String userId) async {
    try {
      final messagesQuery = await _firestore
          .collection('messages')
          .where('participants', arrayContains: userId)
          .get();

      final batch = _firestore.batch();
      
      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error deleting user messages: $e');
    }
  }

  // Helper method to delete user notifications
  static Future<void> _deleteUserNotifications(String userId) async {
    try {
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      
      for (final doc in notificationsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error deleting user notifications: $e');
    }
  }

  // Get users by role
  static Future<List<UserData>> getUsersByRole(String role) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .where('approved', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserData.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting users by role: $e');
      return [];
    }
  }

  // Search users by name
  static Future<List<UserData>> searchUsers(String searchQuery) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('approved', isEqualTo: true)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserData.fromMap(doc.data()))
          .where((user) => 
              user.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              user.email.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();

      return users;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get user stream for real-time updates
  static Stream<UserData?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return UserData.fromMap(snapshot.data()!);
          }
          return null;
        });
  }

  // Check if user exists
  static Future<bool> userExists(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking if user exists: $e');
      return false;
    }
  }

  // Update user rating (for doctors/mentors)
  static Future<bool> updateUserRating({
    required String userId,
    required double rating,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);
        
        if (snapshot.exists) {
          final userData = UserData.fromMap(snapshot.data()!);
          final currentRating = userData.rating ?? 0.0;
          final currentTotal = userData.totalRatings ?? 0;
          
          final newTotal = currentTotal + 1;
          final newRating = ((currentRating * currentTotal) + rating) / newTotal;
          
          transaction.update(userDoc, {
            'rating': newRating,
            'totalRatings': newTotal,
          });
        }
      });

      return true;
    } catch (e) {
      print('Error updating user rating: $e');
      return false;
    }
  }

  // Verify user (admin function)
  static Future<bool> verifyUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isVerified': true,
      });
      return true;
    } catch (e) {
      print('Error verifying user: $e');
      return false;
    }
  }

  // Block/Unblock user
  static Future<bool> toggleUserStatus({
    required String userId,
    required bool isActive,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
      });
      return true;
    } catch (e) {
      print('Error toggling user status: $e');
      return false;
    }
  }
}