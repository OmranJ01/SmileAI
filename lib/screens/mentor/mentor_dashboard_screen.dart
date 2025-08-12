import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Providers/app_state.dart';
import '../common/settings_screen.dart';
import '../mentor/mentor_chat_screen.dart';
import '../common/chatScreen.dart';
import '../mentee/mentee_tasks_screen.dart'; // Use the same tasks screen as mentees
import '../../models/user_data.dart';
import '../../widgets/expandable_action_card.dart';
import '../../widgets/dashboard-calendar-widget.dart';



class MentorDashboardScreen extends StatefulWidget {
  const MentorDashboardScreen({super.key});

  @override
  _MentorDashboardScreenState createState() => _MentorDashboardScreenState();
}

class _MentorDashboardScreenState extends State<MentorDashboardScreen> {
  bool _isDataLoaded = false;
  bool _isRefreshing = false;
  List<UserData> _assignedMentees = [];
  List<UserData> _filteredMentees = [];
  bool _isLoadingMentees = true;
  bool _isMenteesExpanded = false;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterMentees);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDataLoaded) {
        _loadMentorData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMentees() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _filteredMentees = _assignedMentees;
      } else {
        _filteredMentees = _assignedMentees.where((mentee) {
          return mentee.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                 mentee.email.toLowerCase().contains(_searchController.text.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _loadMentorData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.fetchMentorStats(appState.user?.uid);
      await appState.fetchMentees();
      await appState.fetchNotifications();
      await appState.fetchMentorEvents(appState.user?.uid);
      
      // Load mentor's assigned mentees
      await _loadAssignedMentees();
      
      setState(() {
        _isDataLoaded = true;
      });
    } catch (e) {
      print('Error loading mentor data: $e');
    } finally {
      
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadAssignedMentees() async {
    setState(() {
      _isLoadingMentees = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.user == null) return;

      // Query users assigned to this mentor
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('mentorId', isEqualTo: appState.user!.uid)
          .get();

      final assignedMentees = querySnapshot.docs.map((doc) {
        return UserData.fromMap(doc.data());
      }).toList();
if (!mounted) return;
      setState(() {
        _assignedMentees = assignedMentees;
        _filteredMentees = assignedMentees;
      });
    } catch (e) {
      print('Error loading assigned mentees: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingMentees = false;
      });
    }
  }

  Future<void> _forceRefreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
      _isDataLoaded = false;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.forceRefreshMentorData();
      await _loadAssignedMentees();
      
      setState(() {
        _isDataLoaded = true;
      });
    } catch (e) {
      print('Error refreshing mentor data: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when coming back to this screen
    if (_isDataLoaded) {
      _loadMentorData();
    }
  }

  String _getLastActivityText(DateTime? lastActivity) {
    if (lastActivity == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(lastActivity);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  // Show feedback dialog
  void _showFeedbackDialog(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => MentorFeedbackDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    if (!_isDataLoaded && _isRefreshing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading mentor dashboard...'),
          ],
        ),
      );
    }
    
    final myMentees = appState.mentees.where((m) => m.mentorId == appState.user?.uid).toList();
    final totalMessages = appState.mentorStats?.totalMessages ?? 0;
    final totalSessions = appState.mentorStats?.totalSessions ?? 0;
    final averageRating = appState.mentorStats?.averageRating ?? 0.0;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadMentorData();
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                        appState.userData?.name ?? "Mentor",
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.settings),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));
                    },
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              // Points Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[700]!, Colors.green[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Text(
                        '${appState.points}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[700]),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mentorship Points', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Keep helping mentees to earn more points', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
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

              // Tasks & Medications Section (Same as mentee)
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

              // ADDED: Feedback Card (same as mentee)
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
                                'Rate your doctor or fellow mentors',
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
              
              // My Assigned Mentees Section (Updated with collapsible functionality)
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
                      // Header with expand/collapse button
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isMenteesExpanded = !_isMenteesExpanded;
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Assigned Mentees',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_assignedMentees.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                IconButton(
                                  icon: _isRefreshing 
                                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Icon(Icons.refresh, size: 20),
                                  onPressed: _isRefreshing ? null : _forceRefreshData,
                                ),
                                Icon(
                                  _isMenteesExpanded ? Icons.expand_less : Icons.expand_more,
                                  size: 24,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Expandable content
                      if (_isMenteesExpanded) ...[
                        SizedBox(height: 16),
                        
                        // Search bar (only show if there are mentees)
                        if (_assignedMentees.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search mentees...',
                                prefixIcon: Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.green),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        
                        // Mentees list
                        if (_isLoadingMentees)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_assignedMentees.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No mentees assigned yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Wait for doctor to assign mentees to you',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_filteredMentees.isEmpty)
                          Container(
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
                                SizedBox(height: 4),
                                Text(
                                  'Try adjusting your search terms',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: _filteredMentees.map((mentee) => _buildMenteeCard(mentee)).toList(),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              DashboardCalendarWidget(showCreateEventButton: false),
      
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods (keeping all existing ones)
  double _calculateProgressWidth(BuildContext context, int points) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.4;
    final progressInLevel = points % 100;
    return maxWidth * (progressInLevel / 100);
  }

  int _getPointsToNextLevel(int points) {
    return 100 - (points % 100);
  }

  List<Widget> _buildCalendarDays() {
    final now = DateTime.now();
    final today = now.day;
    final daysInWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    
    return List.generate(7, (index) {
      final date = startOfWeek.add(Duration(days: index));
      final isToday = date.day == today && date.month == now.month && date.year == now.year;
      
      return Column(
        children: [
          Text(daysInWeek[index], style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
          SizedBox(height: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: isToday ? Colors.green : Colors.transparent, shape: BoxShape.circle),
            child: Center(
              child: Text('${date.day}', style: TextStyle(color: isToday ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    });
  }

  Color _getEventColor(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'meeting': return Colors.blue;
      case 'session': return Colors.green;
      case 'training': return Colors.purple;
      default: return Colors.orange;
    }
  }

  // Dialog methods
  void _showAllEvents(BuildContext context, List<dynamic> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('All Events (${events.length})'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: events.isEmpty
            ? Center(child: Text('No upcoming events'))
            : ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return ListTile(
                    leading: Icon(_getEventIcon(event.type)),
                    title: Text(event.title),
                    subtitle: Text(DateFormat('MMM dd, yyyy - h:mm a').format(event.dateTime)),
                  );
                },
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'meeting': return Icons.meeting_room;
      case 'session': return Icons.video_call;
      case 'training': return Icons.school;
      default: return Icons.event;
    }
  }

  Widget _buildTaskItem(String title, String time, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(Icons.event, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenteeCard(UserData mentee) {
    // Build the title widget with avatar and name
    final titleWidget = Row(
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
              SizedBox(height: 2),
              Text(
                mentee.email,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // Build action buttons - only chat option
    List<ActionButton> actions = [
      ActionButton(
        label: 'Chat',
        icon: Icons.chat,
        onPressed: () {
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                recipientId: mentee.uid,
                recipientName: mentee.name,
              ),
            ),
          );
        },
        color: Colors.green,
      ),
    ];

    return Container(
      margin: EdgeInsets.only(bottom: 8), 
      child: ExpandableActionCard(
        title: titleWidget,
        actions: actions,
        padding: EdgeInsets.all(16),
      ),
    );
  }
}

// ADDED: Mentor Feedback Dialog (adapted from mentee version)
class MentorFeedbackDialog extends StatefulWidget {
  const MentorFeedbackDialog({super.key});

  @override
  _MentorFeedbackDialogState createState() => _MentorFeedbackDialogState();
}

class _MentorFeedbackDialogState extends State<MentorFeedbackDialog> {
  UserData? _selectedSubject; // Who the feedback is ABOUT (doctor or other mentor)
  List<UserData> _availableSubjects = []; // Doctor and other mentors
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

      // Load assigned doctor (mentors have doctorId too)
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

      // Load assigned mentor (mentors can have mentors too!)
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

      // Load all other mentors (excluding self and already assigned mentor)
      try {
        final mentorsQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'mentor')
            .where('approved', isEqualTo: true)
            .get();
        
        for (final mentorDoc in mentorsQuery.docs) {
          // Exclude self and already added mentor
          if (mentorDoc.id != appState.user!.uid && 
              mentorDoc.id != userData.mentorId) {
            final mentorData = UserData.fromMap(mentorDoc.data());
            subjects.add(mentorData);
          }
        }
      } catch (e) {
        // Silently handle error
      }

      setState(() {
        _availableSubjects = subjects;
        _isLoading = false;
        
        if (subjects.isEmpty) {
          _errorMessage = 'No doctor or mentors available';
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
        'fromUserRole': 'mentor', // Add role to distinguish
        'subjectUserId': _selectedSubject!.uid,       // Doctor being reviewed
        'subjectUserName': _selectedSubject!.name,    // Doctor name
        'subjectUserRole': _selectedSubject!.role,    // 'doctor'
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
          'message': '${appState.userData?.name ?? 'A mentor'} sent feedback about ${_selectedSubject!.name} (${_selectedSubject!.role})',
          'type': 'feedback',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'data': {
            'fromUserId': appState.user!.uid,
            'fromUserRole': 'mentor',
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
                      
                      // Dropdown: Select doctor to give feedback about
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