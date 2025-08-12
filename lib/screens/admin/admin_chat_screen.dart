import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../models/user_data.dart';
import '../../Providers/app_state.dart';
import '../common/chatScreen.dart';
import '../common/chat_list_widget.dart';
import 'assigning_screen.dart';
import 'promote_mentee_screen.dart';
import '../common/settings_screen.dart';

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  _AdminChatScreenState createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  String _searchQuery = '';
  String _selectedUserType = 'all'; // all, mentee, mentor, doctor
  List<UserData> _allUsers = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    _loadAllUsers();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (_) => _loadAllUsers());
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadAllUsers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      
      // Get all users except the current admin
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['mentee', 'mentor', 'doctor'])
          .get();
      
      final users = querySnapshot.docs
          .map((doc) => UserData.fromMap(doc.data()))
          .where((user) => user.uid != appState.user?.uid) // Exclude current admin
          .toList();
      
      setState(() {
        _allUsers = users;
      });
    } catch (e) {
      print('Error loading users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  List<UserData> get _filteredUsers {
    List<UserData> users = _allUsers;
    
    // Filter by user type
    if (_selectedUserType != 'all') {
      users = users.where((user) => user.role == _selectedUserType).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      users = users.where((user) => 
        user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        user.email.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return users;
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
    ).then((_) => _loadAllUsers()); // Refresh when returning from chat
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
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getUserTypeColor(user).withOpacity(0.1),
                  radius: 25,
                  child: user.photoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Image.network(
                          user.photoUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        _getUserIcon(user),
                        color: _getUserTypeColor(user),
                        size: 30,
                      ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.role == 'doctor' ? 'Dr. ${user.name}' : user.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        user.role.toUpperCase(),
                        style: TextStyle(
                          color: _getUserTypeColor(user),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Action buttons
            ListTile(
              leading: Icon(Icons.chat, color: Colors.blue),
              title: Text('Send Message'),
              onTap: () {
                Navigator.pop(context);
                _onUserTap(user);
              },
            ),
            
            if (user.role == 'mentee') ...[
              ListTile(
                leading: Icon(Icons.person_add, color: Colors.green),
                title: Text('Assign to Doctor'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignMenteeScreen(isToDoctor: true),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.psychology, color: Colors.purple),
                title: Text('Assign to Mentor'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignMenteeScreen(isToDoctor: false),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.upgrade, color: Colors.orange),
                title: Text('Promote to Mentor'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PromoteMenteeScreen(),
                    ),
                  );
                },
              ),
            ],
            
            ListTile(
              leading: Icon(Icons.info, color: Colors.grey),
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
  
  Color _getUserTypeColor(UserData user) {
    switch (user.role) {
      case 'doctor':
        return Colors.blue;
      case 'mentor':
        return Colors.green;
      case 'mentee':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getUserIcon(UserData user) {
    switch (user.role) {
      case 'doctor':
        return Icons.medical_services;
      case 'mentor':
        return Icons.psychology;
      case 'mentee':
        return Icons.person;
      default:
        return Icons.person;
    }
  }
  
  String _getUserTypeLabel(UserData user) {
    switch (user.role) {
      case 'doctor':
        return 'Doctor';
      case 'mentor':
        return 'Mentor';
      case 'mentee':
        return 'Mentee';
      default:
        return 'User';
    }
  }
  
  Widget _buildUserTypeSelector() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _buildTypeButton('all', 'All (${_allUsers.length})', Colors.grey),
          _buildTypeButton('mentee', 'Mentees (${_allUsers.where((u) => u.role == 'mentee').length})', Colors.orange),
          _buildTypeButton('mentor', 'Mentors (${_allUsers.where((u) => u.role == 'mentor').length})', Colors.green),
          _buildTypeButton('doctor', 'Doctors (${_allUsers.where((u) => u.role == 'doctor').length})', Colors.blue),
        ],
      ),
    );
  }
  
  Widget _buildTypeButton(String type, String label, MaterialColor color) {
    final isSelected = _selectedUserType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedUserType = type;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : color[800],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAdminActions() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.blue[700]),
              SizedBox(width: 8),
              Text(
                'Admin Actions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickAction(
                  'Assign Mentee',
                  Icons.person_add,
                  Colors.green,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AssignMenteeScreen(isToDoctor: true),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildQuickAction(
                  'Promote User',
                  Icons.upgrade,
                  Colors.orange,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PromoteMenteeScreen(),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildQuickAction(
                  'Settings',
                  Icons.settings,
                  Colors.grey,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickAction(String label, IconData icon, MaterialColor color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color[700], size: 20),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return RefreshIndicator(
      onRefresh: _loadAllUsers,
      child: Padding(
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
                        hintText: 'Search users...',
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
            
            // Admin actions
            _buildAdminActions(),
            
            // User type selector
            _buildUserTypeSelector(),
            
            SizedBox(height: 16),
            
            // Chat list
            Expanded(
              child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading users...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty 
                                ? 'No users found for "$_searchQuery"'
                                : 'No users available',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ChatListWidget(
                      users: _filteredUsers,
                      currentUserId: appState.user?.uid ?? '',
                      userType: 'admin', // Special type for admin
                      onUserTap: _onUserTap,
                      onUserLongPress: _onUserLongPress,
                      showLastMessage: true,
                      showUnreadCount: false, // No red badges as requested
                      refreshable: false, // We handle refresh at parent level
                    ),
            ),
          ],
        ),
      ),
    );
  }
}