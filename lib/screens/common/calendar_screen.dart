import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../Providers/app_state.dart';
import '../../models/calendar_event.dart';
import '../../models/user_data.dart';
import '../../services/notification_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<CalendarEvent> _events = [];
  List<CalendarEvent> _selectedEvents = [];
  bool _isLoading = true;
  Map<DateTime, List<CalendarEvent>> _eventsByDay = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadCalendarEvents();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _loadCalendarEvents() async {
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

      List<CalendarEvent> allEvents = [];

      // 1. Load admin events FIRST - VISIBLE TO ALL USERS (including admin)
      try {
        final adminEventsQuery = await FirebaseFirestore.instance
            .collection('admin_events')
            .get();

        for (final doc in adminEventsQuery.docs) {
          final data = doc.data();
          final eventDate = (data['dateTime'] as Timestamp).toDate();
          
          allEvents.add(CalendarEvent(
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

      // 2. Load tasks based on user role
      if (appState.userData?.role == 'doctor') {
        // For doctors, show tasks they assigned
        final tasksQuery = await FirebaseFirestore.instance
            .collection('mentee_tasks')
            .where('doctorId', isEqualTo: appState.user!.uid)
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
          
          allEvents.add(CalendarEvent(
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
      } else {
        // For mentees and mentors, show their assigned tasks
        final tasksQuery = await FirebaseFirestore.instance
            .collection('mentee_tasks')
            .where('menteeId', isEqualTo: appState.user!.uid)
            .get();

        for (final doc in tasksQuery.docs) {
          final data = doc.data();
          final dueDate = (data['dueDate'] as Timestamp).toDate();
          allEvents.add(CalendarEvent(
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
      }

      // 3. Load doctor events - FIXED WITH PROPER TWO-QUERY APPROACH
      if (appState.userData?.role == 'doctor') {
        // Doctor sees all their own events
        try {
          final eventsQuery = await FirebaseFirestore.instance
              .collection('doctor_events')
              .where('doctorId', isEqualTo: appState.user!.uid)
              .get();

          for (final doc in eventsQuery.docs) {
            final data = doc.data();
            final eventDate = (data['dateTime'] as Timestamp).toDate();
            
            allEvents.add(CalendarEvent(
              id: doc.id,
              title: data['title'] ?? 'Event',
              description: data['description'] ?? '',
              dateTime: eventDate,
              type: 'event',
              createdBy: 'You',
              attendees: List<String>.from(data['attendees'] ?? []),
            ));
          }
        } catch (e) {
          print('Error loading doctor events: $e');
        }
      } else if (appState.userData?.role == 'mentor' || appState.userData?.role == 'mentee') {
        // Mentees and mentors see events where they are attendees OR events shared with all
        String? assignedDoctorId = appState.userData?.doctorId;
        
        if (assignedDoctorId != null) {
          try {
            // Use a Set to track processed event IDs to avoid duplicates
            final Set<String> processedEventIds = {};
            
            // Query 1: Events where user is specifically in attendees list
            final attendeeEventsQuery = await FirebaseFirestore.instance
                .collection('doctor_events')
                .where('attendees', arrayContains: appState.user!.uid)
                .get();

            for (final doc in attendeeEventsQuery.docs) {
              final data = doc.data();
              final eventDate = (data['dateTime'] as Timestamp).toDate();
              
              processedEventIds.add(doc.id);
              allEvents.add(CalendarEvent(
                id: doc.id,
                title: data['title'] ?? 'Event',
                description: data['description'] ?? '',
                dateTime: eventDate,
                type: 'event',
                createdBy: data['doctorName'] ?? 'Doctor',
                attendees: List<String>.from(data['attendees'] ?? []),
              ));
            }

            // Query 2: Events shared with all mentees of the assigned doctor
            final sharedEventsQuery = await FirebaseFirestore.instance
                .collection('doctor_events')
                .where('doctorId', isEqualTo: assignedDoctorId)
                .where('sharedWithAll', isEqualTo: true)
                .get();

            for (final doc in sharedEventsQuery.docs) {
              // Skip if we already processed this event
              if (!processedEventIds.contains(doc.id)) {
                final data = doc.data();
                final eventDate = (data['dateTime'] as Timestamp).toDate();
                
                allEvents.add(CalendarEvent(
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
          } catch (e) {
            print('Error loading events for mentee/mentor: $e');
          }
        }
      }

      // 4. Load medication reminders for mentees and mentors (not doctors or admins)
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

            // Generate reminder events for the next 60 days
            final today = DateTime.now();
            for (int i = 0; i < 60; i++) {
              final checkDate = today.add(Duration(days: i));
              final weekday = checkDate.weekday;
              final dayIndex = weekday == 7 ? 6 : weekday - 1;
              
              if (dayIndex >= 0 && dayIndex < daysOfWeek.length && daysOfWeek[dayIndex]) {
                final reminderDateTime = DateTime(
                  checkDate.year,
                  checkDate.month,
                  checkDate.day,
                  hour,
                  minute,
                );

                allEvents.add(CalendarEvent(
                  id: '${doc.id}_$i',
                  title: '💊 $medicationName',
                  description: 'Medication reminder at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                  dateTime: reminderDateTime,
                  type: 'medication',
                  createdBy: 'System',
                ));
              }
            }
          }
        } catch (e) {
          print('Error loading medication reminders: $e');
        }
      }

      // Organize events by day
      _eventsByDay.clear();
      for (final event in allEvents) {
        final normalizedDate = _normalizeDate(event.dateTime);
        if (_eventsByDay[normalizedDate] != null) {
          _eventsByDay[normalizedDate]!.add(event);
        } else {
          _eventsByDay[normalizedDate] = [event];
        }
      }

      setState(() {
        _events = allEvents;
        _selectedEvents = _getEventsForDay(_selectedDay!);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading calendar events: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    final events = _eventsByDay[normalizedDay] ?? [];
    return events..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  void _showCreateEventDialog() {
    final appState = Provider.of<AppState>(context, listen: false);
    
    // Allow both doctors and admins to create events
    if (appState.userData?.role == 'doctor') {
      showDialog(
        context: context,
        builder: (context) => CreateEventDialog(
          selectedDate: _selectedDay ?? DateTime.now(),
          onEventCreated: _loadCalendarEvents,
        ),
      );
    } else if (appState.userData?.role == 'admin') {
      showDialog(
        context: context,
        builder: (context) => CreateAdminEventDialog(
          selectedDate: _selectedDay ?? DateTime.now(),
          onEventCreated: _loadCalendarEvents,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only doctors and admins can create events')),
      );
    }
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final isAdmin = appState.userData?.role == 'admin';
    
    // Show confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Event'),
        content: Text('Are you sure you want to delete this event? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    try {
      if (isAdmin && event.type == 'admin_event') {
        // Delete admin event
        await FirebaseFirestore.instance
            .collection('admin_events')
            .doc(event.id)
            .delete();
        
        // Get all approved users to send notifications
        final allUsers = await FirebaseFirestore.instance
            .collection('users')
            .where('approved', isEqualTo: true)
            .get();

        // Send notifications to all users except the admin who deleted it
        for (final userDoc in allUsers.docs) {
          if (userDoc.id != appState.user!.uid) {
            try {
              await NotificationService.sendNotification(
                userId: userDoc.id,
                title: 'Global Event Cancelled',
                message: 'Admin has cancelled the event "${event.title}" scheduled for ${DateFormat('MMM d at h:mm a').format(event.dateTime)}.',
                type: 'global_event_cancellation',
                data: {
                  'eventTitle': event.title,
                  'eventDate': event.dateTime.toIso8601String(),
                  'adminName': appState.userData?.name ?? 'Admin',
                },
              );
            } catch (e) {
              print('Error sending event cancellation notification to ${userDoc.id}: $e');
            }
          }
        }
      } else {
        // Doctor event deletion
        // Get all mentees assigned to this doctor
        final menteesQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('doctorId', isEqualTo: appState.user!.uid)
            .get();
        
        final allMenteeIds = menteesQuery.docs.map((doc) => doc.id).toList();

        await FirebaseFirestore.instance
            .collection('doctor_events')
            .doc(event.id)
            .delete();
         
        // Send notification to all mentees of this doctor
        for (String menteeId in allMenteeIds) {
          try {
            await NotificationService.sendEventNotification(
              userId: menteeId,
              title: 'Event Cancelled',
              message: 'Dr. ${appState.userData?.name ?? event.createdBy} has cancelled the event "${event.title}" scheduled for ${DateFormat('MMM d at h:mm a').format(event.dateTime)}.',
              eventDate: event.dateTime,
              doctorName: appState.userData?.name ?? event.createdBy,
            );
          } catch (e) {
            print('Error sending event cancellation notification to $menteeId: $e');
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadCalendarEvents();
    } catch (e) {
      print('Error deleting event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting event: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDoctor = appState.userData?.role == 'doctor';
    final isAdmin = appState.userData?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (isDoctor || isAdmin) ...[
            IconButton(
              icon: Icon(Icons.add, color: isAdmin ? Colors.purple : Colors.green),
              onPressed: _showCreateEventDialog,
              tooltip: isAdmin ? 'Create Global Event' : 'Create Event',
            ),
          ],
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCalendarEvents,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: EdgeInsets.all(8),
                  elevation: 2,
                  child: TableCalendar<CalendarEvent>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    eventLoader: _getEventsForDay,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      weekendTextStyle: TextStyle(color: Colors.red[600]!),
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue[400],
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.blue[200],
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 3,
                      markerDecoration: BoxDecoration(
                        color: Colors.blue[700],
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      formatButtonShowsNext: false,
                      formatButtonDecoration: BoxDecoration(
                        color: Colors.blue[400],
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      formatButtonTextStyle: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      if (!isSameDay(_selectedDay, selectedDay)) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                          _selectedEvents = _getEventsForDay(selectedDay);
                        });
                      }
                    },
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      }
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isNotEmpty) {
                          return Positioned(
                            right: 1,
                            bottom: 1,
                            child: _buildEventsMarker(day, events),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20),
                      SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay ?? DateTime.now()),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      if (_selectedEvents.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedEvents.length} items',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(height: 1),
                Expanded(
                  child: _selectedEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No events on this day',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Your schedule is clear',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _selectedEvents.length,
                          itemBuilder: (context, index) {
                            return _buildEventCard(_selectedEvents[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventsMarker(DateTime day, List events) {
    final calendarEvents = events.whereType<CalendarEvent>().toList();
    
    bool hasAdminEvent = false;
    int taskCount = 0;
    int eventCount = 0;
    int medicationCount = 0;
    
    for (var event in calendarEvents) {
      switch (event.type) {
        case 'admin_event':
          hasAdminEvent = true;
          break;
        case 'task':
          taskCount++;
          break;
        case 'event':
          eventCount++;
          break;
        case 'medication':
          medicationCount++;
          break;
      }
    }
    
    Color markerColor;
    if (hasAdminEvent) {
      markerColor = Colors.purple[400]!;
    } else if (taskCount > 0 && calendarEvents.any((e) => e.type == 'task' && e.completed != true)) {
      markerColor = Colors.red[400]!;
    } else if (eventCount > 0) {
      markerColor = Colors.blue[400]!;
    } else if (medicationCount > 0) {
      markerColor = Colors.green[400]!;
    } else {
      markerColor = Colors.grey[400]!;
    }
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: markerColor,
      ),
      width: 7.0,
      height: 7.0,
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    final appState = Provider.of<AppState>(context);
    final isDoctor = appState.userData?.role == 'doctor';
    final isAdmin = appState.userData?.role == 'admin';
    
    Color cardColor;
    Color iconColor;
    IconData iconData;
    
    switch (event.type) {
      case 'admin_event':
        cardColor = Colors.purple[50]!;
        iconColor = Colors.purple[700]!;
        iconData = Icons.public;
        break;
      case 'task':
        cardColor = event.completed == true ? Colors.grey[100]! : Colors.red[50]!;
        iconColor = event.completed == true ? Colors.grey[600]! : Colors.red[700]!;
        iconData = Icons.assignment;
        break;
      case 'event':
        cardColor = Colors.blue[50]!;
        iconColor = Colors.blue[700]!;
        iconData = Icons.event;
        break;
      case 'medication':
        cardColor = Colors.green[50]!;
        iconColor = Colors.green[700]!;
        iconData = Icons.medication;
        break;
      default:
        cardColor = Colors.grey[50]!;
        iconColor = Colors.grey[700]!;
        iconData = Icons.calendar_today;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showEventDetails(event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: iconColor, size: 24),
              ),
              SizedBox(width: 16),
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
                              color: event.completed == true ? Colors.grey[600] : null,
                            ),
                          ),
                        ),
                        if (event.type == 'admin_event')
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'GLOBAL',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          DateFormat('h:mm a').format(event.dateTime),
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        if (event.priority != null) ...[
                          SizedBox(width: 12),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      ],
                    ),
                    if (event.description.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        event.description,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (event.type == 'task' && event.completed != true)
                IconButton(
                  icon: Icon(Icons.check_circle_outline, color: Colors.green),
                  onPressed: () => _markTaskCompleted(event),
                ),
              if (isDoctor && event.type == 'event' && event.createdBy == 'You')
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteEvent(event),
                  tooltip: 'Delete Event',
                ),
              if (isAdmin && event.type == 'admin_event')
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteEvent(event),
                  tooltip: 'Delete Global Event',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red[700]!;
      case 'medium':
        return Colors.orange[700]!;
      case 'low':
        return Colors.green[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  void _showEventDetails(CalendarEvent event) {
    final appState = Provider.of<AppState>(context, listen: false);
    final isDoctor = appState.userData?.role == 'doctor';
    final isAdmin = appState.userData?.role == 'admin';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(_getIconForType(event.type), color: _getEventColor(event.type)),
            SizedBox(width: 12),
            Expanded(child: Text(event.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                Icons.access_time,
                'Date & Time',
                DateFormat('EEEE, MMMM d, yyyy - h:mm a').format(event.dateTime),
              ),
              if (event.description.isNotEmpty) ...[
                SizedBox(height: 12),
                _buildDetailRow(
                  Icons.description,
                  'Description',
                  event.description,
                ),
              ],
              SizedBox(height: 12),
              _buildDetailRow(
                Icons.person,
                'Created by',
                event.createdBy,
              ),
              if (event.type == 'admin_event') ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.public, size: 20, color: Colors.purple[700]),
                      SizedBox(width: 8),
                      Text(
                        'Global Event - Visible to all users',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (event.priority != null) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.flag, size: 20, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      'Priority: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(event.priority!).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.priority!,
                        style: TextStyle(
                          color: _getPriorityColor(event.priority!),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (event.attendees != null && event.attendees!.isNotEmpty) ...[
                SizedBox(height: 12),
                _buildDetailRow(
                  Icons.group,
                  'Attendees',
                  '${event.attendees!.length} people invited',
                ),
              ],
              if (event.completed == true) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Colors.green[700]),
                      SizedBox(width: 8),
                      Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (event.type == 'task' && event.completed != true)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _markTaskCompleted(event);
              },
              icon: Icon(Icons.check),
              label: Text('Mark Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          if (isDoctor && event.type == 'event' && event.createdBy == 'You')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _deleteEvent(event);
              },
              icon: Icon(Icons.delete),
              label: Text('Delete Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          if (isAdmin && event.type == 'admin_event')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _deleteEvent(event);
              },
              icon: Icon(Icons.delete),
              label: Text('Delete Global Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'admin_event':
        return Icons.public;
      case 'task':
        return Icons.assignment;
      case 'event':
        return Icons.event;
      case 'medication':
        return Icons.medication;
      default:
        return Icons.calendar_today;
    }
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'admin_event':
        return Colors.purple[700]!;
      case 'task':
        return Colors.red[700]!;
      case 'event':
        return Colors.blue[700]!;
      case 'medication':
        return Colors.green[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  Future<void> _markTaskCompleted(CalendarEvent event) async {
    try {
      await FirebaseFirestore.instance
          .collection('mentee_tasks')
          .doc(event.id)
          .update({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task marked as completed!'),
          backgroundColor: Colors.green,
        ),
      );

      _loadCalendarEvents();
    } catch (e) {
      print('Error marking task completed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Admin Event Creation Dialog
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

// Dialog for creating events (doctors)
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