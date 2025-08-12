import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../Providers/app_state.dart';
import '../../services/notification_service.dart';

class MentorTasksScreen extends StatefulWidget {
  const MentorTasksScreen({super.key});

  @override
  _MentorTasksScreenState createState() => _MentorTasksScreenState();
}

class _MentorTasksScreenState extends State<MentorTasksScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
    _loadMedications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Quick track medication as taken
  void _quickTrackMedication(String medicationName) {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;

    FirebaseFirestore.instance.collection('medication_tracking').add({
      'userId': appState.user!.uid,
      'medication': medicationName,
      'taken': true,
      'notes': 'Taken via notification reminder',
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'timestamp': FieldValue.serverTimestamp(),
    }).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$medicationName marked as taken!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  Future<void> _loadTasks() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;

    try {
      // Query tasks where the current user is the mentee (same for mentors who were promoted)
      final tasksQuery = FirebaseFirestore.instance
          .collection('mentee_tasks')
          .where('menteeId', isEqualTo: appState.user!.uid);

      final tasksSnapshot = await tasksQuery.get();

      setState(() {
        _tasks = tasksSnapshot.docs.map((doc) {
          var data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        
        // Sort tasks by creation date (newest first)
        _tasks.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
      await FirebaseFirestore.instance
          .collection('mentee_tasks')
          .doc(taskId)
          .update({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      _loadTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task marked as completed!')),
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
      // Add to Firestore
      final docRef = await FirebaseFirestore.instance.collection('medication_reminders').add({
        'userId': appState.user!.uid,
        'medication': medication,
        'hour': time.hour,
        'minute': time.minute,
        'daysOfWeek': daysOfWeek,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Schedule local notifications
      await NotificationService.scheduleMedicationReminder(
        medicationId: docRef.id,
        medicationName: medication,
        hour: time.hour,
        minute: time.minute,
        daysOfWeek: daysOfWeek,
        userId: appState.user!.uid,
      );

      _loadMedications();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medication reminder added! You will receive notifications at ${time.format(context)}.'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('Error adding medication reminder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding medication reminder')),
      );
    }
  }

  void _showMedicationTrackingDialog(Map<String, dynamic> medication) {
    bool taken = false;
    String notes = '';
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
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: Text('Yes, I took it'),
                      value: taken,
                      onChanged: (value) {
                        setDialogState(() {
                          taken = value ?? false;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  notes = value;
                },
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

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.medication, color: Colors.white),
        ),
        title: Text(
          medication['medication'],
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time: ${TimeOfDay(hour: medication['hour'], minute: medication['minute']).format(context)}',
            ),
            Text('Days: ${activeDays.join(', ')}'),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🔔 Active reminder - notifications will appear at this time',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[800],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.add_circle, color: Colors.green),
              onPressed: () => _showMedicationTrackingDialog(medication),
              tooltip: 'Track Adherence',
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteMedicationReminder(medication['id']),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _deleteMedicationReminder(String medicationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('medication_reminders')
          .doc(medicationId)
          .update({'active': false});

      // Cancel the notifications
      await NotificationService.cancelMedicationReminder(medicationId);

      _loadMedications();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medication reminder removed')),
      );
    } catch (e) {
      print('Error deleting medication reminder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Tasks & Medications'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
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
          RefreshIndicator(
            onRefresh: _loadTasks,
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
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
                              SizedBox(height: 32),
                              ElevatedButton.icon(
                                onPressed: _loadTasks,
                                icon: Icon(Icons.refresh),
                                label: Text('Refresh'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) => _buildTaskCard(_tasks[index]),
                      ),
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
                          SizedBox(height: 100),
                          Icon(Icons.medication, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No medication reminders set',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
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