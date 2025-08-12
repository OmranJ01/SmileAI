import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../models/messages.dart';
import '../../models/user_data.dart';
import '../../Providers/app_state.dart';
import '../../screens/common/chatScreen.dart';
import '../common/chat_list_widget.dart';
import '../../widgets/floating_support_button.dart';


class MentorChatScreen extends StatefulWidget {
  const MentorChatScreen({super.key});

  @override
  _MentorChatScreenState createState() => _MentorChatScreenState();
}

class _MentorChatScreenState extends State<MentorChatScreen> {
  String _searchQuery = '';
  String _selectedTab = 'mentees'; // 'mentees', 'mentors', or 'doctors'
  List<UserData> _myMentees = [];
  List<UserData> _mentors = []; // Will contain only their assigned mentor if exists
  List<UserData> _doctors = []; // Will contain only their assigned doctor if exists
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    _loadData();
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
      
      // Load mentees assigned to this mentor
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('mentorId', isEqualTo: appState.user?.uid)
          .get();
      
      final mentees = querySnapshot.docs.map((doc) {
        return UserData.fromMap(doc.data());
      }).toList();
      
      // Load my mentor if I have one (for mentors who were promoted from mentees)
      List<UserData> myMentorList = [];
      if (appState.userData?.mentorId != null) {
        final mentorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(appState.userData!.mentorId!)
            .get();
        
        if (mentorDoc.exists) {
          myMentorList.add(UserData.fromMap(mentorDoc.data() as Map<String, dynamic>));
        }
      }
      
      // Load my doctor if I have one (for mentors who were promoted from mentees)
      List<UserData> myDoctorList = [];
      if (appState.userData?.doctorId != null) {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(appState.userData!.doctorId!)
            .get();
        
        if (doctorDoc.exists) {
          myDoctorList.add(UserData.fromMap(doctorDoc.data() as Map<String, dynamic>));
        }
      }
      
      setState(() {
        _myMentees = mentees;
        _mentors = myMentorList;
        _doctors = myDoctorList;
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
    List<UserData> users;
    
    switch (_selectedTab) {
      case 'mentees':
        users = _myMentees;
        break;
      case 'mentors':
        users = _mentors;
        break;
      case 'doctors':
        users = _doctors;
        break;
      default:
        users = [];
    }
    
    if (_searchQuery.isEmpty) return users;
    
    return users.where((user) => 
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
    ).then((_) => _loadData());
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
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: Text(user.name[0].toUpperCase()),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTab == 'doctors' ? 'Dr. ${user.name}' : user.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _selectedTab == 'mentees' ? 'Mentee' : 
                        _selectedTab == 'mentors' ? 'My Mentor' : 'My Doctor',
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
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.chat, color: Colors.blue),
              title: Text('Send Message'),
              onTap: () {
                Navigator.pop(context);
                _onUserTap(user);
              },
            ),
            ListTile(
              leading: Icon(Icons.call, color: Colors.green),
              title: Text('Call'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Calling feature coming soon')),
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
                      hintText: 'Search names...',
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
          
          // Three-tab selector
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                // Mentees tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTab = 'mentees';
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'mentees' ? Colors.blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Mentees (${_myMentees.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 'mentees' ? Colors.white : Colors.grey[800],
                          fontWeight: _selectedTab == 'mentees' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4),
                
                // Mentors tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTab = 'mentors';
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'mentors' ? Colors.purple : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Mentors (${_mentors.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 'mentors' ? Colors.white : Colors.grey[800],
                          fontWeight: _selectedTab == 'mentors' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4),
                
                // Doctors tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTab = 'doctors';
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 'doctors' ? Colors.green : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Doctors (${_doctors.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 'doctors' ? Colors.white : Colors.grey[800],
                          fontWeight: _selectedTab == 'doctors' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
              : _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedTab == 'mentees' ? Icons.people_outline : 
                          _selectedTab == 'mentors' ? Icons.person_outline : 
                          Icons.medical_services_outlined, 
                          size: 64, 
                          color: Colors.grey
                        ),
                        SizedBox(height: 16),
                        Text(
                          _selectedTab == 'mentees' ? 'No mentees assigned yet' : 
                          _selectedTab == 'mentors' ? 'No mentor assigned' : 
                          'No doctor assigned',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        if (_selectedTab == 'mentees')
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'The admin will assign mentees to you',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ),
                      ],
                    ),
                  )
                : ChatListWidget(
                    users: _filteredUsers,
                    currentUserId: appState.user?.uid ?? '',
                    userType: _selectedTab == 'mentees' ? 'mentee' : 
                              _selectedTab == 'mentors' ? 'mentor' : 'doctor',
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
      

    );
  }
}