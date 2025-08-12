import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../screens/common/settings_screen.dart';
import '../../Providers/app_state.dart';
import '../../screens/mentee/brushing_timer_screen.dart';
import 'mentee_tasks_screen.dart';
import '../../widgets/dashboard-calendar-widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_data.dart';

class MenteeDashboardScreen extends StatelessWidget {
  const MenteeDashboardScreen({super.key});

  // Show feedback dialog
  void _showFeedbackDialog(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => FeedbackDialog(),
    );
  }

  // Helper method to calculate progress width
  double _calculateProgressWidth(BuildContext context, int points) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.4;
    final progressInLevel = points % 100;
    return maxWidth * (progressInLevel / 100);
  }

  // Helper method to get points to next level
  int _getPointsToNextLevel(int points) {
    return 100 - (points % 100);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Clean like mentor dashboard
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      appState.userData?.name ?? "User",
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // Points Section - NEW
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Text(
                      '${appState.points}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Learning Points', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Complete tasks and activities to earn more points', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                        SizedBox(height: 12),
                        Container(
                          height: 8,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            children: [
                              Container(
                                width: _calculateProgressWidth(context, appState.points),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${appState.points} pts', style: TextStyle(color: Colors.white, fontSize: 12)),
                            Text('${_getPointsToNextLevel(appState.points)} pts to next level', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            // Brush Buddy Card
            Card(
              color: Colors.blue[50],
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BrushingTimerScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.brush,
                        size: 48,
                        color: Colors.blue[700],
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Brush Buddy',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            Text(
                              'Start your 2-minute brushing timer with technique guidance',
                              style: TextStyle(
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.blue[700],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Tasks & Medications Card
            Card(
              color: Colors.green[50],
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MenteeTasksScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.assignment,
                        size: 48,
                        color: Colors.green[700],
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Tasks & Medications',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            Text(
                              'View tasks from your doctor and manage medication reminders',
                              style: TextStyle(
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.green[700],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // UPDATED: Feedback Card
            Card(
              color: Colors.orange[50],
              child: InkWell(
                onTap: () => _showFeedbackDialog(context),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.feedback,
                        size: 48,
                        color: Colors.orange[700],
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send Feedback',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                            Text(
                              'Rate your doctor or mentor\'s performance',
                              style: TextStyle(
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.orange[700],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            
            // Events section
            Row(
              children: [
                Icon(Icons.event),
                SizedBox(width: 8),
                Text(
                  'Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            DashboardCalendarWidget(showCreateEventButton: false),
          ],
        ),
      ),
    );
  }
}

// UPDATED: Simplified Feedback Dialog - all admins receive the feedback
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  @override
  _FeedbackDialogState createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  UserData? _selectedSubject; // Who the feedback is ABOUT (doctor/mentor)
  List<UserData> _availableSubjects = []; // Doctor/Mentor assigned to mentee
  int _rating = 0;
  final _feedbackController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUsers() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final userData = appState.userData;
      
      if (userData == null) {
        setState(() {
          _errorMessage = 'User data not found';
          _isLoading = false;
        });
        return;
      }

      List<UserData> subjects = [];

      // Load assigned doctor
      if (userData.doctorId != null && userData.doctorId!.isNotEmpty) {
        try {
          final doctorDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userData.doctorId)
              .get();
          
          if (doctorDoc.exists && doctorDoc.data() != null) {
            final doctorData = UserData.fromMap(doctorDoc.data()!);
            subjects.add(doctorData);
          }
        } catch (e) {
          // Silently handle error
        }
      }

      // Load assigned mentor
      if (userData.mentorId != null && userData.mentorId!.isNotEmpty) {
        try {
          final mentorDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userData.mentorId)
              .get();
          
          if (mentorDoc.exists && mentorDoc.data() != null) {
            final mentorData = UserData.fromMap(mentorDoc.data()!);
            subjects.add(mentorData);
          }
        } catch (e) {
          // Silently handle error
        }
      }

      setState(() {
        _availableSubjects = subjects;
        _isLoading = false;
        
        if (subjects.isEmpty) {
          _errorMessage = 'No doctor or mentor assigned yet';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitFeedback() async {
    // Validation
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select who you want to give feedback about')),
      );
      return;
    }

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide a rating')),
      );
      return;
    }

    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide feedback text')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      
      // Create feedback document
      await FirebaseFirestore.instance.collection('feedbacks').add({
        'fromUserId': appState.user!.uid,
        'fromUserName': appState.userData?.name ?? 'Unknown',
        'subjectUserId': _selectedSubject!.uid,       // Doctor/mentor being reviewed
        'subjectUserName': _selectedSubject!.name,    // Doctor/mentor name
        'subjectUserRole': _selectedSubject!.role,    // 'doctor' or 'mentor'
        'rating': _rating,
        'feedback': _feedbackController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Send notification to ALL admins
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('approved', isEqualTo: true)
          .get();

      // Create notifications for all admins
      for (final adminDoc in adminQuery.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': adminDoc.id,
          'title': 'New Feedback Received',
          'message': '${appState.userData?.name ?? 'A mentee'} sent feedback about ${_selectedSubject!.name} (${_selectedSubject!.role})',
          'type': 'feedback',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'data': {
            'fromUserId': appState.user!.uid,
            'subjectUserId': _selectedSubject!.uid,
            'subjectUserName': _selectedSubject!.name,
            'subjectUserRole': _selectedSubject!.role,
            'rating': _rating,
          },
        });
      }

      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback about ${_selectedSubject!.name} sent to all admins successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting feedback'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.feedback, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Send Feedback',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Loading state
                    if (_isLoading) ...[
                      SizedBox(height: 40),
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading available users...'),
                      SizedBox(height: 40),
                    ]
                    
                    // Error state
                    else if (_errorMessage.isNotEmpty) ...[
                      SizedBox(height: 20),
                      Icon(
                        Icons.info_outline, 
                        size: 48, 
                        color: Colors.orange,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = '';
                          });
                          _loadAvailableUsers();
                        },
                        icon: Icon(Icons.refresh),
                        label: Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      SizedBox(height: 20),
                    ]
                    
                    // Main content
                    else ...[
                      // Info card about where feedback goes
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700], size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your feedback will be reviewed by all administrators',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Dropdown: Select doctor/mentor to give feedback about
                      DropdownButtonFormField<UserData>(
                        decoration: InputDecoration(
                          labelText: 'About (Doctor/Mentor)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        value: _selectedSubject,
                        items: _availableSubjects.map((user) {
                          return DropdownMenuItem(
                            value: user,
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: user.role == 'doctor' 
                                        ? Colors.red[100] 
                                        : Colors.green[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      user.role == 'doctor' 
                                          ? Icons.medical_services 
                                          : Icons.psychology,
                                      color: user.role == 'doctor' 
                                          ? Colors.red[700] 
                                          : Colors.green[700],
                                      size: 18,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      user.name,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      user.role == 'doctor' ? 'Doctor' : 'Mentor',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSubject = value;
                          });
                        },
                      ),
                      SizedBox(height: 20),
                      
                      // Show feedback title if subject is selected
                      if (_selectedSubject != null) ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selectedSubject!.role == 'doctor' 
                                ? Colors.red[50] 
                                : Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedSubject!.role == 'doctor' 
                                  ? Colors.red[200]! 
                                  : Colors.green[200]!,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _selectedSubject!.role == 'doctor' 
                                    ? Icons.medical_services 
                                    : Icons.psychology,
                                color: _selectedSubject!.role == 'doctor' 
                                    ? Colors.red[700] 
                                    : Colors.green[700],
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Feedback about',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _selectedSubject!.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedSubject!.role == 'doctor' 
                                      ? Colors.red[800] 
                                      : Colors.green[800],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                _selectedSubject!.role == 'doctor' ? 'Doctor' : 'Mentor',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      // Rating section
                      Text(
                        'Rate your experience',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                            onPressed: () {
                              setState(() {
                                _rating = index + 1;
                              });
                            },
                          );
                        }),
                      ),
                      if (_rating > 0)
                        Text(
                          _rating == 5 ? 'Excellent' :
                          _rating == 4 ? 'Good' :
                          _rating == 3 ? 'Average' :
                          _rating == 2 ? 'Poor' : 'Very Poor',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _rating >= 4 ? Colors.green : 
                                   _rating >= 3 ? Colors.orange : Colors.red,
                          ),
                        ),
                      SizedBox(height: 20),
                      
                      // Feedback text
                      TextField(
                        controller: _feedbackController,
                        decoration: InputDecoration(
                          labelText: _selectedSubject != null 
                              ? 'Your feedback about ${_selectedSubject!.name}'
                              : 'Your Feedback',
                          hintText: 'Share your experience...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  if (!_isLoading && _errorMessage.isEmpty)
                    ElevatedButton(
                      onPressed: _isSubmitting || _availableSubjects.isEmpty
                          ? null 
                          : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            ) 
                            
                          : Text('Submit Feedback'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}