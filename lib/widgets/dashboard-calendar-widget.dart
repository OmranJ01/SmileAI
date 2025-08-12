import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/models/user_data.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Providers/app_state.dart';
import '../models/calendar_event.dart';
import '../screens/common/calendar_screen.dart';
import '../services/notification_service.dart';

// Global event creation dialog for admin
class CreateAdminEventDialog extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback onEventCreated;

  const CreateAdminEventDialog({
    super.key,
    required this.selectedDate,
    required this.onEventCreated,
  });

  @override
  _CreateAdminEventDialogState createState() => _CreateAdminEventDialogState();
}

class _CreateAdminEventDialogState extends State<CreateAdminEventDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      DateTime.now().hour + 1,
      0,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createAdminEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an event title')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      
      // Create admin event that will be visible to all users
      await FirebaseFirestore.instance.collection('admin_events').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'dateTime': Timestamp.fromDate(_selectedDateTime),
        'createdBy': appState.user!.uid,
        'adminName': appState.userData?.name ?? 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
        'global': true,
      });

      // Get all approved users to send notifications
      final allUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('approved', isEqualTo: true)
          .get();

      // Send notifications to all users except the admin who created it
      for (final userDoc in allUsers.docs) {
        if (userDoc.id != appState.user!.uid) {
          try {
            await NotificationService.sendNotification(
              userId: userDoc.id,
              title: 'New Global Event',
              message: '${appState.userData?.name ?? 'Admin'} created a new event: ${_titleController.text}',
              type: 'global_event',
              data: {
                'eventTitle': _titleController.text,
                'eventDate': _selectedDateTime.toIso8601String(),
                'adminName': appState.userData?.name ?? 'Admin',
              },
            );
          } catch (e) {
            print('Error sending notification to ${userDoc.id}: $e');
          }
        }
      }

      widget.onEventCreated();
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Global event created and notifications sent to all users!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error creating admin event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating event'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(Icons.event_available, color: Colors.purple),
          SizedBox(width: 8),
          Text('Create Global Event'),
        ],
      ),
      content: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDateTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
                    );
                    if (time != null) {
                      setState(() {
                        _selectedDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.purple[700]),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date & Time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, yyyy - h:mm a').format(_selectedDateTime),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.public, color: Colors.purple[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This event will be visible to all users and they will receive notifications.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createAdminEvent,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
          child: _isCreating
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text('Create Event'),
        ),
      ],
    );
  }
}



// Create event dialog for doctors (existing functionality)
class CreateEventDialog extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback onEventCreated;

  const CreateEventDialog({
    super.key,
    required this.selectedDate,
    required this.onEventCreated,
  });

  @override
  _CreateEventDialogState createState() => _CreateEventDialogState();
}


class _CreateEventDialogState extends State<CreateEventDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  List<UserData> _assignedMentees = [];
  List<String> _selectedAttendees = [];
  bool _isLoadingMentees = true;
  bool _shareWithAllMentees = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      DateTime.now().hour + 1,
      0,
    );
    _loadAssignedMentees();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedMentees() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('doctorId', isEqualTo: appState.user!.uid)
          .where('approved', isEqualTo: true)
          .get();

      final mentees = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return UserData.fromMap(data);
      }).toList();

      setState(() {
        _assignedMentees = mentees;
        _isLoadingMentees = false;
      });
    } catch (e) {
      print('Error loading mentees: $e');
      setState(() {
        _isLoadingMentees = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(Icons.event_available, color: Colors.green[700]),
          SizedBox(width: 8),
          Text('Create Event'),
        ],
      ),
      content: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Event Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDateTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
                    );
                    if (time != null) {
                      setState(() {
                        _selectedDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue[700]),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date & Time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, yyyy - h:mm a').format(_selectedDateTime),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (_isLoadingMentees)
                Container(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                )
              else if (_assignedMentees.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This event will be shared with all your mentees:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${_assignedMentees.length} mentees will be notified',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                      SizedBox(height: 8),
                      Text('No mentees assigned'),
                      Text(
                        'Events will only be visible to you',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createEvent,
          child: _isCreating 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Create Event'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _createEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an event title')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.user == null || appState.userData == null) {
        throw Exception('User not authenticated');
      }

      // Always share with all mentees
      final attendeesList = _assignedMentees.map((m) => m.uid).toList();
      
      final eventData = {
        'doctorId': appState.user!.uid,
        'doctorName': appState.userData!.name,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'dateTime': Timestamp.fromDate(_selectedDateTime),
        'attendees': attendeesList,
        'sharedWithAll': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('doctor_events').add(eventData);

      // Send notifications to all mentees
      for (final mentee in _assignedMentees) {
        try {
          await NotificationService.sendEventNotification(
            userId: mentee.uid,
            title: 'New Event: ${_titleController.text.trim()}',
            message: 'Dr. ${appState.userData!.name} scheduled an event for ${DateFormat('MMM d at h:mm a').format(_selectedDateTime)}',
            eventDate: _selectedDateTime,
            doctorName: appState.userData!.name,
          );
        } catch (e) {
          print('Error sending event notification to ${mentee.uid}: $e');
        }
      }

      Navigator.pop(context);
      widget.onEventCreated();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event created and all mentees notified!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error creating event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating event: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }
}
class DashboardCalendarWidget extends StatefulWidget {
  final bool showCreateEventButton;
  
  const DashboardCalendarWidget({
    super.key,
    this.showCreateEventButton = false,
  });

  @override
  _DashboardCalendarWidgetState createState() => _DashboardCalendarWidgetState();
}

class _DashboardCalendarWidgetState extends State<DashboardCalendarWidget> {
  List<CalendarEvent> _todayEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayEvents();
  }

  Future<void> _loadTodayEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      List<CalendarEvent> todayEvents = [];
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // Load admin events - VISIBLE TO ALL USERS (including admin)
      try {
        final adminEventsQuery = await FirebaseFirestore.instance
            .collection('admin_events')
            .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();

        for (final doc in adminEventsQuery.docs) {
          final data = doc.data();
          final eventDate = (data['dateTime'] as Timestamp).toDate();
          
          todayEvents.add(CalendarEvent(
            id: doc.id,
            title: data['title'] ?? 'Admin Event',
            description: data['description'] ?? '',
            dateTime: eventDate,
            type: 'admin_event',
            createdBy: data['adminName'] ?? 'Admin',
          ));
        }
      } catch (e) {
        print('Error loading admin events: $e');
      }

      // Load tasks based on user role
      if (appState.userData?.role == 'doctor') {
        // For doctors, show tasks they assigned for today
        try {
          final tasksQuery = await FirebaseFirestore.instance
              .collection('mentee_tasks')
              .where('doctorId', isEqualTo: appState.user!.uid)
              .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
              .get();

          for (final doc in tasksQuery.docs) {
            final data = doc.data();
            final dueDate = (data['dueDate'] as Timestamp).toDate();
            
            // Get mentee name
            String menteeName = 'Unknown';
            try {
              final menteeDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(data['menteeId'])
                  .get();
              if (menteeDoc.exists) {
                menteeName = menteeDoc.data()?['name'] ?? 'Unknown';
              }
            } catch (e) {
              print('Error fetching mentee name: $e');
            }
            
            todayEvents.add(CalendarEvent(
              id: doc.id,
              title: '${data['title']} (for $menteeName)',
              description: data['description'] ?? '',
              dateTime: dueDate,
              type: 'task',
              createdBy: 'You',
              priority: data['priority'] ?? 'Medium',
              completed: data['completed'] ?? false,
            ));
          }
        } catch (e) {
          print('Error loading doctor tasks: $e');
        }
      } else {
        // For mentees and mentors, show their assigned tasks
        try {
          final tasksQuery = await FirebaseFirestore.instance
              .collection('mentee_tasks')
              .where('menteeId', isEqualTo: appState.user!.uid)
              .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
              .get();

          for (final doc in tasksQuery.docs) {
            final data = doc.data();
            final dueDate = (data['dueDate'] as Timestamp).toDate();
            todayEvents.add(CalendarEvent(
              id: doc.id,
              title: data['title'] ?? 'Task',
              description: data['description'] ?? '',
              dateTime: dueDate,
              type: 'task',
              createdBy: data['doctorName'] ?? 'Doctor',
              priority: data['priority'] ?? 'Medium',
              completed: data['completed'] ?? false,
            ));
          }
        } catch (e) {
          print('Error loading mentee tasks: $e');
        }
      }

      // Load events - FIXED LOGIC
      if (appState.userData?.role == 'doctor') {
        // Doctor sees all their own events for today
        try {
          final eventsQuery = await FirebaseFirestore.instance
              .collection('doctor_events')
              .where('doctorId', isEqualTo: appState.user!.uid)
              .get();

          for (final doc in eventsQuery.docs) {
            final data = doc.data();
            final eventDate = (data['dateTime'] as Timestamp).toDate();
            
            if (eventDate.year == today.year && 
                eventDate.month == today.month && 
                eventDate.day == today.day) {
              
              todayEvents.add(CalendarEvent(
                id: doc.id,
                title: data['title'] ?? 'Event',
                description: data['description'] ?? '',
                dateTime: eventDate,
                type: 'event',
                createdBy: 'You',
                attendees: List<String>.from(data['attendees'] ?? []),
              ));
            }
          }
        } catch (e) {
          print('Error loading doctor events: $e');
        }
      } else if (appState.userData?.role == 'mentor' || appState.userData?.role == 'mentee') {
        // Mentees and mentors see events where they are attendees OR events shared with all
        String? assignedDoctorId = appState.userData?.doctorId;
        
        if (assignedDoctorId != null) {
          try {
            // Get all events for today that the user should see
            final Set<String> processedEventIds = {};
            
            // Query 1: Events where user is specifically in attendees list
            final attendeeEventsQuery = await FirebaseFirestore.instance
                .collection('doctor_events')
                .where('attendees', arrayContains: appState.user!.uid)
                .get();

            for (final doc in attendeeEventsQuery.docs) {
              final data = doc.data();
              final eventDate = (data['dateTime'] as Timestamp).toDate();
              
              if (eventDate.year == today.year && 
                  eventDate.month == today.month && 
                  eventDate.day == today.day) {
                
                processedEventIds.add(doc.id);
                todayEvents.add(CalendarEvent(
                  id: doc.id,
                  title: data['title'] ?? 'Event',
                  description: data['description'] ?? '',
                  dateTime: eventDate,
                  type: 'event',
                  createdBy: data['doctorName'] ?? 'Doctor',
                  attendees: List<String>.from(data['attendees'] ?? []),
                ));
              }
            }

            // Query 2: Events shared with all mentees of the assigned doctor
            final sharedEventsQuery = await FirebaseFirestore.instance
                .collection('doctor_events')
                .where('doctorId', isEqualTo: assignedDoctorId)
                .where('sharedWithAll', isEqualTo: true)
                .get();

            for (final doc in sharedEventsQuery.docs) {
              if (!processedEventIds.contains(doc.id)) {
                final data = doc.data();
                final eventDate = (data['dateTime'] as Timestamp).toDate();
                
                if (eventDate.year == today.year && 
                    eventDate.month == today.month && 
                    eventDate.day == today.day) {
                  
                  todayEvents.add(CalendarEvent(
                    id: doc.id,
                    title: data['title'] ?? 'Event',
                    description: data['description'] ?? '',
                    dateTime: eventDate,
                    type: 'event',
                    createdBy: data['doctorName'] ?? 'Doctor',
                    attendees: List<String>.from(data['attendees'] ?? []),
                  ));
                }
              }
            }
          } catch (e) {
            print('Error loading events for mentee/mentor: $e');
          }
        }
      }

      // Load medication reminders for mentees and mentors (not doctors or admins)
      if (appState.userData?.role != 'doctor' && appState.userData?.role != 'admin') {
        try {
          final remindersQuery = await FirebaseFirestore.instance
              .collection('medication_reminders')
              .where('userId', isEqualTo: appState.user!.uid)
              .where('active', isEqualTo: true)
              .get();

          for (final doc in remindersQuery.docs) {
            final data = doc.data();
            final daysOfWeek = List<bool>.from(data['daysOfWeek'] ?? []);
            final hour = data['hour'] ?? 0;
            final minute = data['minute'] ?? 0;
            final medicationName = data['medication'] ?? 'Medication';
            
            final weekday = today.weekday;
            final dayIndex = weekday == 7 ? 6 : weekday - 1;
            
            if (dayIndex >= 0 && dayIndex < daysOfWeek.length && daysOfWeek[dayIndex]) {
              final reminderDateTime = DateTime(
                today.year,
                today.month,
                today.day,
                hour,
                minute,
              );

              todayEvents.add(CalendarEvent(
                id: doc.id,
                title: '💊 $medicationName',
                description: 'Medication reminder',
                dateTime: reminderDateTime,
                type: 'medication',
                createdBy: 'System',
              ));
            }
          }
        } catch (e) {
          print('Error loading medication reminders: $e');
        }
      }

      // Sort by time
      todayEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));
if (!mounted) return;
      setState(() {
        _todayEvents = todayEvents;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading today events: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final now = DateTime.now();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.calendar_view_month, size: 16),
                      label: Text('Full Calendar'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CalendarScreen()),
                        ).then((_) => _loadTodayEvents()); // Refresh when returning
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                      ),
                    ),
                    if (widget.showCreateEventButton && appState.userData?.role == 'doctor')
                      TextButton.icon(
                        icon: Icon(Icons.add, size: 16),
                        label: Text('Create Event'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => CreateEventDialog(
                              selectedDate: DateTime.now(),
                              onEventCreated: _loadTodayEvents,
                            ),
                          );
                        },
                      ),
                    if (widget.showCreateEventButton && appState.userData?.role == 'admin')
                      TextButton.icon(
                        icon: Icon(Icons.add, size: 16),
                        label: Text('Create Global Event'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => CreateAdminEventDialog(
                              selectedDate: DateTime.now(),
                              onEventCreated: _loadTodayEvents,
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.purple[700],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Text('Today'),
            SizedBox(height: 8),
            Text(
              DateFormat('EEE, MMM d').format(now),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            // Simple calendar view
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _buildWeekDays(),
              ),
            ),
            SizedBox(height: 16),
            // Events section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Events',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_todayEvents.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_todayEvents.length}',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            if (_isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_todayEvents.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No events scheduled for today',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your schedule is clear',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                constraints: BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _todayEvents.length > 3 ? 3 : _todayEvents.length,
                  itemBuilder: (context, index) {
                    return _buildEventItem(_todayEvents[index]);
                  },
                ),
              ),
            if (_todayEvents.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CalendarScreen()),
                      );
                    },
                    child: Text('View all ${_todayEvents.length} events'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWeekDays() {
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    
    return List.generate(7, (index) {
      final dayDate = weekStart.add(Duration(days: index));
      final isToday = dayDate.day == today.day && 
                     dayDate.month == today.month && 
                     dayDate.year == today.year;
      
      return Column(
        children: [
          Text(
            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isToday ? Colors.blue : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${dayDate.day}',
                style: TextStyle(
                  color: isToday ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildEventItem(CalendarEvent event) {
    Color color;
    IconData icon;
    
    switch (event.type) {
      case 'task':
        color = event.completed == true ? Colors.grey : Colors.red;
        icon = Icons.assignment;
        break;
      case 'event':
        color = Colors.blue;
        icon = Icons.event;
        break;
      case 'admin_event':
        color = Colors.purple;
        icon = Icons.public;
        break;
      case 'medication':
        color = Colors.green;
        icon = Icons.medication;
        break;
      default:
        color = Colors.grey;
        icon = Icons.calendar_today;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CalendarScreen()),
          );
        },
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: event.completed == true ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (event.type == 'admin_event')
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'GLOBAL',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.purple[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    DateFormat('h:mm a').format(event.dateTime),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (event.priority != null && event.type == 'task')
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(event.priority!).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.priority!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getPriorityColor(event.priority!),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}