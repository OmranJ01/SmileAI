import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/user_data.dart';
import '../models/articles.dart';
import '../models/messages.dart';
import '../models/notifications.dart';
import '../services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Mentor data model classes
class MentorStats {
  final int totalMessages;
  final int totalSessions;
  final double averageRating;
  final int completedTasks;

  MentorStats({
    required this.totalMessages,
    required this.totalSessions,
    required this.averageRating,
    required this.completedTasks,
  });

  factory MentorStats.fromFirestore(Map<String, dynamic> data) {
    return MentorStats(
      totalMessages: data['totalMessages'] ?? 0,
      totalSessions: data['totalSessions'] ?? 0,
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      completedTasks: data['completedTasks'] ?? 0,
    );
  }
}

class MentorEvent {
  final String id;
  final String title;
  final String type;
  final DateTime dateTime;
  final String? description;

  MentorEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.dateTime,
    this.description,
  });

  factory MentorEvent.fromFirestore(Map<String, dynamic> data, String id) {
    return MentorEvent(
      id: id,
      title: data['title'] ?? '',
      type: data['type'] ?? 'event',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      description: data['description'],
    );
  }
}

class MentorTask {
  final String id;
  final String title;
  final String priority;
  final DateTime deadline;
  final int progress;
  final bool isCompleted;

  MentorTask({
    required this.id,
    required this.title,
    required this.priority,
    required this.deadline,
    required this.progress,
    required this.isCompleted,
  });

  factory MentorTask.fromFirestore(Map<String, dynamic> data, String id) {
    return MentorTask(
      id: id,
      title: data['title'] ?? '',
      priority: data['priority'] ?? 'Medium',
      deadline: (data['deadline'] as Timestamp).toDate(),
      progress: data['progress'] ?? 0,
      isCompleted: data['isCompleted'] ?? false,
    );
  }
}

class AppState extends ChangeNotifier {
  User? _user;
  UserData? _userData;
  bool _isLoading = false;
  List<Article> _articles = [];
  List<MyNotification> _notifications = [];
  List<Message> _messages = [];
  List<UserData> _mentees = [];
  List<UserData> _mentors = [];
  List<UserData> _doctors = [];
  int _points = 0;

  // New mentor properties
  MentorStats? _mentorStats;
  List<MentorEvent> _mentorEvents = [];
  List<MentorTask> _mentorTasks = [];
  
  // Real-time listeners
  StreamSubscription<DocumentSnapshot>? _userDataListener;
  StreamSubscription<QuerySnapshot>? _articlesListener;
  
  // Role change detection
  String? _previousRole;
  bool _roleChangeInProgress = false;
  Function(String oldRole, String newRole)? _onRoleChange;

  // Existing getters
  User? get user => _user;
  UserData? get userData => _userData;
  bool get isLoading => _isLoading;
  List<Article> get articles => _articles;
  List<MyNotification> get notifications => _notifications;
  List<Message> get messages => _messages;
  List<UserData> get mentees => _mentees;
  List<UserData> get mentors => _mentors;
  List<UserData> get doctors => _doctors;
  int get points => _points;

  // New mentor getters
  MentorStats? get mentorStats => _mentorStats;
  List<MentorEvent> get mentorEvents => _mentorEvents;
  List<MentorTask> get mentorTasks => _mentorTasks;
  
  // User role getters
  bool get isAdmin => _userData?.role == 'admin';
  bool get isMentor => _userData?.role == 'mentor';
  bool get isMentee => _userData?.role == 'mentee';
  bool get isDoctor => _userData?.role == 'doctor';

  void setUserData(UserData userData) {
    _userData = userData;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Update user points
  void updatePoints(int newPoints) {
    _points = newPoints;
    notifyListeners();
  }

  // Refresh user data manually
  Future<void> refreshUserData() async {
    if (_user == null) return;
    
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        _userData = UserData.fromMap(data);
        _points = data['points'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  Future<void> saveFcmToken() async {
    if (_user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'fcmToken': token,
      });
    }
  }

  // Method to set role change callback
  void setRoleChangeCallback(Function(String oldRole, String newRole)? callback) {
    _onRoleChange = callback;
  }

  // 🔧 CONSTRUCTOR - Initialize with notification service
  AppState() {
    print('🚀 Initializing AppState');
    _initializeNotificationService();
    
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      print('🔄 Auth state changed: ${user?.uid}');
      
      _user = user;
      if (user != null) {
        try {
          await _loadUserData();
          await _loadArticles();
          _setupUserDataListener(); // Set up real-time listener
          _setupArticlesListener(); // Set up articles listener
          
        } catch (e) {
          print('❌ Error in auth state change: $e');
          _isLoading = false;
          notifyListeners();
        }
      } else {
        _userData = null;
        _points = 0;
        _previousRole = null;
        _roleChangeInProgress = false;
        _userDataListener?.cancel();
        _articlesListener?.cancel();
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  // Set up real-time listener for user data changes
  void _setupUserDataListener() {
    if (_user == null) return;
    
    _userDataListener?.cancel();
    _userDataListener = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        UserData newUserData = UserData.fromMap(data);
        int newPoints = data['points'] ?? 0;
        
        // Check for role change
        String? currentRole = _userData?.role;
        String newRole = newUserData.role;
        
        if (currentRole != null && currentRole != newRole && !_roleChangeInProgress) {
          print('🔄 ROLE CHANGE DETECTED: $currentRole → $newRole');
          _roleChangeInProgress = true;
          _previousRole = currentRole;
          
          // Update user data first
          _userData = newUserData;
          _points = newPoints;
          notifyListeners();
          
          // Call role change callback if set
          if (_onRoleChange != null) {
            _onRoleChange!(currentRole, newRole);
          }
          
          // Reset role change flag after a delay
          Future.delayed(Duration(seconds: 3), () {
            _roleChangeInProgress = false;
          });
        } else {
          // Normal update
          _userData = newUserData;
          _points = newPoints;
          notifyListeners();
        }
      }
    }, onError: (error) {
      print('❌ Error in user data listener: $error');
    });
  }

  // NEW: Set up real-time listener for articles
  void _setupArticlesListener() {
    print('🔄 Setting up real-time articles listener');
    
    // Cancel existing listener if any
    _articlesListener?.cancel();
    
    // Set up new listener
    _articlesListener = FirebaseFirestore.instance
        .collection('articles')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _articles = snapshot.docs.map((doc) {
        return Article.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
      }).toList();
      
      print('🔄 Articles updated in real-time. Count: ${_articles.length}');
      
      // Notify listeners to update UI
      notifyListeners();
    }, onError: (error) {
      print('❌ Error in articles listener: $error');
    });
  }

  @override
  void dispose() {
    _userDataListener?.cancel();
    _articlesListener?.cancel();
    super.dispose();
  }

  // 🔧 NEW: Initialize notification service
  Future<void> _initializeNotificationService() async {
    try {
      print('🔔 Initializing notification service...');
      await NotificationService.init();
      print('✅ Notification service initialized');
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    }
  }

// 🔧 FIXED: Load user data and handle notifications
Future<void> _loadUserData() async {
  if (_user == null) return;
  
  print('🔄 Loading user data for ${_user!.uid}');
  
  _isLoading = true;
  notifyListeners();
  
  try {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      UserData newUserData = UserData.fromMap(data);
      
      String? oldRole = _userData?.role;
      String? newRole = newUserData.role;
      bool roleChanged = oldRole != newRole;
      
      print('🔍 Role: $oldRole -> $newRole (changed: $roleChanged)');
      
      _userData = newUserData;
      _points = data['points'] ?? 0;
      
      // 🔔 ENHANCED: Comprehensive notification handling on sign in
      await NotificationService.checkAndCreateNotificationsForFiredReminders(_user!.uid);
      await NotificationService.checkMissedRemindersOnSignIn();

      // 🔧 SMART: Only clear cache if role changed or first sign-in
      if (roleChanged || oldRole == null) {
        print('🧹 Clearing cache due to role change or first sign-in...');
        _mentorStats = null;
        _mentorEvents = [];
        _mentorTasks = [];
      }

      // 🔧 CRITICAL: Load admin data IMMEDIATELY
      if (newRole == 'admin') {
        print('👑 ADMIN DETECTED - LOADING ALL USERS NOW');
        _isLoading = false;
        notifyListeners();
        await loadAllUsersNow();
        return;
      }
      
      if (roleChanged && oldRole != null) {
        print('🔄 Role change detected');
        _mentorStats = null;
        _mentorEvents = [];
        _mentorTasks = [];
        _mentees = [];
        _mentors = [];
        _doctors = [];
        
        _isLoading = false;
        notifyListeners();
        
        await _loadRoleSpecificData();
        return;
      }
    }
  } catch (e) {
    print('❌ Error loading user data: $e');
  }
  
  _isLoading = false;
  notifyListeners();
}
  // 🔧 NEW: Simple method to load all users immediately for admin
// Replace your existing loadAllUsersNow method in AppState with this:

// Replace your existing loadAllUsersNow method in AppState with this:

Future<void> loadAllUsersNow() async {
  print('🔄 LOADING ALL USERS NOW FOR ADMIN...');
  
  try {
    // Load mentees
    QuerySnapshot menteesSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'mentee')
        .get();
    _mentees = menteesSnap.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['uid'] = doc.id; // CRITICAL: Ensure uid is set from document ID
      return UserData.fromMap(data);
    }).toList();
    
    // Load mentors  
    QuerySnapshot mentorsSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'mentor')
        .get();
    _mentors = mentorsSnap.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['uid'] = doc.id; // CRITICAL: Ensure uid is set from document ID
      return UserData.fromMap(data);
    }).toList();
        
    // Load doctors
    QuerySnapshot doctorsSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .get();
    _doctors = doctorsSnap.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['uid'] = doc.id; // CRITICAL: Ensure uid is set from document ID
      return UserData.fromMap(data);
    }).toList();
    
    print('✅ LOADED: ${_mentees.length} mentees, ${_mentors.length} mentors, ${_doctors.length} doctors');
    print('✅ APPROVED: ${_mentees.where((u) => u.approved).length} mentees, ${_mentors.where((u) => u.approved).length} mentors, ${_doctors.where((u) => u.approved).length} doctors');
    
    // Debug: Print first user data to check structure
    if (_mentees.isNotEmpty) {
      print('🔍 Sample mentee data:');
      print('   UID: ${_mentees.first.uid}');
      print('   Name: ${_mentees.first.name}');
      print('   Email: ${_mentees.first.email}');
      print('   Approved: ${_mentees.first.approved}');
    }
    
    // CRITICAL: Notify listeners to update UI
    notifyListeners();
    
  } catch (e) {
    print('❌ Error loading all users: $e');
  }
}

  Future<void> _loadRoleSpecificData() async {
    if (_userData == null) return;
    
    try {
      print('🔄 Loading role-specific data for ${_userData!.role}');
      
      if (isMentor) {
        await _loadMentorDataSafely();
      } else if (isAdmin) {
        await loadAllUsersNow();
      } else if (isDoctor) {
        await loadAllUsersNow();
      }
      
      await _loadNotifications();
      
    } catch (e) {
      print('❌ Error loading role-specific data: $e');
    }
    
    notifyListeners();
  }

  Future<void> _loadMentorDataSafely() async {
    if (_user?.uid == null || !isMentor) return;
    
    try {
      await Future.wait([
        _loadMentorStatsWithTimeout(_user!.uid),
        _loadMentorEventsWithTimeout(_user!.uid),
        _loadMentorTasksWithTimeout(_user!.uid),
        fetchMentees(),
      ], eagerError: false).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          _setDefaultMentorData();
          return [];
        },
      );
    } catch (e) {
      print('❌ Error loading mentor data: $e');
      _setDefaultMentorData();
    }
  }

  Future<void> _loadMentorStatsWithTimeout(String mentorId) async {
    try {
      final statsDoc = await FirebaseFirestore.instance
          .collection('mentorStats')
          .doc(mentorId)
          .get()
          .timeout(Duration(seconds: 5));

      if (statsDoc.exists) {
        _mentorStats = MentorStats.fromFirestore(statsDoc.data()!);
      } else {
        _mentorStats = MentorStats(
          totalMessages: 0,
          totalSessions: 0,
          averageRating: 0.0,
          completedTasks: 0,
        );
        
        await FirebaseFirestore.instance
            .collection('mentorStats')
            .doc(mentorId)
            .set({
          'totalMessages': 0,
          'totalSessions': 0,
          'averageRating': 0.0,
          'completedTasks': 0,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error loading mentor stats: $e');
      _mentorStats = MentorStats(
        totalMessages: 0,
        totalSessions: 0,
        averageRating: 0.0,
        completedTasks: 0,
      );
    }
  }

  Future<void> _loadMentorEventsWithTimeout(String mentorId) async {
    try {
      final eventsQuery = await FirebaseFirestore.instance
          .collection('mentorEvents')
          .where('mentorId', isEqualTo: mentorId)
          .where('dateTime', isGreaterThan: DateTime.now())
          .orderBy('dateTime')
          .limit(5)
          .get()
          .timeout(Duration(seconds: 5));

      _mentorEvents = eventsQuery.docs
          .map((doc) => MentorEvent.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('❌ Error loading mentor events: $e');
      _mentorEvents = [];
    }
  }

  Future<void> _loadMentorTasksWithTimeout(String mentorId) async {
    try {
      final tasksQuery = await FirebaseFirestore.instance
          .collection('mentorTasks')
          .where('mentorId', isEqualTo: mentorId)
          .where('isCompleted', isEqualTo: false)
          .orderBy('deadline')
          .limit(5)
          .get()
          .timeout(Duration(seconds: 5));

      _mentorTasks = tasksQuery.docs
          .map((doc) => MentorTask.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('❌ Error loading mentor tasks: $e');
      _mentorTasks = [];
    }
  }

  void _setDefaultMentorData() {
    _mentorStats = MentorStats(
      totalMessages: 0,
      totalSessions: 0,
      averageRating: 0.0,
      completedTasks: 0,
    );
    _mentorEvents = [];
    _mentorTasks = [];
  }

  // 🔧 IMPROVED: Clear cache on sign-in to prevent stale calendar data
Future<void> clearCacheOnSignIn() async {
  print('🧹 Clearing cache on sign-in...');
  
  try {
    // Only clear specific cached data that might be stale, not everything
    _mentorStats = null;
    _mentorEvents = [];
    _mentorTasks = [];
    
    // Don't clear notifications and articles as they don't cause calendar issues
    // _notifications = [];  // REMOVED
    // _articles = [];       // REMOVED
    
    print('✅ Cache cleared successfully');
    
    // Don't call notifyListeners() here to prevent UI flashing
    
  } catch (e) {
    print('❌ Error clearing cache: $e');
  }
}
  // 🔧 ENHANCED: Role change methods with proper debugging and notifications
  Future<void> changeUserRole(String userId, String newRole) async {
    try {
      print('🔄 STARTING ROLE CHANGE: $userId to $newRole');
      
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        print('❌ User not found: $userId');
        throw Exception('User not found');
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String currentRole = userData['role'] ?? '';
      
      print('🔍 Current role: $currentRole, New role: $newRole');
      
      if (currentRole == newRole) {
        print('⚠️ User already has role $newRole');
        return;
      }
      
      print('📝 Updating role in Firestore...');
      
      // Prepare update data
      Map<String, dynamic> updateData = {
        'role': newRole,
        'approved': true,
        'roleChangedAt': FieldValue.serverTimestamp(),
        'roleChangedBy': _user?.uid,
        'previousRole': currentRole,
      };
      
      // IMPORTANT: When promoting mentee to mentor, preserve both mentor and doctor assignments
      if (currentRole == 'mentee' && newRole == 'mentor') {
        // Keep both mentor and doctor assignments - don't delete mentorId or doctorId
        print('🔗 Preserving mentor and doctor assignments during promotion');
        print('📋 Keeping mentorId: ${userData['mentorId']}');
        print('📋 Keeping doctorId: ${userData['doctorId']}');
      } else if (newRole == 'mentee') {
        // Only remove assignments when downgrading TO mentee
        updateData['mentorId'] = FieldValue.delete();
        updateData['doctorId'] = FieldValue.delete();
      }
      
      // Update the role in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update(updateData);
      
      print('✅ Role updated in Firestore successfully');
      
      // Handle mentor-specific setup/cleanup
      if (newRole == 'mentor' && currentRole != 'mentor') {
        print('🔧 Setting up mentor data...');
        await _setupMentorData(userId);
      } else if (currentRole == 'mentor' && newRole != 'mentor') {
        print('🧹 Cleaning up mentor data...');
        await _cleanupMentorData(userId);
      }
      
      // Force reload data to reflect changes
      print('🔄 Reloading all users data...');
      await loadAllUsersNow();
      
      // If this is the current user, reload their data too
      if (_user?.uid == userId) {
        print('🔄 Reloading current user data...');
        await _loadUserData();
      }
      
      // 🔔 ENHANCED: Send comprehensive role change notification via FCM
      final notificationUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (notificationUserDoc.exists) {
        final notificationUserData = notificationUserDoc.data() as Map<String, dynamic>;
        final fcmToken = notificationUserData['fcmToken'] as String?;
        final userName = notificationUserData['name'] as String? ?? 'User';
        
        final notificationTitle = newRole == 'mentor' && currentRole == 'mentee' 
            ? '🎉 Congratulations! You\'ve been promoted to Mentor!' 
            : 'Role Updated';
        final notificationMessage = newRole == 'mentor' && currentRole == 'mentee'
            ? 'You can now guide and help other mentees on their journey!'
            : 'Your role has been changed to $newRole.';
        
        print('🔔 Sending role change notification to $userName (${userId})');
        
        // Create in-app notification
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': userId,
          'title': notificationTitle,
          'message': notificationMessage,
          'type': 'role_change',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'data': {
            'newRole': newRole,
            'previousRole': currentRole,
            'changedBy': _userData?.name ?? 'Admin',
            'changedAt': DateTime.now().toIso8601String(),
          },
        });
        
        // Send FCM push notification if user has a token
        if (fcmToken != null && fcmToken.isNotEmpty) {
          print('📱 Sending FCM push notification for role change');
          
          await NotificationService.sendFcmPushNotification(
            token: fcmToken,
            title: notificationTitle,
            body: notificationMessage,
            data: {
              'type': 'role_change',
              'newRole': newRole,
              'previousRole': currentRole,
              'changedBy': _userData?.name ?? 'Admin',
            },
          );
          
          print('✅ FCM notification sent successfully');
        } else {
          print('⚠️ No FCM token found for user, only in-app notification sent');
        }
      }
      
      print('✅ ROLE CHANGE COMPLETED: $currentRole → $newRole');
      
    } catch (e) {
      print('❌ ERROR in changeUserRole: $e');
      print('❌ Stack trace: ${e.toString()}');
      rethrow;
    }
  }

  // 🔧 FIXED: Specific promotion method with debugging
  Future<void> promoteMenteeToMentor(String userId) async {
    print('🎯 PROMOTING MENTEE TO MENTOR: $userId');
    try {
      await changeUserRole(userId, 'mentor');
      print('✅ PROMOTION TO MENTOR COMPLETED');
    } catch (e) {
      print('❌ PROMOTION TO MENTOR FAILED: $e');
      rethrow;
    }
  }

  // 🔧 FIXED: Specific downgrade method with debugging  
  Future<void> downgradeMentorToMentee(String userId) async {
    print('🎯 DOWNGRADING MENTOR TO MENTEE: $userId');
    try {
      await changeUserRole(userId, 'mentee');
      print('✅ DOWNGRADE TO MENTEE COMPLETED');
    } catch (e) {
      print('❌ DOWNGRADE TO MENTEE FAILED: $e');
      rethrow;
    }
  }

  // 🔧 NEW: General role change method for any role
  Future<void> changeToRole(String userId, String newRole) async {
    print('🎯 CHANGING USER $userId TO ROLE: $newRole');
    try {
      await changeUserRole(userId, newRole);
      print('✅ ROLE CHANGE TO $newRole COMPLETED');
    } catch (e) {
      print('❌ ROLE CHANGE TO $newRole FAILED: $e');
      rethrow;
    }
  }

  // 🔧 ENHANCED: Setup mentor data with better error handling
  Future<void> _setupMentorData(String userId) async {
    try {
      print('🔧 Setting up mentor data for $userId...');
      
      await FirebaseFirestore.instance.collection('mentorStats').doc(userId).set({
        'totalMessages': 0,
        'totalSessions': 0,
        'averageRating': 0.0,
        'completedTasks': 0,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Mentor data setup completed for $userId');
    } catch (e) {
      print('❌ Error setting up mentor data for $userId: $e');
    }
  }

  // 🔧 ENHANCED: Cleanup mentor data with better error handling
  Future<void> _cleanupMentorData(String userId) async {
    try {
      print('🧹 Cleaning up mentor data for $userId...');
      
      // Mark mentor stats as inactive
      await FirebaseFirestore.instance.collection('mentorStats').doc(userId).update({
        'active': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
      
      // Remove mentor assignments from mentees
      QuerySnapshot menteeAssignments = await FirebaseFirestore.instance
          .collection('users')
          .where('mentorId', isEqualTo: userId)
          .get();
      
      if (menteeAssignments.docs.isNotEmpty) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (QueryDocumentSnapshot doc in menteeAssignments.docs) {
          batch.update(doc.reference, {'mentorId': FieldValue.delete()});
        }
        await batch.commit();
        print('🧹 Removed mentor assignments from ${menteeAssignments.docs.length} mentees');
      }
      
      print('✅ Mentor data cleanup completed for $userId');
    } catch (e) {
      print('❌ Error cleaning up mentor data for $userId: $e');
    }
  }
  // Add this method to your AppState class

Future<void> fetchArticles() async {
  try {
    print('🔄 Fetching articles...');
    
    // Set loading state
    _isLoading = true;
    notifyListeners();
    
    // Query Firestore for articles
    final QuerySnapshot articlesSnapshot = await FirebaseFirestore.instance
        .collection('articles')
        .orderBy('createdAt', descending: true)
        .get();
    
    // Convert documents to Article objects
    
    _articles = articlesSnapshot.docs.map((doc) {
  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  return Article.fromMap(data, id: doc.id); // <-- Pass the doc.id!
}).toList();
    
    print('✅ Successfully fetched ${_articles.length} articles');
    
  } catch (e) {
    print('❌ Error fetching articles: $e');
    // Don't clear articles on error, keep existing ones
  } finally {
    // Always reset loading state
    _isLoading = false;
    notifyListeners();
  }
}

  // Legacy methods 
  Future<void> fetchMentorStats(String? mentorId) async {
    if (mentorId == null) return;
    await _loadMentorStatsWithTimeout(mentorId);
    notifyListeners();
  }

  Future<void> fetchMentorEvents(String? mentorId) async {
    if (mentorId == null) return;
    await _loadMentorEventsWithTimeout(mentorId);
    notifyListeners();
  }

  Future<void> fetchMentorTasks(String? mentorId) async {
    if (mentorId == null) return;
    await _loadMentorTasksWithTimeout(mentorId);
    notifyListeners();
  }

  Future<void> initializeNewMentorData(String mentorId) async {
    await _loadMentorDataSafely();
  }

  Future<void> addMentorTask(String title, String priority, DateTime deadline) async {
    if (_user?.uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('mentorTasks').add({
        'mentorId': _user!.uid,
        'title': title,
        'priority': priority,
        'deadline': Timestamp.fromDate(deadline),
        'progress': 0,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _loadMentorTasksWithTimeout(_user!.uid);
      notifyListeners();
    } catch (e) {
      print('Error adding mentor task: $e');
    }
  }

  Future<void> updateMentorStats({
    bool incrementMessages = false,
    bool incrementSessions = false,
    double? newRating,
    bool incrementCompletedTasks = false,
  }) async {
    if (_user?.uid == null) return;

    try {
      Map<String, dynamic> updates = {};

      if (incrementMessages) {
        updates['totalMessages'] = FieldValue.increment(1);
      }

      if (incrementSessions) {
        updates['totalSessions'] = FieldValue.increment(1);
      }

      if (newRating != null && _mentorStats != null) {
        final currentTotal = _mentorStats!.averageRating * _mentorStats!.totalSessions;
        final newTotal = currentTotal + newRating;
        final newAverage = newTotal / (_mentorStats!.totalSessions + 1);
        updates['averageRating'] = newAverage;
      }

      if (incrementCompletedTasks) {
        updates['completedTasks'] = FieldValue.increment(1);
      }

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('mentorStats')
            .doc(_user!.uid)
            .update(updates);

        await _loadMentorStatsWithTimeout(_user!.uid);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating mentor stats: $e');
    }
  }

  Future<void> onMessageSent() async {
    if (isMentor) {
      await updateMentorStats(incrementMessages: true);
    }
  }

  Future<void> onSessionCompleted(double rating) async {
    if (isMentor) {
      await updateMentorStats(incrementSessions: true, newRating: rating);
    }
  }

  Future<void> updateMenteeLastActivity(String menteeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(menteeId)
          .update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating mentee last activity: $e');
    }
  }

  Future<void> forceRefreshMentorData() async {
    if (_user?.uid == null) return;
    await _loadMentorDataSafely();
  }

  Future<void> fetchNotifications() async {
    await _loadNotifications();
  }
// REPLACE your existing fetchMentees method in AppState with this fixed version:

Future<void> fetchMentees() async {
  if (_user == null) return;
  
  try {
    print('🔍 fetchMentees called for user: ${_user!.uid}, role: ${_userData?.role}');
    
    if (isMentor) {
      // FIXED: Query for mentees specifically assigned to this mentor
      print('🎯 Fetching mentees for mentor: ${_user!.uid}');
      
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'mentee')
          .where('mentorId', isEqualTo: _user!.uid)
          .get();

      _mentees = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id; // Ensure uid is set
        return UserData.fromMap(data);
      }).toList();
      
      print('✅ Mentor found ${_mentees.length} assigned mentees');
      
    } else if (isDoctor) {
      // FIXED: Query for mentees assigned to this doctor
      print('🎯 Fetching mentees for doctor: ${_user!.uid}');
      
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'mentee')
          .where('doctorId', isEqualTo: _user!.uid)
          .get();

      _mentees = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id; // Ensure uid is set
        return UserData.fromMap(data);
      }).toList();
      
      print('✅ Doctor found ${_mentees.length} assigned mentees');
      
    } else if (isAdmin) {
      // For admins: load all mentees
      print('🎯 Fetching all mentees for admin');
      await loadMentees();
      
    } else {
      print('⚠️ User role ${_userData?.role} not handled in fetchMentees');
      _mentees = [];
    }
  } catch (e) {
    print('❌ Error fetching mentees: $e');
    _mentees = [];
  }
  
  notifyListeners();
}

// ALSO ADD this helper method to your AppState for doctor assignment functionality:

Future<void> assignMentorToMenteeByDoctor(String menteeId, String mentorId) async {
  if (_user == null || !isDoctor) {
    print('❌ Not authorized to assign mentors');
    return;
  }
  
  try {
    print('🔄 Doctor ${_user!.uid} assigning mentor $mentorId to mentee $menteeId');
    
    // Update the mentee's mentorId field
    await FirebaseFirestore.instance
        .collection('users')
        .doc(menteeId)
        .update({
      'mentorId': mentorId,
      'assignedAt': FieldValue.serverTimestamp(),
      'assignedBy': _user!.uid,
    });
    
    print('✅ Successfully assigned mentor to mentee');
    
    // Refresh mentees list
    await fetchMentees();
    
    // Send notifications
    final mentorDoc = await FirebaseFirestore.instance.collection('users').doc(mentorId).get();
    final menteeDoc = await FirebaseFirestore.instance.collection('users').doc(menteeId).get();
    
    final mentorName = mentorDoc.data()?['name'] ?? 'Mentor';
    final menteeName = menteeDoc.data()?['name'] ?? 'Mentee';
    
    await NotificationService.sendAssignmentNotification(
      userId: menteeId,
      assignmentType: 'mentor',
      assignedToName: mentorName,
      assignedById: _user!.uid,
      assignedByName: _userData?.name,
    );
    
    await NotificationService.sendAssignmentNotification(
      userId: mentorId,
      assignmentType: 'mentee',
      assignedToName: menteeName,
      assignedById: _user!.uid,
      assignedByName: _userData?.name,
    );
    
  } catch (e) {
    print('❌ Error assigning mentor to mentee: $e');
    rethrow;
  }
}
  Future<void> loadMentees() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'mentee')
          .get();
      
      _mentees = snapshot.docs.map((doc) {
        return UserData.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
      
      notifyListeners();
    } catch (e) {
      print('Error loading mentees: $e');
    }
  }

  Future<void> _loadAllUsers() async {
    await loadAllUsersNow();
  }

  // Authentication methods
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      UserCredential result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password
      );
      await saveFcmToken();
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🔔 ENHANCED: Sign up with admin approval notification
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password, String role) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      UserCredential result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password
      );
      
      // Create user profile with approved=false initially for all users
      await FirebaseFirestore.instance.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'email': email,
        'role': role,
        'name': email.split('@')[0], // Default name
        'createdAt': Timestamp.now(),
        'points': 0,
        'approved': false, // Set to false for all users initially
      });
      
      // Save FCM token for notifications
      await saveFcmToken();
      
      // 🔔 NEW: Send notification to user about waiting for approval
      await NotificationService.sendSystemNotification(
        userId: result.user!.uid,
        title: 'Account Created Successfully!',
        message: 'Welcome! Your account has been created and is pending admin approval. You will be notified once approved.',
        data: {
          'type': 'account_created',
          'role': role,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      
      print('✅ Signup notification sent to user: ${result.user!.uid}');
      
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🔔 ENHANCED: Sign out with notification service cleanup
  Future<void> signOut() async {
    print('🚀 Starting sign out process...');
    
    try {
      // Dispose notification service to stop all notifications
      await NotificationService.dispose();
      print('✅ Notification service disposed');
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      print('✅ Firebase sign out completed');
    } catch (e) {
      print('❌ Error during sign out: $e');
    }
  }

  // Admin methods
  Future<void> approveUser(String userId) async {
    try {
      print('🔄 Approving user: $userId');
      
      // Update user approval status
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'approved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _user?.uid,
      });
      
      print('✅ User approved in database: $userId');
      
      // Reload all users to reflect changes
      await loadAllUsersNow();
      
      // Get the approved user's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final fcmToken = userData['fcmToken'] as String?;
        final userName = userData['name'] as String? ?? 'User';
        
        print('🔔 Sending approval notification to $userName (${userId})');
        
        // Create in-app notification
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': userId,
          'title': 'Account Approved! 🎉',
          'message': 'Congratulations! Your account has been approved and you can now access all features.',
          'type': 'approval',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'data': {
            'approvedBy': _userData?.name ?? 'Admin',
            'approvedAt': DateTime.now().toIso8601String(),
          },
        });
        
        // Send FCM push notification if user has a token
        if (fcmToken != null && fcmToken.isNotEmpty) {
          print('📱 Sending FCM push notification to approved user');
          
          await NotificationService.sendFcmPushNotification(
            token: fcmToken,
            title: 'Account Approved! 🎉',
            body: 'Congratulations! Your account has been approved and you can now access all features.',
            data: {
              'type': 'approval',
              'userId': userId,
              'approvedBy': _userData?.name ?? 'Admin',
            },
          );
          
          print('✅ FCM notification sent successfully');
        } else {
          print('⚠️ No FCM token found for user, only in-app notification sent');
        }
      }
      
      print('✅ User approval completed: $userId');
      
    } catch (e) {
      print('❌ Error approving user: $e');
      rethrow;
    }
  }
  // Add this method to your AppState class, right after the approveUser method

// Add this method to your AppState class, right after the approveUser method
Future<void> disapproveUser(String userId) async {
  try {
    print('🔄 Disapproving user: $userId');
    
    // Mark user as disapproved (keeps them in "waiting for approval" state)
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'approved': false,
      'disapprovedAt': FieldValue.serverTimestamp(),
      'disapprovedBy': _user?.uid,
      'wasDisapproved': true, // NEW: Track that this user was specifically disapproved
    });
    
    print('✅ User marked as disapproved: $userId');
    
    // Reload all users to reflect changes
    await loadAllUsersNow();
    
    // Get the disapproved user's FCM token
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmToken = userData['fcmToken'] as String?;
      final userName = userData['name'] as String? ?? 'User';
      
      print('🔔 Sending disapproval notification to $userName (${userId})');
      
      // Create in-app notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': 'Account Application Update',
        'message': 'Your account application was not approved. Please contact support if you believe this is an error.',
        'type': 'disapproval',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'data': {
          'disapprovedBy': _userData?.name ?? 'Admin',
          'disapprovedAt': DateTime.now().toIso8601String(),
        },
      });
      
      // Send FCM push notification if user has a token
      if (fcmToken != null && fcmToken.isNotEmpty) {
        print('📱 Sending FCM push notification to disapproved user');
        
        await NotificationService.sendFcmPushNotification(
          token: fcmToken,
          title: 'Account Application Update',
          body: 'Your account application was not approved. Please contact support if you believe this is an error.',
          data: {
            'type': 'disapproval',
            'userId': userId,
            'disapprovedBy': _userData?.name ?? 'Admin',
          },
        );
        
        print('✅ FCM notification sent successfully');
      } else {
        print('⚠️ No FCM token found for user, only in-app notification sent');
      }
    }
    
    print('✅ User disapproval completed: $userId');
    
  } catch (e) {
    print('❌ Error disapproving user: $e');
    rethrow;
  }
}

  Future<void> assignMenteeToDoctor(String menteeId, String doctorId) async {
    final doctorDoc = await FirebaseFirestore.instance.collection('users').doc(doctorId).get();
    final menteeDoc = await FirebaseFirestore.instance.collection('users').doc(menteeId).get();
    
    final doctorName = doctorDoc.data()?['name'] ?? 'Doctor';
    final menteeName = menteeDoc.data()?['name'] ?? 'Mentee';
    
    await FirebaseFirestore.instance.collection('users').doc(menteeId).update({
      'doctorId': doctorId
    });
    await loadAllUsersNow();
    
    await NotificationService.sendAssignmentNotification(
      userId: menteeId,
      assignmentType: 'doctor',
      assignedToName: doctorName,
      assignedById: _user?.uid,
      assignedByName: _userData?.name,
    );
    
    await NotificationService.sendAssignmentNotification(
      userId: doctorId,
      assignmentType: 'patient',
      assignedToName: menteeName,
      assignedById: _user?.uid,
      assignedByName: _userData?.name,
    );
  }

  Future<void> assignMenteeToMentor(String menteeId, String mentorId) async {
    final mentorDoc = await FirebaseFirestore.instance.collection('users').doc(mentorId).get();
    final menteeDoc = await FirebaseFirestore.instance.collection('users').doc(menteeId).get();
    
    final mentorName = mentorDoc.data()?['name'] ?? 'Mentor';
    final menteeName = menteeDoc.data()?['name'] ?? 'Mentee';
    
    await FirebaseFirestore.instance.collection('users').doc(menteeId).update({
      'mentorId': mentorId
    });
    await loadAllUsersNow();
    
    await NotificationService.sendAssignmentNotification(
      userId: menteeId,
      assignmentType: 'mentor',
      assignedToName: mentorName,
      assignedById: _user?.uid,
      assignedByName: _userData?.name,
    );
    
    await NotificationService.sendAssignmentNotification(
      userId: mentorId,
      assignmentType: 'mentee',
      assignedToName: menteeName,
      assignedById: _user?.uid,
      assignedByName: _userData?.name,
    );
  }

 // Replace ONLY the addArticle method in your app_state.dart with this:

Future<void> addArticle(String title, String content, String category) async {
  try {
    print('📰 Adding new article: $title');
    
    // Add the article to Firestore
    final articleDoc = await FirebaseFirestore.instance.collection('articles').add({
      'category': category,
      'content': content,
      'createdAt': Timestamp.now(),
      'createdBy': _user!.uid,
      'title': title
    });
    
    print('✅ Article added with ID: ${articleDoc.id}');
    
    // Reload articles list
    await _loadArticles();
    
    // ADDED: Send notifications to ALL users about the new article
    await _notifyAllUsersAboutNewArticle(title, category, articleDoc.id);
    
    print('✅ Article notifications sent to all users');
    
  } catch (e) {
    print('❌ Error adding article: $e');
    rethrow;
  }
}
// ADD this method to your AppState class in app_state.dart

// 🔔 NEW: Mark only article notifications as read for current user
Future<void> markArticleNotificationsAsRead() async {
  if (_user == null) return;
  
  try {
    print('📰 Marking article notifications as read for user: ${_user!.uid}');
    
    // Get all unread article notifications for this specific user
    QuerySnapshot unreadArticleNotifications = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: _user!.uid)  // CRITICAL: Only for this user
        .where('type', isEqualTo: 'article')     // CRITICAL: Only article notifications
        .where('read', isEqualTo: false)         // CRITICAL: Only unread ones
        .get();
    
    print('📰 Found ${unreadArticleNotifications.docs.length} unread article notifications for user');
    
    if (unreadArticleNotifications.docs.isEmpty) {
      print('📰 No unread article notifications to mark as read');
      return;
    }
    
    // Create batch to update all unread article notifications for this user
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    for (QueryDocumentSnapshot doc in unreadArticleNotifications.docs) {
      batch.update(doc.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    
    // Commit the batch update
    await batch.commit();
    
    print('✅ Successfully marked ${unreadArticleNotifications.docs.length} article notifications as read for user: ${_user!.uid}');
    
    // Refresh notifications to update the UI
    await _loadNotifications();
    
  } catch (e) {
    print('❌ Error marking article notifications as read: $e');
    // Don't rethrow - this is not critical enough to break the user experience
  }
}
// ADD this new method to your AppState class:
Future<void> _notifyAllUsersAboutNewArticle(String articleTitle, String category, String articleId) async {
  try {
    print('📧 Sending article notifications to all users...');
    
    // Get all approved users (exclude unapproved users)
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('approved', isEqualTo: true)
        .get();
    
    print('📧 Found ${usersSnapshot.docs.length} approved users to notify');
    
    // Create notifications batch
    final batch = FirebaseFirestore.instance.batch();
    final now = Timestamp.now();
    
    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      
      // Don't send notification to the article creator (admin)
      if (userId == _user!.uid) {
        print('📧 Skipping notification for article creator: $userId');
        continue;
      }
      
      // Create notification document
      final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
      
      batch.set(notificationRef, {
        'userId': userId,
        'title': 'New Article Published',
        'message': 'Check out the new article: "$articleTitle" in $category',
        'type': 'article',
        'timestamp': now,
        'read': false,
        'data': {
          'articleId': articleId,
          'articleTitle': articleTitle,
          'category': category,
          'createdBy': _userData?.name ?? 'Admin',
        },
      });
      
      print('📧 Added notification for user: $userId');
    }
    
    // Commit all notifications at once
    await batch.commit();
    
    print('✅ Successfully sent ${usersSnapshot.docs.length - 1} article notifications');
    
  } catch (e) {
    print('❌ Error sending article notifications: $e');
    // Don't rethrow - article was still created successfully
  }
}

  Future<void> _loadArticles() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('articles')
          .orderBy('createdAt', descending: true)
          .get();
      
     // In _loadArticles and fetchArticles, update the mapping like this:
_articles = snapshot.docs.map((doc) {
  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  return Article.fromMap(data, id: doc.id); // <-- Pass the doc.id!
}).toList();
    } catch (e) {
      print('Error loading articles: $e');
    }
    
    notifyListeners();
  }

  Future<void> _loadNotifications() async {
    if (_user == null) return;
    
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _user!.uid)
          .orderBy('timestamp', descending: true)
          .get();
      
      _notifications = snapshot.docs.map((doc) {
        return MyNotification.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      notifyListeners();
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  // 🔔 ENHANCED: Medication reminder with full notification system
  Future<void> setMedicationReminder(String medication, TimeOfDay time, List<bool> daysOfWeek) async {
    if (_user == null) return;
    
    print('💊 Setting medication reminder for: $medication at ${time.hour}:${time.minute}');
    
    try {
      // Create a unique reminder ID
      final reminderDoc = FirebaseFirestore.instance.collection('medication_reminders').doc();
      final reminderId = reminderDoc.id;
      
      // Store reminder in Firestore
      await reminderDoc.set({
        'userId': _user!.uid,
        'medication': medication,
        'hour': time.hour,
        'minute': time.minute,
        'daysOfWeek': daysOfWeek,
        'createdAt': Timestamp.now(),
        'active': true
      });
      
      print('✅ Reminder stored in Firestore with ID: $reminderId');
      
      // Schedule device notifications
      await NotificationService.scheduleMedicationReminder(
        medicationId: reminderId,
        medicationName: medication,
        hour: time.hour,
        minute: time.minute,
        daysOfWeek: daysOfWeek,
        userId: _user!.uid,
      );
      
      print('✅ Device notifications scheduled for: $medication');
      
    } catch (e) {
      print('❌ Error setting medication reminder: $e');
    }
  }

  Future<void> trackMedicationAdherence(String reminderId, bool taken) async {
    if (_user == null) return;
    
    await FirebaseFirestore.instance.collection('medication_tracking').add({
      'userId': _user!.uid,
      'reminderId': reminderId,
      'taken': taken,
      'timestamp': Timestamp.now()
    });
  }

  Future<void> updateUserProfile(String name, String? photoUrl) async {
    if (_user == null) return;
    
    Map<String, dynamic> updateData = {
      'name': name,
    };
    
    if (photoUrl != null) {
      updateData['photoUrl'] = photoUrl;
    }
    
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update(updateData);
    await _loadUserData();
  }

  Future<int> getUnreadMessageCount(String otherUserId) async {
    if (_user == null) return 0;
    
    try {
      QuerySnapshot unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('recipientId', isEqualTo: _user!.uid)
          .where('read', isEqualTo: false)
          .get();
      
      return unreadMessages.size;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }

  Future<bool> hasMenteesAssigned() async {
    if (_user == null || !isDoctor) return false;
    
    try {
      QuerySnapshot mentees = await FirebaseFirestore.instance
          .collection('users')
          .where('doctorId', isEqualTo: _user!.uid)
          .limit(1)
          .get();
      
      return mentees.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if doctor has mentees: $e');
      return false;
    }
  }

  Future<bool> hasDoctorAssigned() async {
    if (_user == null || !isMentee) return false;
    
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['doctorId'] != null;
      }
      return false;
    } catch (e) {
      print('Error checking if mentee has doctor: $e');
      return false;
    }
  }

  Future<UserData?> getAssignedDoctor() async {
    if (_user == null || !isMentee || _userData?.doctorId == null) return null;
    
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userData!.doctorId!)
          .get();
      
      if (doc.exists) {
        return UserData.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting assigned doctor: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMenteesWithChatStatus() async {
    if (_user == null || !isDoctor) return [];
    
    try {
      QuerySnapshot mentees = await FirebaseFirestore.instance
          .collection('users')
          .where('doctorId', isEqualTo: _user!.uid)
          .get();
      
      List<Map<String, dynamic>> result = [];
      
      for (var doc in mentees.docs) {
        UserData mentee = UserData.fromMap(doc.data() as Map<String, dynamic>);
        
        int unreadCount = await getUnreadMessageCount(mentee.uid);
        
        QuerySnapshot lastMessageQuery = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', whereIn: [_user!.uid, mentee.uid])
            .where('recipientId', whereIn: [_user!.uid, mentee.uid])
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
        
        Timestamp? lastMessageTime;
        if (lastMessageQuery.docs.isNotEmpty) {
          lastMessageTime = (lastMessageQuery.docs.first.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
        }
        
        result.add({
          'mentee': mentee,
          'unreadCount': unreadCount,
          'lastMessageTime': lastMessageTime,
        });
      }
      
      result.sort((a, b) {
        final aTime = a['lastMessageTime'];
        final bTime = b['lastMessageTime'];
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        return bTime.compareTo(aTime);
      });
      
      return result;
    } catch (e) {
      print('Error getting mentees with chat status: $e');
      return [];
    }
  }

  // 🔔 ENHANCED: Notification system methods with full integration
  Future<void> sendSystemAnnouncement({
    required String message,
    String? title,
    String? targetRole,
  }) async {
    if (!isAdmin) return;
    
    if (targetRole != null) {
      await NotificationService.sendRoleBasedNotification(
        role: targetRole,
        message: message,
        title: title ?? 'System Announcement',
        type: 'system',
      );
    } else {
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      final userIds = allUsersSnapshot.docs.map((doc) => doc.id).toList();
      
      await NotificationService.sendBulkNotifications(
        userIds: userIds,
        message: message,
        title: title ?? 'System Announcement',
        type: 'system',
      );
    }
  }

  Future<void> scheduleAppointmentReminder({
    required String userId,
    required String doctorName,
    required DateTime appointmentTime,
    String? appointmentId,
  }) async {
    final reminderTime = appointmentTime.subtract(Duration(hours: 1));
    
    await NotificationService.scheduleNotification(
      userId: userId,
      title: 'Upcoming Appointment',
      message: 'You have an appointment with Dr. $doctorName in 1 hour',
      scheduledTime: reminderTime,
      type: 'appointment',
      data: {
        'appointmentTime': appointmentTime.toIso8601String(),
        'doctorName': doctorName,
        'appointmentId': appointmentId,
      },
    );
  }

  Future<Map<String, dynamic>> getNotificationStats() async {
    if (_user == null) return {};
    
    return await NotificationService.getNotificationStats(_user!.uid);
  }

  // 🔧 DEBUG: Check what's actually happening in Firestore
  Future<void> debugUserRole(String userId) async {
    try {
      print('🔍 DEBUGGING USER ROLE for $userId');
      
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        print('❌ User document does not exist');
        return;
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      print('📋 USER DATA:');
      print('   Role: ${userData['role']}');
      print('   Name: ${userData['name']}');
      print('   Email: ${userData['email']}');
      print('   Approved: ${userData['approved']}');
      print('   Created: ${userData['createdAt']}');
      print('   Last Role Change: ${userData['roleChangedAt']}');
      print('   Previous Role: ${userData['previousRole']}');
      print('   Changed By: ${userData['roleChangedBy']}');
      
    } catch (e) {
      print('❌ Error debugging user role: $e');
    }
  }

  // 🔧 DEBUG: Test promotion with full logging
  Future<void> testPromotion(String userId) async {
    print('🧪 TESTING PROMOTION FOR USER: $userId');
    
    try {
      // Check user before
      await debugUserRole(userId);
      
      // Attempt promotion
      print('🔄 ATTEMPTING PROMOTION...');
      await promoteMenteeToMentor(userId);
      
      // Wait a moment for Firestore to update
      await Future.delayed(Duration(seconds: 2));
      
      // Check user after
      print('🔍 CHECKING USER AFTER PROMOTION:');
      await debugUserRole(userId);
      
      // Force reload our cached data
      await loadAllUsersNow();
      
      print('✅ TEST PROMOTION COMPLETED');
      
    } catch (e) {
      print('❌ TEST PROMOTION FAILED: $e');
    }
  }

  // 🔔 NEW: Test notification methods for debugging
  Future<void> testNotificationSystem() async {
    print('🧪 Testing notification system...');
    
    await NotificationService.testNotification();
    
    if (_user != null) {
      await NotificationService.sendSystemNotification(
        userId: _user!.uid,
        title: 'Test System Notification',
        message: 'This is a test system notification to verify the notification system is working properly.',
      );
    }
  }

  Future<void> testMedicationNotification(String medicationName) async {
    print('🧪 Testing medication notification for: $medicationName');
    
    await NotificationService.testAlarmIn30Seconds(medicationName);
  }

  Future<void> debugNotificationSystem() async {
    print('🔧 Debugging notification system...');
    
    await NotificationService.debugMedicationSetup();
    
    final pending = await NotificationService.getPendingNotifications();
    print('📱 Pending notifications: ${pending.length}');
    
    final logs = NotificationService.getDebugLogs();
    print('📋 Recent notification logs:');
    for (int i = 0; i < logs.length.clamp(0, 10); i++) {
      print('   ${logs[i]}');
    }
  }

  // 🔔 NEW: Get medication reminders for current user
  Future<List<Map<String, dynamic>>> getMedicationReminders() async {
    if (_user == null) return [];
    
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('medication_reminders')
          .where('userId', isEqualTo: _user!.uid)
          .where('active', isEqualTo: true)
          .orderBy('hour')
          .orderBy('minute')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'medication': data['medication'],
          'hour': data['hour'],
          'minute': data['minute'],
          'daysOfWeek': List<bool>.from(data['daysOfWeek'] ?? []),
          'active': data['active'] ?? true,
          'createdAt': data['createdAt'],
        };
      }).toList();
    } catch (e) {
      print('Error getting medication reminders: $e');
      return [];
    }
  }

  // 🔔 NEW: Cancel medication reminder
  Future<void> cancelMedicationReminder(String reminderId) async {
    try {
      await NotificationService.cancelMedicationReminder(reminderId);
      
      await FirebaseFirestore.instance
          .collection('medication_reminders')
          .doc(reminderId)
          .update({
        'active': false,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Medication reminder cancelled: $reminderId');
    } catch (e) {
      print('❌ Error cancelling medication reminder: $e');
    }
  }

  // 🔔 NEW: Send message with notification
  Future<void> sendMessage({
    required String recipientId,
    required String content,
    required String senderName,
  }) async {
    if (_user == null) return;
    
    try {
      // Store message in Firestore
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': _user!.uid,
        'recipientId': recipientId,
        'senderName': senderName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      
      // Send notification
      await NotificationService.sendMessageNotification(
        recipientId: recipientId,
        senderId: _user!.uid,
        senderName: senderName,
        messageContent: content,
      );
      
      print('✅ Message sent with notification');
    } catch (e) {
      print('❌ Error sending message: $e');
    }
  }

  // 🔔 NEW: Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await NotificationService.markNotificationAsRead(notificationId);
      await _loadNotifications(); // Refresh notifications
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // 🔔 NEW: Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    if (_user == null) return;
    
    try {
      await NotificationService.markAllAsReadForUser(_user!.uid);
      await _loadNotifications(); // Refresh notifications
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }

  // 🔔 NEW: Force check for reminders (for testing)
  Future<void> forceCheckReminders() async {
    await NotificationService.forceCheckReminders();
  }

  // 🔔 NEW: Get notification debug logs
  List<String> getNotificationDebugLogs() {
    return NotificationService.getDebugLogs();
  }

  // 🔔 NEW: Clear notification debug logs
  void clearNotificationDebugLogs() {
    NotificationService.clearDebugLogs();
  }
}