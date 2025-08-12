import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../Providers/app_state.dart';
import '../common/settings_screen.dart';
import '../../models/user_data.dart';
import '../common/chatScreen.dart';
import '../admin/assigning_screen.dart';
import '../../models/articles.dart';
import '../../services/notification_service.dart';
import '../common/settings_screen.dart';
import '../common/chatScreen.dart';
import '../../widgets/expandable_action_card.dart';
import '../../widgets/dashboard-calendar-widget.dart';


class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  _DoctorDashboardScreenState createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  List<UserData> _assignedMentees = [];
  List<UserData> _filteredMentees = [];
  bool _isLoadingMentees = true;
  bool _isMenteesListExpanded = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAssignedMentees();
    _searchController.addListener(_filterMentees);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMentees() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMentees = List.from(_assignedMentees);
      } else {
        _filteredMentees = _assignedMentees.where((mentee) {
          return mentee.name.toLowerCase().contains(query) ||
                 mentee.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadAssignedMentees() async {
    setState(() {
      _isLoadingMentees = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.user == null) return;

      // Query users assigned to this doctor (regardless of their current role)
      // This will include both mentees and those who became mentors
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('doctorId', isEqualTo: appState.user!.uid)
          .get();

      final assignedUsers = querySnapshot.docs.map((doc) {
        return UserData.fromMap(doc.data());
      }).toList();

      setState(() {
        _assignedMentees = assignedUsers;
        _filteredMentees = List.from(assignedUsers);
      });
    } catch (e) {
      print('Error loading assigned mentees: $e');
    } finally {
      setState(() {
        _isLoadingMentees = false;
      });
    }
  }

  // Show dialog to select mentee for task assignment
  void _showSelectMenteeForTaskDialog() {
    if (_assignedMentees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No mentees assigned yet')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.assignment_add, color: Colors.purple),
            SizedBox(width: 8),
            Text('Select Mentee for Task'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _assignedMentees.length,
            itemBuilder: (context, index) {
              final mentee = _assignedMentees[index];
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: mentee.role == 'mentor' ? Colors.green[100] : Colors.blue[100],
                    child: Text(
                      mentee.name[0].toUpperCase(),
                      style: TextStyle(
                        color: mentee.role == 'mentor' ? Colors.green[800] : Colors.blue[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(mentee.name),
                      SizedBox(width: 8),
                      if (mentee.role == 'mentor')
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'MENTOR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(mentee.email, style: TextStyle(fontSize: 12)),
                  trailing: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAssignTaskDialog(mentee);
                    },
                    icon: Icon(Icons.add, size: 16),
                    label: Text('Add Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      textStyle: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Task assignment dialog
  void _showAssignTaskDialog(UserData mentee) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime dueDate = DateTime.now().add(Duration(days: 7));
    String priority = 'Medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign Task to ${mentee.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Task Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: ['High', 'Medium', 'Low'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      priority = value ?? 'Medium';
                    });
                  },
                ),
                SizedBox(height: 16),
                ListTile(
                  title: Text('Due Date'),
                  subtitle: Text(DateFormat('MMM d, yyyy').format(dueDate)),
                  trailing: Icon(Icons.calendar_today),
                  onTap: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (selectedDate != null) {
                      setDialogState(() {
                        dueDate = selectedDate;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
                  await _assignTaskToMentee(
                    mentee,
                    titleController.text,
                    descriptionController.text,
                    priority,
                    dueDate,
                  );
                  Navigator.pop(context);
                }
              },
              child: Text('Assign Task'),
            ),
          ],
        ),
      ),
    );
  }

  // Assign task to mentee
  Future<void> _assignTaskToMentee(
    UserData mentee,
    String title,
    String description,
    String priority,
    DateTime dueDate,
  ) async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;

    try {
      // Add task to Firestore
      await FirebaseFirestore.instance.collection('mentee_tasks').add({
        'menteeId': mentee.uid,
        'doctorId': appState.user!.uid,
        'doctorName': appState.userData?.name ?? 'Doctor',
        'title': title,
        'description': description,
        'priority': priority,
        'dueDate': Timestamp.fromDate(dueDate),
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send notification to mentee
      await NotificationService.sendNotification(
        userId: mentee.uid,
        title: 'New Task Assigned',
        message: 'Dr. ${appState.userData?.name ?? 'Doctor'} assigned you a new task: $title',
        type: 'task',
        data: {
          'taskTitle': title,
          'doctorName': appState.userData?.name ?? 'Doctor',
          'dueDate': dueDate.toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task assigned to ${mentee.name} successfully!')),
      );
    } catch (e) {
      print('Error assigning task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning task')),
      );
    }
  }

  // NEW: Show mentor assignment dialog with available mentors from doctor's mentees
  void _showAssignMentorDialog(UserData mentee) {
    // Get available mentors (promoted mentees of this doctor)
    final availableMentors = _assignedMentees
        .where((user) => user.role == 'mentor' && user.uid != mentee.uid)
        .toList();

    if (availableMentors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No available mentors from your mentees. Promote a mentee to mentor first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.supervisor_account, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text('Assign Mentor to ${mentee.name}'),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a mentor from your promoted mentees:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: availableMentors.length,
                  itemBuilder: (context, index) {
                    final mentor = availableMentors[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: Text(
                            mentor.name[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(mentor.name),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'MENTOR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mentor.email, style: TextStyle(fontSize: 12)),
                            SizedBox(height: 4),
                            FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .where('mentorId', isEqualTo: mentor.uid)
                                  .get(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  final currentMenteeCount = snapshot.data!.docs.length;
                                  return Text(
                                    'Currently mentoring: $currentMenteeCount mentees',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  );
                                }
                                return Text(
                                  'Loading...',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                );
                              },
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _assignMentorToMentee(mentee, mentor);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text('Assign'),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // FIXED: Assign mentor to mentee - Fixed the context access issue
  Future<void> _assignMentorToMentee(UserData mentee, UserData mentor) async {
    try {
      // Get the current doctor's info from AppState
      final appState = Provider.of<AppState>(context, listen: false);
      final doctorName = appState.userData?.name ?? 'Doctor';
      
      print('🔄 Starting mentor assignment...');
      print('👤 Mentee: ${mentee.name} (${mentee.uid})');
      print('👨‍🏫 Mentor: ${mentor.name} (${mentor.uid})');
      print('👨‍⚕️ Doctor: $doctorName');

      // Update mentee's mentorId
      await FirebaseFirestore.instance
          .collection('users')
          .doc(mentee.uid)
          .update({'mentorId': mentor.uid});
      
      print('✅ Updated mentee document with mentorId');

      // Send notification to mentee
      await NotificationService.sendNotification(
        userId: mentee.uid,
        title: 'Mentor Assigned',
        message: 'Dr. $doctorName assigned ${mentor.name} as your mentor.',
        type: 'mentor_assignment',
        data: {
          'mentorName': mentor.name,
          'mentorId': mentor.uid,
        },
      );
      
      print('✅ Sent notification to mentee');

      // Send notification to mentor
      await NotificationService.sendNotification(
        userId: mentor.uid,
        title: 'New Mentee Assigned',
        message: 'Dr. $doctorName assigned ${mentee.name} as your mentee.',
        type: 'mentee_assignment',
        data: {
          'menteeName': mentee.name,
          'menteeId': mentee.uid,
        },
      );
      
      print('✅ Sent notification to mentor');

      // Refresh the list to show updated assignments
      await _loadAssignedMentees();
      
      print('✅ Refreshed mentee list');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${mentor.name} assigned as mentor to ${mentee.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      print('✅ Mentor assignment completed successfully');
      
    } catch (e) {
      print('❌ Error assigning mentor: $e');
      print('❌ Stack trace: ${e.toString()}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning mentor: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return RefreshIndicator(
      onRefresh: _loadAssignedMentees,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with welcome message and settings button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        'Dr. ${appState.userData?.name ?? "Doctor"}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
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
              
              // Doctor status card
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.medical_services,
                            color: Colors.blue[700],
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doctor',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${_assignedMentees.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Assigned Mentees',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDoctorStatItem(
                          'Total', 
                          '${_assignedMentees.length}', 
                          Icons.people
                        ),
                        _buildDoctorStatItem(
                          'With Mentor', 
                          '${_assignedMentees.where((m) => m.mentorId != null && m.mentorId!.isNotEmpty).length}', 
                          Icons.supervisor_account
                        ),
                        _buildDoctorStatItem(
                          'Without Mentor', 
                          '${_assignedMentees.where((m) => m.mentorId == null || m.mentorId!.isEmpty).length}', 
                          Icons.person_add
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // My Assigned Mentees section with collapsible list
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
                                  color: Colors.blue,
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
                                icon: Icon(
                                  _isMenteesListExpanded 
                                      ? Icons.keyboard_arrow_up 
                                      : Icons.keyboard_arrow_down,
                                  size: 28,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isMenteesListExpanded = !_isMenteesListExpanded;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_isMenteesListExpanded) ...[
                        SizedBox(height: 16),
                        // Search bar
                        if (_assignedMentees.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search mentees by name or email...',
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
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
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
                                  'Wait for admin to assign mentees to you',
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
                                  'Try searching with a different name or email',
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
              
              // Schedule/Events Calendar
             DashboardCalendarWidget(showCreateEventButton: true),
              SizedBox(height: 24),
    Text(
      'Pending Resubmit Requests',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
 FutureBuilder<QuerySnapshot>(
  future: FirebaseFirestore.instance
      .collection('resubmit_requests')
      .where('doctorId', isEqualTo: appState.user?.uid ?? '')
      .where('status', isEqualTo: 'pending')
      .get(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    final requests = snapshot.data!.docs;
    if (requests.isEmpty) return Text('No resubmit requests.');

    // ✅ Keep local approval states in a Map:
    final Map<String, bool> approvalStates = {};

    return Column(
      children: requests.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final docId = doc.id;

        // Initialize local state if not yet tracked:
        approvalStates.putIfAbsent(docId, () => data['status'] == 'approved');

        return Card(
          child: ListTile(
            title: Text('${data['userName']} (${data['userEmail']})'),
            subtitle: Text('Exam: ${data['examId']}'),
            trailing: StatefulBuilder(
              builder: (context, setState) {
                final isApproved = approvalStates[docId]!;

                return ElevatedButton(
                  child: Text(isApproved ? 'Approved' : 'Approve'),
                  onPressed: isApproved
                      ? null
                      : () async {
                          // ✅ Update local state immediately:
                          setState(() {
                            approvalStates[docId] = true;
                          });
                          // ✅ Then update Firestore:
                          await doc.reference.update({'status': 'approved'});
                          // Send notification to the user
await NotificationService.sendNotification(
  userId: data['userId'], // or whatever field holds the mentee/mentor's UID
  title: 'Resubmit Request Approved',
  message: 'Your resubmit request for exam ${data['examId']} has been approved by Dr. ${appState.userData?.name ?? "Doctor"}.',
  type: 'resubmit',
  data: {
    'examId': data['examId'],
    'doctorId': appState.user?.uid,
    'doctorName': appState.userData?.name,
  },
);
final menteeDoc = await FirebaseFirestore.instance.collection('users').doc(data['userId']).get();
final fcmToken = menteeDoc.data()?['fcmToken'];
if (fcmToken != null) {
  await NotificationService.sendFcmPushNotification(
    token: fcmToken,
    title: 'Resubmit Request Approved',
    body: 'Your resubmit request for exam ${data['examId']} has been approved!',
    data: {
      'examId': data['examId'],
      'doctorId': appState.user?.uid,
      'doctorName': appState.userData?.name,
    },
  );
}
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Request approved')),
                          );  
                        },
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  },
)



            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMenteeCard(UserData mentee) {
    // Build the title widget with avatar and name
    final titleWidget = Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: mentee.role == 'mentor' ? Colors.green[100] : Colors.blue[100],
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
                        color: mentee.role == 'mentor' ? Colors.green[800] : Colors.blue[800],
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
                  color: mentee.role == 'mentor' ? Colors.green[800] : Colors.blue[800],
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
              Row(
                children: [
                  Text(
                    mentee.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  if (mentee.role == 'mentor')
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'MENTOR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
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

    // Build subtitle widget with status information
    Widget? subtitleWidget;
    if (mentee.role == 'mentee') {
      if (mentee.mentorId != null && mentee.mentorId!.isNotEmpty) {
        subtitleWidget = FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(mentee.mentorId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Loading mentor...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              );
            }
            
            if (snapshot.hasData && snapshot.data!.exists) {
              final mentorData = UserData.fromMap(
                snapshot.data!.data() as Map<String, dynamic>
              );
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                    SizedBox(width: 4),
                    Text(
                      'Mentor: ${mentorData.name}',
                      style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }
            
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, size: 14, color: Colors.orange[700]),
                  SizedBox(width: 4),
                  Text(
                    'Mentor not found',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        subtitleWidget = Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add, size: 14, color: Colors.orange[700]),
              SizedBox(width: 4),
              Text(
                'No mentor assigned',
                style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }
    } else {
      // For mentors, show their mentee count
      subtitleWidget = FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .where('mentorId', isEqualTo: mentee.uid)
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
                    '$menteeCount mentees assigned',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }
          return SizedBox.shrink();
        },
      );
    }

    // Build action buttons
    List<ActionButton> actions = [
      ActionButton(
        label: 'Add Task',
        icon: Icons.assignment_add,
        onPressed: () => _showAssignTaskDialog(mentee),
        color: Colors.purple,
      ),
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
        color: Colors.blue,
      ),
    ];

    // Add assign mentor button for mentees
    if (mentee.role == 'mentee') {
      actions.add(
        ActionButton(
          label: mentee.mentorId != null && mentee.mentorId!.isNotEmpty 
              ? 'Change Mentor' 
              : 'Assign Mentor',
          icon: Icons.supervisor_account,
          onPressed: () => _showAssignMentorDialog(mentee),
          color: Colors.green[700],
          isOutlined: true,
        ),
      );
    }

    return ExpandableActionCard(
      title: titleWidget,
      subtitle: subtitleWidget,
      actions: actions,
      padding: EdgeInsets.all(16),
    );
  }
}