class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String type; // 'task', 'event', 'medication'
  final String createdBy;
  final String? priority; // For tasks: 'High', 'Medium', 'Low'
  final bool? completed; // For tasks
  final List<String>? attendees; // For events

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.type,
    required this.createdBy,
    this.priority,
    this.completed,
    this.attendees,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> data, String id) {
    return CalendarEvent(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dateTime: data['dateTime']?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'event',
      createdBy: data['createdBy'] ?? '',
      priority: data['priority'],
      completed: data['completed'],
      attendees: data['attendees'] != null ? List<String>.from(data['attendees']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dateTime': dateTime,
      'type': type,
      'createdBy': createdBy,
      'priority': priority,
      'completed': completed,
      'attendees': attendees,
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? type,
    String? createdBy,
    String? priority,
    bool? completed,
    List<String>? attendees,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      type: type ?? this.type,
      createdBy: createdBy ?? this.createdBy,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      attendees: attendees ?? this.attendees,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarEvent && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CalendarEvent(id: $id, title: $title, type: $type, dateTime: $dateTime)';
  }
}