import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../Providers/app_state.dart';
import '../../models/user_data.dart';

class MenteeFeedbackScreen extends StatefulWidget {
  const MenteeFeedbackScreen({super.key});

  @override
  _MenteeFeedbackScreenState createState() => _MenteeFeedbackScreenState();
}

class _MenteeFeedbackScreenState extends State<MenteeFeedbackScreen> {
  final _feedbackController = TextEditingController();
  String? _selectedUserId;
  String? _selectedUserType;
  int _rating = 5;
  bool _isSubmitting = false;
  List<UserData> _availableUsers = [];

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
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.userData == null) return;

    List<UserData> users = [];

    // Load assigned doctor
    if (appState.userData!.doctorId != null) {
      try {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(appState.userData!.doctorId)
            .get();
        
        if (doctorDoc.exists) {
          final doctor = UserData.fromMap(doctorDoc.data()!);
          users.add(doctor);
        }
      } catch (e) {
        print('Error loading doctor: $e');
      }
    }

    // Load assigned mentor
    if (appState.userData!.mentorId != null) {
      try {
        final mentorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(appState.userData!.mentorId)
            .get();
        
        if (mentorDoc.exists) {
          final mentor = UserData.fromMap(mentorDoc.data()!);
          users.add(mentor);
        }
      } catch (e) {
        print('Error loading mentor: $e');
      }
    }

    setState(() {
      _availableUsers = users;
      if (users.isNotEmpty) {
        _selectedUserId = users.first.uid;
        _selectedUserType = users.first.role;
      }
    });
  }

  Future<void> _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty || _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a user and enter feedback')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      
      // Submit feedback to Firestore
      await FirebaseFirestore.instance.collection('feedbacks').add({
        'fromUserId': appState.user!.uid,
        'fromUserName': appState.userData?.name ?? 'Unknown',
        'toUserId': _selectedUserId,
        'toUserType': _selectedUserType,
        'feedback': _feedbackController.text.trim(),
        'rating': _rating,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewed
      });

      // Send notification to admin
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      
      for (final adminDoc in adminQuery.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': adminDoc.id,
          'title': 'New Feedback Received',
          'message': '${appState.userData?.name} submitted feedback about a $_selectedUserType',
          'type': 'feedback',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'data': {
            'fromUserId': appState.user!.uid,
            'toUserId': _selectedUserId,
            'rating': _rating,
          },
        });
      }

      _feedbackController.clear();
      setState(() {
        _rating = 5;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error submitting feedback: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Submit Feedback'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _availableUsers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.feedback_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No doctor or mentor assigned yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select who to give feedback about:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          ..._availableUsers.map((user) => RadioListTile<String>(
                            title: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: user.role == 'doctor' 
                                      ? Colors.red[100] 
                                      : Colors.green[100],
                                  child: Text(
                                    user.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: user.role == 'doctor' 
                                          ? Colors.red[800] 
                                          : Colors.green[800],
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
                                        user.name,
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        user.role == 'doctor' ? 'Doctor' : 'Mentor',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            value: user.uid,
                            groupValue: _selectedUserId,
                            onChanged: (value) {
                              setState(() {
                                _selectedUserId = value;
                                _selectedUserType = user.role;
                              });
                            },
                          )).toList(),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate your experience:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                icon: Icon(
                                  index < _rating ? Icons.star : Icons.star_border,
                                  size: 36,
                                  color: Colors.amber,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _rating = index + 1;
                                  });
                                },
                              );
                            }),
                          ),
                          Center(
                            child: Text(
                              _rating == 5 ? 'Excellent' :
                              _rating == 4 ? 'Good' :
                              _rating == 3 ? 'Average' :
                              _rating == 2 ? 'Poor' : 'Very Poor',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _rating >= 4 ? Colors.green : 
                                       _rating >= 3 ? Colors.orange : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your feedback:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: _feedbackController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Share your experience...',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Your feedback will be sent to the admin for review',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Submitting...'),
                              ],
                            )
                          : Text(
                              'Submit Feedback',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}