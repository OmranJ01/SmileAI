import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../models/messages.dart';
import '../../models/user_data.dart';
import '../../Providers/app_state.dart';
import '../../screens/admin/assigning_screen.dart';
import '../common/chatScreen.dart';
import '../common/chat_list_widget.dart';
import '../../widgets/floating_support_button.dart';

class DoctorChatScreen extends StatefulWidget {
  const DoctorChatScreen({super.key});

  @override
  _DoctorChatScreenState createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  String _searchQuery = '';
  bool _chatbotEnabled = false;
  List<UserData> _myMentees = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (_) => _loadData());
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
          // Load chatbot toggle status for this doctor
    if (appState.user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(appState.user!.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _chatbotEnabled = doc.data()?['chatbotEnabled'] == true;
        });
      }
    }

      // Load all users assigned to this doctor (both mentees and those who became mentors)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('doctorId', isEqualTo: appState.user?.uid)
          .get();
      
      final mentees = querySnapshot.docs.map((doc) {
        return UserData.fromMap(doc.data());
      }).toList();
      
      setState(() {
        _myMentees = mentees;
      });
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  List<UserData> get _filteredUsers {
    if (_searchQuery.isEmpty) return _myMentees;
    
    return _myMentees.where((user) => 
      user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      user.email.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }
  
  void _onUserTap(UserData user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          recipientId: user.uid,
          recipientName: user.name,
        ),
      ),
    ).then((_) => _loadData()); // Refresh when returning
  }
  
  void _onUserLongPress(UserData user) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.chat, color: Colors.blue),
              title: Text('Open Chat'),
              onTap: () {
                Navigator.pop(context);
                _onUserTap(user);
              },
            ),
            if (user.role == 'mentee')
              ListTile(
                leading: Icon(Icons.person_add, color: Colors.green),
                title: Text('Assign to Mentor'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignMentorScreen(mentee: user),
                    ),
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.assignment, color: Colors.purple),
              title: Text('Assign Task'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Task assignment feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.info, color: Colors.orange),
              title: Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Profile view coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Scaffold(
    body:Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search mentees...',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          
          // Replace your SizedBox(height: 16), Row(...), and Container(...)
// with this single Container:

Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.blue[50],
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Chatbot toggle row
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Chatbot',
          style: TextStyle(
    fontSize: 14,
    color: Colors.blue[600],
  )),
          Switch(
            value: _chatbotEnabled,
            onChanged: (val) async{
              setState(() {
                _chatbotEnabled = val;
              });
              // Optionally, save this state to Firestore or Provider if you want persistence
               final appState = Provider.of<AppState>(context, listen: false);
  if (appState.user != null) {
    await FirebaseFirestore.instance
      .collection('users')
      .doc(appState.user!.uid)
      .update({'chatbotEnabled': val});
  }
            },
            activeColor: Colors.blue[700],
          ),
        ],
      ),
      // Header row
      Row(
        children: [
          Icon(Icons.people, color: Colors.blue[700], size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
               Text(
  _chatbotEnabled
      ? 'Chatbot will answer your mentees now'
      : 'Chat with your assigned mentees',
  style: TextStyle(
    fontSize: 14,
    color: Colors.blue[600],
  ),
),
              ],
            ),
          ),
        ],
      ),
    ],
  ),
),
Padding(
  padding: const EdgeInsets.only(bottom: 8.0),
  child: Text(
    'Mentees: ${_myMentees.length}',
    style: TextStyle(
      color: Colors.blue[700],
      fontWeight: FontWeight.w500,
      fontSize: 13,
    ),
  ),
),
          Align(
  alignment: Alignment.centerRight,
  child: FloatingSupportButton(),
),
          SizedBox(height: 16),
          
          // Chat list
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _myMentees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No mentees assigned yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Wait for admin to assign mentees to you',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ChatListWidget(
                      users: _filteredUsers,
                      currentUserId: appState.user?.uid ?? '',
                      userType: 'mentee',
                      onUserTap: _onUserTap,
                      onUserLongPress: _onUserLongPress,
                      showLastMessage: true,
                      showUnreadCount: true,
                      refreshable: true,
                    ),
          ),
        ],
      ),
    ),
      

    )
    ;
  }
}