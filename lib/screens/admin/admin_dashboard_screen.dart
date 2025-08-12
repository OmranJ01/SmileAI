import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/app_state.dart';
import '../../models/user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'assigning_screen.dart';
import 'promote_mentee_screen.dart';
import '../../widgets/expandable_action_card.dart';
import '../../widgets/dashboard-calendar-widget.dart';
import '../../services/notification_service.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class AddArticleScreen extends StatefulWidget {
  const AddArticleScreen({super.key});

  @override
  _AddArticleScreenState createState() => _AddArticleScreenState();
}

class _AddArticleScreenState extends State<AddArticleScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'Gingival Disease';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Article'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              value: _selectedCategory,
              items: [
                DropdownMenuItem(value: 'Gingival Disease', child: Text('Gingival Disease')),
                DropdownMenuItem(value: 'Oral Hygiene', child: Text('Oral Hygiene')),
                DropdownMenuItem(value: 'Dental Care', child: Text('Dental Care')),
                DropdownMenuItem(value: 'Preventive Care', child: Text('Preventive Care')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }
                
                await appState.addArticle(
                  _titleController.text,
                  _contentController.text,
                  _selectedCategory,
                );
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Article added successfully')),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Add Article'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  List<UserData> _pendingUsers = [];
  bool _isLoading = true;

  // User counts
  int _totalUsers = 0;
  int _totalMentors = 0;
  int _totalMentees = 0;
  int _totalDoctors = 0;
  int _totalPendingUsers = 0;

  // Pending users management
  bool _isPendingUsersExpanded = false;
  bool _isLoadingPendingUsers = true;

  // Mentor management variables
  bool _isMentorsExpanded = false;
  
  // Mentors list and management
  List<UserData> _mentorsList = [];
  bool _isLoadingMentors = true;
  TextEditingController _searchMentorController = TextEditingController();
  List<UserData> _filteredMentors = [];
  
  // Mentees list and management
  List<UserData> _menteesList = [];
  bool _isLoadingMentees = true;
  TextEditingController _searchMenteeController = TextEditingController();
  List<UserData> _filteredMentees = [];

  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoadingFeedbacks = true;
  bool _isFeedbacksExpanded = false;

  // Analytics data
  int _totalMessages = 0;
  int _totalSessions = 0;
  double _averageRating = 0.0;
  
  // Tab controller for points management
  late TabController _pointsTabController;

  @override
  void initState() {
    super.initState();
    _pointsTabController = TabController(length: 2, vsync: this);
    _loadPendingUsers();
    _loadMentors();
    _loadMentees();
    _loadFeedbacks();
    _searchMentorController.addListener(_filterMentors);
    _searchMenteeController.addListener(_filterMentees);
    _checkPromotionsOnAppStart();

  }

// Check for promotions when admin first enters the app
Future<void> _checkPromotionsOnAppStart() async {
  try {
    print('🚀 Admin entered app - checking for promotion recommendations...');
    
    // Wait a bit for other loading to complete
    await Future.delayed(Duration(seconds: 2));
    
    // Load fresh mentee data and check promotions
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.loadAllUsersNow();
    
    final menteesList = appState.mentees.where((m) => m.approved).toList();
    
    for (final mentee in menteesList) {
      final currentPoints = mentee.points ?? 0;
      
      if (currentPoints >= 100) {
        print('⭐ App start check: Found mentee ${mentee.name} with $currentPoints points');
        
        // ALWAYS send notification when admin enters app - don't check for existing notifications
        print('🔔 App start: Sending promotion recommendation for ${mentee.name}');
        
        // Get current admin user (the one who just opened the app)
        final currentUser = Provider.of<AppState>(context, listen: false).userData;
        if (currentUser != null) {
          await NotificationService.sendSystemNotification(
            userId: currentUser.uid,
            title: 'Mentee Ready for Promotion',
            message: '${mentee.name} currently has $currentPoints points and may be ready for promotion to mentor status.',
            data: {
              'menteeId': mentee.uid,
              'menteeName': mentee.name,
              'menteeEmail': mentee.email,
              'currentPoints': currentPoints,
              'recommendationType': 'promotion_to_mentor',
              'timestamp': DateTime.now().toIso8601String(),
              'triggerType': 'app_start_check',
            },
          );
          
          print('✅ App start: Promotion recommendation sent for ${mentee.name}');
        }
        
        // Also send to all other admins
        final adminQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .where('approved', isEqualTo: true)
            .get();
        
        for (final adminDoc in adminQuery.docs) {
          if (adminDoc.id != currentUser?.uid) { // Don't send to current admin twice
            await NotificationService.sendSystemNotification(
              userId: adminDoc.id,
              title: 'Mentee Ready for Promotion',
              message: '${mentee.name} currently has $currentPoints points and may be ready for promotion to mentor status.',
              data: {
                'menteeId': mentee.uid,
                'menteeName': mentee.name,
                'menteeEmail': mentee.email,
                'currentPoints': currentPoints,
                'recommendationType': 'promotion_to_mentor',
                'timestamp': DateTime.now().toIso8601String(),
                'triggerType': 'app_start_check',
              },
            );
          }
        }
      }
    }
    
    print('✅ App start promotion check completed');
  } catch (e) {
    print('❌ Error checking promotions on app start: $e');
  }
}



  @override
  void dispose() {
    _searchMentorController.dispose();
    _searchMenteeController.dispose();
    _pointsTabController.dispose();
    super.dispose();
  }


 Future<void> _checkAllMenteesForPromotion() async {
  try {
    print('🔍 Initial check: Looking for mentees with 100+ points...');
    
    for (final mentee in _menteesList) {
      final currentPoints = mentee.points ?? 0;
      
      if (currentPoints >= 100) {
        print('⭐ Initial check: Found mentee ${mentee.name} with $currentPoints points');
        
        // Check if we already sent a promotion recommendation recently (within last 24 hours)
        final oneDayAgo = DateTime.now().subtract(Duration(days: 1));
        final recentNotifications = await FirebaseFirestore.instance
            .collection('notifications')
            .where('type', isEqualTo: 'system')
            .where('data.recommendationType', isEqualTo: 'promotion_to_mentor')
            .where('data.menteeId', isEqualTo: mentee.uid)
            .where('timestamp', isGreaterThan: Timestamp.fromDate(oneDayAgo))
            .get();
        
        if (recentNotifications.docs.isEmpty) {
          print('🔔 Initial check: Sending promotion recommendation for ${mentee.name}');
          
          // Get all admin users
          final adminQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .where('approved', isEqualTo: true)
              .get();
          
          if (adminQuery.docs.isNotEmpty) {
            // Send notification to all admins
            for (final adminDoc in adminQuery.docs) {
              await NotificationService.sendSystemNotification(
                userId: adminDoc.id,
                title: 'Mentee Promotion Recommendation',
                message: '${mentee.name} has $currentPoints points and may be ready for promotion to mentor status.',
                data: {
                  'menteeId': mentee.uid,
                  'menteeName': mentee.name,
                  'menteeEmail': mentee.email,
                  'currentPoints': currentPoints,
                  'recommendationType': 'promotion_to_mentor',
                  'timestamp': DateTime.now().toIso8601String(),
                  'triggerType': 'initial_check',
                },
              );
            }
            
            print('✅ Initial check: All admins notified about ${mentee.name}');
          }
        } else {
          print('ℹ️ Initial check: Recent notification exists for ${mentee.name} - skipping');
        }
      }
    }
  } catch (e) {
    print('❌ Error in initial mentee promotion check: $e');
  }
}


  Future<void> _loadPendingUsers() async {
    setState(() {
      _isLoadingPendingUsers = true;
    });

    try {
      print('=== LOADING PENDING USERS DIRECTLY FROM FIRESTORE ===');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('approved', isEqualTo: false)
          .get();

      List<UserData> pendingUsersList = [];
      
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          print('Found user: ${data['name']} - Role: ${data['role']} - Approved: ${data['approved']}');
          
          if (data['disapprovedAt'] == null) {
            final user = UserData(
              uid: doc.id,
              name: data['name'] ?? '',
              email: data['email'] ?? '',
              role: data['role'] ?? '',
              approved: data['approved'] ?? false,
              createdAt: data['createdAt'] ?? Timestamp.now(),
              photoUrl: data['photoUrl'],
              points: data['points'],
              disapprovedAt: data['disapprovedAt'],
            );
            pendingUsersList.add(user);
            print('Added to pending list: ${user.name}');
          } else {
            print('User ${data['name']} was disapproved, skipping');
          }
        } catch (e) {
          print('Error processing user doc ${doc.id}: $e');
        }
      }

      setState(() {
        _pendingUsers = pendingUsersList;
      });
      
      print('Total pending users loaded: ${_pendingUsers.length}');
      print('=== END LOADING PENDING USERS ===');
      
    } catch (e) {
      print('Error loading pending users: $e');
    } finally {
      setState(() {
        _isLoadingPendingUsers = false;
      });
    }
  }


// Enhanced promotion check that works for any points update
Future<void> _checkMenteePromotionEligibility(UserData mentee, int newPoints) async {
  try {
    final oldPoints = mentee.points ?? 0;
    
    print('🔍 Checking promotion for ${mentee.name}: $oldPoints → $newPoints points');
    
    // Check if mentee just crossed the 100-point threshold (going from below to above)
    if (oldPoints < 100 && newPoints >= 100) {
      print('🌟 Mentee ${mentee.name} crossed 100 points threshold! Sending promotion recommendation...');
      
      // Get all admin users
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('approved', isEqualTo: true)
          .get();
      
      if (adminQuery.docs.isNotEmpty) {
        // Send notification to all admins - ALWAYS send when crossing threshold
        for (final adminDoc in adminQuery.docs) {
          await NotificationService.sendSystemNotification(
            userId: adminDoc.id,
            title: 'Mentee Promotion Recommendation',
            message: '${mentee.name} has reached $newPoints points! Consider promoting them to mentor status.',
            data: {
              'menteeId': mentee.uid,
              'menteeName': mentee.name,
              'menteeEmail': mentee.email,
              'currentPoints': newPoints,
              'previousPoints': oldPoints,
              'recommendationType': 'promotion_to_mentor',
              'timestamp': DateTime.now().toIso8601String(),
              'triggerType': 'threshold_crossed',
            },
          );
          
          print('✅ Promotion recommendation sent to admin: ${adminDoc.id}');
        }
        
        print('✅ All admins notified about ${mentee.name} crossing 100-point threshold');
      } else {
        print('⚠️ No admin users found to send promotion recommendation');
      }
    } else if (oldPoints >= 100 && newPoints < 100) {
      print('📉 Mentee ${mentee.name} dropped below 100 points ($oldPoints → $newPoints)');
    } else if (newPoints >= 100) {
      print('ℹ️ Mentee ${mentee.name} already above 100 points ($oldPoints → $newPoints) - no threshold crossed');
    } else {
      print('ℹ️ Mentee ${mentee.name} still below 100 points ($oldPoints → $newPoints)');
    }
  } catch (e) {
    print('❌ Error checking mentee promotion eligibility: $e');
  }
}


  Future<void> _approveUser(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'approved': true});
      
      await _loadPendingUsers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error approving user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disapproveUser(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
            'approved': false,
            'disapprovedAt': FieldValue.serverTimestamp(),
          });
      
      await _loadPendingUsers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User disapproved'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error disapproving user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error disapproving user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadFeedbacks() async {
    setState(() {
      _isLoadingFeedbacks = true;
    });

    try {
      final feedbacksQuery = await FirebaseFirestore.instance
          .collection('feedbacks')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      List<Map<String, dynamic>> feedbacksList = [];
      
      for (final doc in feedbacksQuery.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        if (!data.containsKey('fromUserName')) {
          try {
            final fromUserDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['fromUserId'])
                .get();
            
            if (fromUserDoc.exists) {
              data['fromUserName'] = fromUserDoc.data()?['name'] ?? 'Unknown';
            }
          } catch (e) {
            data['fromUserName'] = 'Unknown';
          }
        }
        
        data['toUserName'] = data['subjectUserName'] ?? 'Unknown';
        data['toUserType'] = data['subjectUserRole'] ?? 'unknown';
        
        feedbacksList.add(data);
      }

      setState(() {
        _feedbacks = feedbacksList;
      });
    } catch (e) {
      print('Error loading feedbacks: $e');
    } finally {
      setState(() {
        _isLoadingFeedbacks = false;
      });
    }
  }

  Future<void> _markFeedbackReviewed(String feedbackId) async {
    try {
      await FirebaseFirestore.instance
          .collection('feedbacks')
          .doc(feedbackId)
          .update({'status': 'reviewed'});
      
      await _loadFeedbacks();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback marked as reviewed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating feedback: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating feedback'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFeedbackDetails(Map<String, dynamic> feedback) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.feedback, color: Colors.orange),
            SizedBox(width: 8),
            Text('Feedback Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      feedback['fromUserName'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: feedback['toUserType'] == 'doctor' 
                      ? Colors.red[50] 
                      : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          feedback['toUserName'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: feedback['toUserType'] == 'doctor' 
                                ? Colors.red 
                                : Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            feedback['toUserType']?.toUpperCase() ?? 'UNKNOWN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Rating: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...List.generate(5, (index) => Icon(
                    index < (feedback['rating'] ?? 0) 
                        ? Icons.star 
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  )),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Feedback:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  feedback['feedback'] ?? 'No feedback provided',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Status: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: feedback['status'] == 'reviewed' 
                          ? Colors.green[100] 
                          : Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      feedback['status']?.toUpperCase() ?? 'PENDING',
                      style: TextStyle(
                        color: feedback['status'] == 'reviewed' 
                            ? Colors.green[700] 
                            : Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (feedback['status'] != 'reviewed')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _markFeedbackReviewed(feedback['id']);
              },
              child: Text('Mark as Reviewed'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMentors() async {
    setState(() {
      _isLoadingMentors = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.loadAllUsersNow();
      
      setState(() {
        _mentorsList = appState.mentors.where((m) => m.approved).toList();
        _filteredMentors = List.from(_mentorsList);
      });
    } catch (e) {
      print('Error loading mentors: $e');
    } finally {
      setState(() {
        _isLoadingMentors = false;
      });
    }
  }

  void _filterMentors() {
    final query = _searchMentorController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMentors = List.from(_mentorsList);
      } else {
        _filteredMentors = _mentorsList.where((mentor) {
          return mentor.name.toLowerCase().contains(query) ||
                 mentor.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _updateMentorPoints(UserData mentor, int pointsChange) async {
    try {
      final newPoints = (mentor.points ?? 0) + pointsChange;
      
      if (newPoints < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Points cannot be negative'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(mentor.uid)
          .update({'points': newPoints});
      
      await NotificationService.sendNotification(
  userId: mentor.uid,
  title: pointsChange > 0 ? 'Points Added!' : 'Points Deducted',
  message: pointsChange > 0 
    ? 'Admin added $pointsChange points to your account. Total: $newPoints points'
    : 'Admin deducted ${-pointsChange} points from your account. Total: $newPoints points',
  type: 'points_update',
  data: {
    'pointsChange': pointsChange,
    'newTotal': newPoints,
  },
);
// --- ADD THIS ---
final mentorDoc = await FirebaseFirestore.instance.collection('users').doc(mentor.uid).get();
final fcmToken = mentorDoc.data()?['fcmToken'];
if (fcmToken != null) {
  await NotificationService.sendFcmPushNotification(
    token: fcmToken,
    title: pointsChange > 0 ? 'Points Added!' : 'Points Deducted',
    body: pointsChange > 0 
      ? 'Admin added $pointsChange points to your account. Total: $newPoints points'
      : 'Admin deducted ${-pointsChange} points from your account. Total: $newPoints points',
    data: {
      'pointsChange': pointsChange,
      'newTotal': newPoints,
    },
  );
}
      

      await _loadMentors();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pointsChange > 0 
              ? 'Added $pointsChange points to ${mentor.name}'
              : 'Deducted ${-pointsChange} points from ${mentor.name}'
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating mentor points: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating points'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mentee points update method



// Mentee points update method
Future<void> _updateMenteePoints(UserData mentee, int pointsChange) async {
  try {
    final newPoints = (mentee.points ?? 0) + pointsChange;
    
    if (newPoints < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Points cannot be negative'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(mentee.uid)
        .update({'points': newPoints});
    
    await NotificationService.sendNotification(
      userId: mentee.uid,
      title: pointsChange > 0 ? 'Points Added!' : 'Points Deducted',
      message: pointsChange > 0 
        ? 'Admin added $pointsChange points to your account. Total: $newPoints points'
        : 'Admin deducted ${-pointsChange} points from your account. Total: $newPoints points',
      type: 'points_update',
      data: {
        'pointsChange': pointsChange,
        'newTotal': newPoints,
      },
    );

    final menteeDoc = await FirebaseFirestore.instance.collection('users').doc(mentee.uid).get();
    final fcmToken = menteeDoc.data()?['fcmToken'];
    if (fcmToken != null) {
      await NotificationService.sendFcmPushNotification(
        token: fcmToken,
        title: pointsChange > 0 ? 'Points Added!' : 'Points Deducted',
        body: pointsChange > 0 
          ? 'Admin added $pointsChange points to your account. Total: $newPoints points'
          : 'Admin deducted ${-pointsChange} points from your account. Total: $newPoints points',
        data: {
          'pointsChange': pointsChange,
          'newTotal': newPoints,
        },
      );
    }
    
    // ✅ This checks for threshold crossing (below 100 → above 100)
    await _checkMenteePromotionEligibility(mentee, newPoints);
    await _loadMentees();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pointsChange > 0 
            ? 'Added $pointsChange points to ${mentee.name}'
            : 'Deducted ${-pointsChange} points from ${mentee.name}'
        ),
        backgroundColor: Colors.green,
      ),
    );
    
    // ❌ REMOVE THIS DUPLICATE LINE:
    // await _checkAllMenteesForPromotion();
    
  } catch (e) {
    print('Error updating mentee points: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error updating points'),
        backgroundColor: Colors.red,
      ),
    );
  }
}






  void _showPointsDialog(UserData mentor, bool isAdding) {
    final pointsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green[100],
              child: Text(
                mentor.name[0].toUpperCase(),
                style: TextStyle(color: Colors.green[800]),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isAdding ? 'Add Points' : 'Deduct Points', style: TextStyle(fontSize: 18)),
                  Text(
                    mentor.name,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars, color: Colors.orange, size: 32),
                  SizedBox(width: 8),
                  Text(
                    'Current Points: ${mentor.points ?? 0}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of Points',
                border: OutlineInputBorder(),
                prefixIcon: Icon(
                  isAdding ? Icons.add : Icons.remove,
                  color: isAdding ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final points = int.tryParse(pointsController.text);
              if (points == null || points <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid number')),
                );
                return;
              }
              
              Navigator.pop(context);
              _updateMentorPoints(mentor, isAdding ? points : -points);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAdding ? Colors.green : Colors.red,
            ),
            child: Text(isAdding ? 'Add Points' : 'Deduct Points'),
          ),
        ],
      ),
    );
  }

  // Generic points dialog for both mentors and mentees
  void _showGenericPointsDialog(UserData user, bool isAdding, bool isMentor) {
    final pointsController = TextEditingController();
    final MaterialColor avatarColor = isMentor ? Colors.green : Colors.blue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: avatarColor[100],
              child: Text(
                user.name[0].toUpperCase(),
                style: TextStyle(color: avatarColor[800]),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isAdding ? 'Add Points' : 'Deduct Points', style: TextStyle(fontSize: 18)),
                  Text(
                    '${user.name} (${isMentor ? 'Mentor' : 'Mentee'})',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars, color: Colors.orange, size: 32),
                  SizedBox(width: 8),
                  Text(
                    'Current Points: ${user.points ?? 0}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of Points',
                border: OutlineInputBorder(),
                prefixIcon: Icon(
                  isAdding ? Icons.add : Icons.remove,
                  color: isAdding ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final points = int.tryParse(pointsController.text);
              if (points == null || points <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid number')),
                );
                return;
              }
              
              Navigator.pop(context);
              if (isMentor) {
                _updateMentorPoints(user, isAdding ? points : -points);
              } else {
                _updateMenteePoints(user, isAdding ? points : -points);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAdding ? Colors.green : Colors.red,
            ),
            child: Text(isAdding ? 'Add Points' : 'Deduct Points'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final bool isPending = feedback['status'] == 'pending';
    final int rating = feedback['rating'] ?? 0;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 1,
        child: InkWell(
          onTap: () => _showFeedbackDetails(feedback),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            feedback['fromUserName'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: feedback['toUserType'] == 'doctor' 
                                  ? Colors.red[100] 
                                  : Colors.green[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              feedback['toUserName'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 12,
                                color: feedback['toUserType'] == 'doctor' 
                                    ? Colors.red[700] 
                                    : Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (index) => Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            size: 14,
                            color: Colors.amber,
                          )),
                          SizedBox(width: 8),
                          Text(
                            '${feedback['feedback']}'.length > 50 
                                ? '${feedback['feedback']}'.substring(0, 50) + '...'
                                : '${feedback['feedback']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPending ? Colors.orange[100] : Colors.green[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPending ? 'PENDING' : 'REVIEWED',
                              style: TextStyle(
                                fontSize: 10,
                                color: isPending ? Colors.orange[700] : Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            feedback['createdAt'] != null 
                                ? DateFormat('MMM d, h:mm a').format(
                                    (feedback['createdAt'] as Timestamp).toDate()
                                  )
                                : 'Unknown date',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.visibility, color: Colors.blue),
                  onPressed: () => _showFeedbackDetails(feedback),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingUserCard(UserData user) {
    Color backgroundColor;
    Color textColor;
    String roleText = '${user.role[0].toUpperCase()}${user.role.substring(1)}';
    
    switch (user.role) {
      case 'mentee':
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        break;
      case 'mentor':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case 'doctor':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: backgroundColor,
                child: Text(
                  (user.name.isNotEmpty ? user.name[0] : 'U').toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isNotEmpty ? user.name : 'Unknown User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$roleText - ${user.email}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Registered on ${DateFormat('MMM d, yyyy').format(user.createdAt.toDate())}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _approveUser(user.uid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: Size(80, 36),
                    ),
                    child: Text('Approve', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                  SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _disapproveUser(user.uid),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      minimumSize: Size(80, 36),
                    ),
                    child: Text('Reject', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  final appState = Provider.of<AppState>(context);
  final screenWidth = MediaQuery.of(context).size.width;

  return Scaffold(
    floatingActionButton: SpeedDial(
      icon: Icons.admin_panel_settings_outlined,
      activeIcon: Icons.close,
      backgroundColor:  Colors.blue,
      children: [
        SpeedDialChild(
          child: Icon(Icons.medical_services, color: Colors.red),
          label: 'Assign Doctor',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssignMenteeScreen(isToDoctor: true),
              ),
            );
          },
        ),
        SpeedDialChild(
          child: Icon(Icons.psychology, color: Colors.green),
          label: 'Assign Mentor',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssignMenteeScreen(isToDoctor: false),
              ),
            );
          },
        ),
        SpeedDialChild(
          child: Icon(Icons.upgrade, color: Colors.orange),
          label: 'Promote Mentee',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PromoteMenteeScreen(),
              ),
            );
          },
        ),
        SpeedDialChild(
          child: Icon(Icons.article, color: Colors.blue),
          label: 'Add Article',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddArticleScreen(),
              ),
            );
          },
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        await appState.loadAllUsersNow();
        await _loadMentors();
        await _loadFeedbacks();
        await _loadPendingUsers();
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    appState.userData?.name ?? "Admin",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[800],
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          context, 
                          'Mentees', 
                          '${appState.mentees.where((u) => u.approved).length}',
                          Icons.people,
                          Colors.blue
                        ),
                        _buildStatItem(
                          context, 
                          'Mentors', 
                          '${appState.mentors.where((u) => u.approved).length}',
                          Icons.psychology,
                          Colors.green
                        ),
                        _buildStatItem(
                          context, 
                          'Doctors', 
                          '${appState.doctors.where((u) => u.approved).length}',
                          Icons.medical_services,
                          Colors.red
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Pending approvals section - ALWAYS SHOW
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  'Pending Approvals',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_pendingUsers.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: _isLoadingPendingUsers 
                                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(Icons.refresh, size: 20),
                                onPressed: _isLoadingPendingUsers ? null : _loadPendingUsers,
                                tooltip: 'Refresh pending users',
                              ),
                              IconButton(
                                icon: Icon(
                                  _isPendingUsersExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPendingUsersExpanded = !_isPendingUsersExpanded;
                                  });
                                },
                                tooltip: _isPendingUsersExpanded ? 'Collapse' : 'Expand',
                              ),
                            ],
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Column(
                          children: [
                            if (_isPendingUsersExpanded) ...[
                              SizedBox(height: 16),
                              if (_isLoadingPendingUsers)
                                Center(child: CircularProgressIndicator())
                              else if (_pendingUsers.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 48,
                                        color: Colors.green,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'No pending approvals',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'All users have been reviewed',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ..._pendingUsers.map((user) => 
                                  _buildPendingUserCard(user)
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Points Management Section (Both Mentors and Mentees)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  'Points Management',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_mentorsList.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_menteesList.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: (_isLoadingMentors || _isLoadingMentees)
                                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(Icons.refresh, size: 20),
                                onPressed: (_isLoadingMentors || _isLoadingMentees) ? null : () {
                                  _loadMentors();
                                  _loadMentees();
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  _isMentorsExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isMentorsExpanded = !_isMentorsExpanded;
                                  });
                                },
                                tooltip: _isMentorsExpanded ? 'Collapse' : 'Expand',
                              ),
                            ],
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Column(
                          children: [
                            if (_isMentorsExpanded) ...[
                              SizedBox(height: 16),
                              // Tab Bar
                              Container(
                                margin: EdgeInsets.only(bottom: 16),
                                child: TabBar(
                                  controller: _pointsTabController,
                                  labelColor: Colors.black,
                                  unselectedLabelColor: Colors.grey,
                                  indicatorColor: Colors.blue,
                                  tabs: [
                                    Tab(
                                      icon: Icon(Icons.psychology, color: Colors.green),
                                      text: 'Mentors',
                                    ),
                                    Tab(
                                      icon: Icon(Icons.person, color: Colors.blue),
                                      text: 'Mentees',
                                    ),
                                  ],
                                ),
                              ),
                              // Tab Bar View
                              Container(
                                height: 400,
                                child: TabBarView(
                                  controller: _pointsTabController,
                                  children: [
                                    // Mentors Tab
                                    _buildMentorsTab(),
                                    // Mentees Tab
                                    _buildMenteesTab(),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Feedbacks Management Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  'User Feedbacks',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_feedbacks.where((f) => f['status'] == 'pending').length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: _isLoadingFeedbacks 
                                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(Icons.refresh, size: 20),
                                onPressed: _isLoadingFeedbacks ? null : _loadFeedbacks,
                              ),
                              IconButton(
                                icon: Icon(
                                  _isFeedbacksExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isFeedbacksExpanded = !_isFeedbacksExpanded;
                                  });
                                },
                                tooltip: _isFeedbacksExpanded ? 'Collapse' : 'Expand',
                              ),
                            ],
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Column(
                          children: [
                            if (_isFeedbacksExpanded) ...[
                              SizedBox(height: 16),
                              if (_isLoadingFeedbacks)
                                Center(child: CircularProgressIndicator())
                              else if (_feedbacks.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.feedback_outlined,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'No feedbacks yet',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  children: _feedbacks.map((feedback) => _buildFeedbackCard(feedback)).toList(),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Admin Calendar/Events
              DashboardCalendarWidget(showCreateEventButton: true),
            ],
          ),
        ),
      ),
    ),
  );
}
  Widget _buildStatItem(BuildContext context, String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAdminActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMentorCard(UserData mentor) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.green[100],
                child: mentor.photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        mentor.photoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            mentor.name[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          );
                        },
                      ),
                    )
                  : Text(
                      mentor.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mentor.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      mentor.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .where('mentorId', isEqualTo: mentor.uid)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final menteeCount = snapshot.data!.docs.length;
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people, size: 14, color: Colors.blue[700]),
                                SizedBox(width: 4),
                                Text(
                                  '$menteeCount mentees',
                                  style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, color: Colors.orange[700], size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${mentor.points ?? 0}',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _showGenericPointsDialog(mentor, true, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: Size(70, 32),
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16),
                        Text('Add', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: () => _showGenericPointsDialog(mentor, false, true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      minimumSize: Size(70, 32),
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove, size: 16),
                        Text('Sub', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mentee management methods
  Future<void> _loadMentees() async {
    setState(() {
      _isLoadingMentees = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.loadAllUsersNow();
      
      setState(() {
        _menteesList = appState.mentees.where((m) => m.approved).toList();
        _filteredMentees = List.from(_menteesList);
      });
    } catch (e) {
      print('Error loading mentees: $e');
    } finally {
      setState(() {
        _isLoadingMentees = false;
      });
    }
  }

  void _filterMentees() {
    final query = _searchMenteeController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMentees = List.from(_menteesList);
      } else {
        _filteredMentees = _menteesList.where((mentee) {
          return mentee.name.toLowerCase().contains(query) ||
                 mentee.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // Mentee card builder
  Widget _buildMenteeCard(UserData mentee) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue[100],
                child: mentee.photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        mentee.photoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            mentee.name[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          );
                        },
                      ),
                    )
                  : Text(
                      mentee.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mentee.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      mentee.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'MENTEE',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, color: Colors.orange[700], size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${mentee.points ?? 0}',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _showGenericPointsDialog(mentee, true, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: Size(70, 32),
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16),
                        Text('Add', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: () => _showGenericPointsDialog(mentee, false, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      minimumSize: Size(70, 32),
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove, size: 16),
                        Text('Sub', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build mentors tab content
  Widget _buildMentorsTab() {
    return Column(
      children: [
        if (_mentorsList.isNotEmpty)
          Container(
            margin: EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _searchMentorController,
              decoration: InputDecoration(
                hintText: 'Search mentors by name or email...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchMentorController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchMentorController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        Expanded(
          child: _isLoadingMentors
              ? Center(child: CircularProgressIndicator())
              : _mentorsList.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No mentors found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredMentors.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No mentors found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          children: _filteredMentors.map((mentor) => _buildMentorCard(mentor)).toList(),
                        ),
        ),
      ],
    );
  }

  // Build mentees tab content
  Widget _buildMenteesTab() {
    return Column(
      children: [
        if (_menteesList.isNotEmpty)
          Container(
            margin: EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _searchMenteeController,
              decoration: InputDecoration(
                hintText: 'Search mentees by name or email...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchMenteeController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchMenteeController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        Expanded(
          child: _isLoadingMentees
              ? Center(child: CircularProgressIndicator())
              : _menteesList.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No mentees found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredMentees.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No mentees found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          children: _filteredMentees.map((mentee) => _buildMenteeCard(mentee)).toList(),
                        ),
        ),
      ],
    );
  }
}