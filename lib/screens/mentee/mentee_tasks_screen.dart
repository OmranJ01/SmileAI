import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../Providers/app_state.dart';
import '../../services/notification_service.dart';
import '../../widgets/expandable_action_card.dart';

class MenteeTasksScreen extends StatefulWidget {
  @override
  _MenteeTasksScreenState createState() => _MenteeTasksScreenState();
}

class _MenteeTasksScreenState extends State<MenteeTasksScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMedications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _getTasksStream() {
  final appState = Provider.of<AppState>(context, listen: false);
  if (appState.user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('mentee_tasks')
      .where('menteeId', isEqualTo: appState.user!.uid)
      // REMOVED: .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    final tasks = snapshot.docs.map((doc) {
      var data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    
    // Sort in memory instead
    tasks.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    
    return tasks;
  });
}

  Future<void> _loadMedications() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;

    try {
      final medicationsSnapshot = await FirebaseFirestore.instance
          .collection('medication_reminders')
          .where('userId', isEqualTo: appState.user!.uid)
          .where('active', isEqualTo: true)
          .get();

      setState(() {
        _medications = medicationsSnapshot.docs.map((doc) {
          var data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      print('Error loading medications: $e');
    }
  }

  Future<void> _markTaskComplete(String taskId) async {
    try {
      // First, mark the task as complete
      await FirebaseFirestore.instance
          .collection('mentee_tasks')
          .doc(taskId)
          .update({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Award points to the mentee
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.user != null) {
        // Award 10 points for completing a task
        final pointsToAward = 2;
        
        // Update user's points in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(appState.user!.uid)
            .update({
          'points': FieldValue.increment(pointsToAward),
        });

        // Update points in app state
        appState.updatePoints(appState.points + pointsToAward);
        
        // Refresh user data to ensure UI updates immediately
        await appState.refreshUserData();
        
        // Create a notification for the mentee
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': appState.user!.uid,
          'title': 'Points Earned!',
          'message': 'You earned $pointsToAward points for completing a task!',
          'type': 'points',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      _loadMedications();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task completed! You earned 2 points!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error marking task complete: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing task')),
      );
    }
  }

  void _showAddMedicationDialog() {
    final medicationController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    List<bool> selectedDays = List.filled(7, false);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Set Medication Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: medicationController,
                  decoration: InputDecoration(
                    labelText: 'Medication Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                ListTile(
                  title: Text('Time: ${selectedTime.format(context)}'),
                  trailing: Icon(Icons.schedule),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() {
                        selectedTime = time;
                      });
                    }
                  },
                ),
                SizedBox(height: 16),
                Text('Days of Week:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (index) => 
                    FilterChip(
                      label: Text(days[index]),
                      selected: selectedDays[index],
                      onSelected: (selected) {
                        setDialogState(() {
                          selectedDays[index] = selected;
                        });
                      },
                    ),
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
            ElevatedButton(
              onPressed: () async {
                if (medicationController.text.isNotEmpty && selectedDays.contains(true)) {
                  await _addMedicationReminder(
                    medicationController.text,
                    selectedTime,
                    selectedDays,
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter medication name and select at least one day'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: Text('Add Reminder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMedicationReminder(String medication, TimeOfDay time, List<bool> daysOfWeek) async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;

    try {
      DocumentReference docRef = await FirebaseFirestore.instance.collection('medication_reminders').add({
        'userId': appState.user!.uid,
        'medication': medication,
        'hour': time.hour,
        'minute': time.minute,
        'daysOfWeek': daysOfWeek,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Schedule the actual device notifications
      await NotificationService.scheduleMedicationReminder(
        medicationId: docRef.id,
        medicationName: medication,
        hour: time.hour,
        minute: time.minute,
        daysOfWeek: daysOfWeek,
        userId: appState.user!.uid,
      );

      _loadMedications();
      
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final selectedDayNames = <String>[];
      for (int i = 0; i < daysOfWeek.length; i++) {
        if (daysOfWeek[i]) selectedDayNames.add(dayNames[i]);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder set for $medication at ${time.format(context)} on ${selectedDayNames.join(', ')}',
          ),
          duration: Duration(seconds: 4),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding medication reminder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding reminder'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMedicationTrackingDialog(Map<String, dynamic> medication) {
    bool taken = false;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Track ${medication['medication']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Did you take your medication today?'),
              SizedBox(height: 16),
              CheckboxListTile(
                title: Text('Yes, I took it'),
                value: taken,
                onChanged: (value) {
                  setDialogState(() {
                    taken = value ?? false;
                  });
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _trackMedicationAdherence(medication['id'], taken, notesController.text);
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _trackMedicationAdherence(String medicationId, bool taken, String notes) async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;

    try {
      await FirebaseFirestore.instance.collection('medication_tracking').add({
        'userId': appState.user!.uid,
        'medicationId': medicationId,
        'taken': taken,
        'notes': notes,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medication adherence tracked!')),
      );
    } catch (e) {
      print('Error tracking medication: $e');
    }
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final isCompleted = task['completed'] ?? false;
    final dueDate = task['dueDate'] != null 
        ? (task['dueDate'] as Timestamp).toDate()
        : null;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted ? Colors.green : Colors.orange,
          child: Icon(
            isCompleted ? Icons.check : Icons.assignment,
            color: Colors.white,
          ),
        ),
        title: Text(
          task['title'] ?? 'Task',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task['description'] != null && task['description'].isNotEmpty)
              Text(task['description']),
            if (dueDate != null)
              Text(
                'Due: ${DateFormat('MMM d, yyyy').format(dueDate)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            Text(
              'From: Dr. ${task['doctorName'] ?? 'Doctor'}',
              style: TextStyle(color: Colors.blue[600], fontSize: 12),
            ),
          ],
        ),
        trailing: !isCompleted
            ? ElevatedButton(
                onPressed: () => _markTaskComplete(task['id']),
                child: Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              )
            : Icon(Icons.check_circle, color: Colors.green),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> medication) {
    final daysOfWeek = List<bool>.from(medication['daysOfWeek'] ?? List.filled(7, false));
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final activeDays = <String>[];
    for (int i = 0; i < daysOfWeek.length; i++) {
      if (daysOfWeek[i]) activeDays.add(days[i]);
    }

    // Build title widget
    final titleWidget = Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.medication, color: Colors.white),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medication['medication'],
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 2),
              Text(
                'Time: ${TimeOfDay(hour: medication['hour'], minute: medication['minute']).format(context)}',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );

    // Build subtitle widget
    final subtitleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Days: ${activeDays.join(', ')}'),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_active, size: 12, color: Colors.green[700]),
              SizedBox(width: 4),
              Text(
                'Notifications scheduled',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // Build action buttons
    final actions = [
  
      ActionButton(
        label: 'Delete',
        icon: Icons.delete,
        onPressed: () => _deleteMedicationReminder(medication['id']),
        color: Colors.red,
      ),

    ];

    return ExpandableActionCard(
      title: titleWidget,
      subtitle: subtitleWidget,
      actions: actions,
    );
  }

  Future<void> _deleteMedicationReminder(String medicationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Reminder'),
        content: Text('Are you sure you want to delete this medication reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await NotificationService.cancelMedicationReminder(medicationId);
      
      await FirebaseFirestore.instance
          .collection('medication_reminders')
          .doc(medicationId)
          .update({'active': false});

      _loadMedications();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medication reminder deleted'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error deleting medication reminder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting reminder'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Tasks & Medications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Tasks', icon: Icon(Icons.assignment)),
            Tab(text: 'Medications', icon: Icon(Icons.medication)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tasks Tab
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getTasksStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Error loading tasks'),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {}); // Force rebuild
                        },
                        icon: Icon(Icons.refresh),
                        label: Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              
              final tasks = snapshot.data ?? [];
              
              if (tasks.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 100),
                        Icon(Icons.assignment, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No tasks assigned yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        Text(
                          'Your doctor will assign tasks for you',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return RefreshIndicator(
                onRefresh: () async {
                  // Just a placeholder since StreamBuilder auto-updates
                  await Future.delayed(Duration(seconds: 1));
                },
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) => _buildTaskCard(tasks[index]),
                ),
              );
            },
          ),
          // Medications Tab
          RefreshIndicator(
            onRefresh: _loadMedications,
            child: _medications.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 80),
                          Icon(Icons.medication, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No medication reminders set',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Set reminders to get notifications at exact times',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showAddMedicationDialog,
                            icon: Icon(Icons.add),
                            label: Text('Add Medication Reminder'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _medications.length,
                    itemBuilder: (context, index) => _buildMedicationCard(_medications[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          return _tabController.index == 1
              ? FloatingActionButton(
                  onPressed: _showAddMedicationDialog,
                  child: Icon(Icons.add),
                  tooltip: 'Add Medication Reminder',
                )
              : SizedBox.shrink();
        },
      ),
    );
  }
}