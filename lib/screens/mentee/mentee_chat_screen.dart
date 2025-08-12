// COMPLETE mentee_chat_screen.dart implementation
// Replace your current mentee_chat_screen.dart with this:

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
import '../../services/chat_service.dart';
import '../../widgets/floating_support_button.dart';
class MenteeChatScreen extends StatefulWidget {
  const MenteeChatScreen({super.key});

  @override
  _MenteeChatScreenState createState() => _MenteeChatScreenState();
}

class _MenteeChatScreenState extends State<MenteeChatScreen> {
  String _searchQuery = '';
  List<UserData> _careTeam = [];
  UserData? _assignedDoctor;
  UserData? _assignedMentor;
  bool _isLoadingCareTeam = true;
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    _loadCareTeam();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (_) => _loadCareTeam());
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadCareTeam() async {
    setState(() {
      _isLoadingCareTeam = true;
    });
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.user == null) return;
      
      // Get current user's data to find assigned doctor and mentor
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(appState.user!.uid)
          .get();
      
      if (!userDoc.exists) {
        setState(() {
          _isLoadingCareTeam = false;
        });
        return;
      }
      
      final userData = UserData.fromMap(userDoc.data() as Map<String, dynamic>);
      List<UserData> careTeamMembers = [];
      
      // Load assigned doctor
      if (userData.doctorId != null && userData.doctorId!.isNotEmpty) {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userData.doctorId)
            .get();
        
        if (doctorDoc.exists) {
          final doctorData = UserData.fromMap(doctorDoc.data() as Map<String, dynamic>);
          setState(() {
            _assignedDoctor = doctorData;
          });
          careTeamMembers.add(doctorData);
        }
      } else {
        setState(() {
          _assignedDoctor = null;
        });
      }
      
      // Load assigned mentor
      if (userData.mentorId != null && userData.mentorId!.isNotEmpty) {
        final mentorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userData.mentorId)
            .get();
        
        if (mentorDoc.exists) {
          final mentorData = UserData.fromMap(mentorDoc.data() as Map<String, dynamic>);
          setState(() {
            _assignedMentor = mentorData;
          });
          careTeamMembers.add(mentorData);
        }
      } else {
        setState(() {
          _assignedMentor = null;
        });
      }
      
      setState(() {
        _careTeam = careTeamMembers;
      });
      
    } catch (e) {
      print('Error loading care team: $e');
    } finally {
      setState(() {
        _isLoadingCareTeam = false;
      });
    }
  }
  
  List<UserData> get _filteredCareTeam {
    if (_searchQuery.isEmpty) return _careTeam;
    
    return _careTeam.where((user) => 
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
    ).then((_) => _loadCareTeam()); // Refresh when returning from chat
  }
  
  void _onUserLongPress(UserData user) {
    final isDoctor = user.role == 'doctor';
    
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
                  backgroundColor: isDoctor ? Colors.blue[100] : Colors.green[100],
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
                        isDoctor ? Icons.medical_services : Icons.psychology,
                        color: isDoctor ? Colors.blue[800] : Colors.green[800],
                        size: 30,
                      ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDoctor ? 'Dr. ${user.name}' : user.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Your ${isDoctor ? 'Doctor' : 'Mentor'}',
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
            
            // Action buttons
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
              leading: Icon(Icons.video_call, color: Colors.purple),
              title: Text('Video Call'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Video calling feature coming soon')),
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
            
            if (isDoctor)
              ListTile(
                leading: Icon(Icons.schedule, color: Colors.teal),
                title: Text('Schedule Appointment'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Appointment scheduling coming soon')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 24),
          Text(
            'No care team assigned yet',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Your doctor and mentor will be assigned soon.\nYou\'ll be notified when they\'re available.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadCareTeam,
            icon: Icon(Icons.refresh),
            label: Text('Check Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCareTeamInfo() {
    final careTeamCount = _careTeam.length;
    final hasDoctor = _assignedDoctor != null;
    final hasMentor = _assignedMentor != null;
    
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[50]!, Colors.green[50]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital, color: Colors.blue[700], size: 24),
              SizedBox(width: 8),
              Text(
                'My Care Team',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: careTeamCount > 0 ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  careTeamCount > 0 ? '$careTeamCount Active' : 'Pending',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  title: 'Doctor',
                  isAssigned: hasDoctor,
                  name: hasDoctor ? 'Dr. ${_assignedDoctor!.name}' : null,
                  icon: Icons.medical_services,
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatusCard(
                  title: 'Mentor',
                  isAssigned: hasMentor,
                  name: hasMentor ? _assignedMentor!.name : null,
                  icon: Icons.psychology,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusCard({
    required String title,
    required bool isAssigned,
    String? name,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAssigned ? color[200]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isAssigned ? color[600] : Colors.grey[400],
            size: 24,
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 4),
          Text(
            isAssigned ? 'Assigned' : 'Pending',
            style: TextStyle(
              fontSize: 10,
              color: isAssigned ? color[600] : Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isAssigned && name != null) ...[
            SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
      onRefresh: _loadCareTeam,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        hintText: 'Search in care team...',
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
            
            SizedBox(height: 20),
            
            // Care team info card
            _buildCareTeamInfo(),
            Align(
  alignment: Alignment.centerRight,
  child: FloatingSupportButton(),
),
            // Chat list
            Expanded(
              child: _isLoadingCareTeam
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading your care team...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _careTeam.isEmpty
                  ? _buildEmptyState()
                  : ChatListWidget(
                      users: _filteredCareTeam,
                      currentUserId: Provider.of<AppState>(context).user?.uid ?? '',
                      userType: 'care_team', // Special type for mentee's care team
                      onUserTap: _onUserTap,
                      onUserLongPress: _onUserLongPress,
                      showLastMessage: true,
                      showUnreadCount: false, // ← RED BADGES DISABLED
                      refreshable: false, // We handle refresh at parent level
                    ),
            ),
          ],
        ),
      ),
      ),
  
    );
  }
}