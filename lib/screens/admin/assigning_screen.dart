import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_data.dart';
import '../../Providers/app_state.dart';

class AssignMenteeScreen extends StatefulWidget {
  final bool isToDoctor; // true if assigning to doctor, false if to mentor
  
  const AssignMenteeScreen({super.key, required this.isToDoctor});
  
  @override
  _AssignMenteeScreenState createState() => _AssignMenteeScreenState();
}


class AssignMenteeListScreen extends StatelessWidget {
  const AssignMenteeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign a Mentee'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search mentees...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            
            Expanded(
              child: appState.isLoading
                ? Center(child: CircularProgressIndicator())
                // FIXED: Only show approved mentees assigned to current doctor
                : appState.mentees.where((m) => m.approved && m.doctorId == appState.user?.uid).isEmpty
                  ? Center(child: Text('No approved mentees assigned to you'))
                  : ListView.builder(
                      itemCount: appState.mentees.where((m) => m.approved && m.doctorId == appState.user?.uid).length,
                      itemBuilder: (context, index) {
                        final menteesList = appState.mentees.where((m) => m.approved && m.doctorId == appState.user?.uid).toList();
                        final mentee = menteesList[index];
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(mentee.name[0]),
                          ),
                          title: Text(mentee.name),
                          subtitle: Text(mentee.email),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AssignMentorScreen(mentee: mentee),
                                ),
                              );
                            },
                            child: Text('Assign'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


class _AssignMenteeScreenState extends State<AssignMenteeScreen> {
  String _searchQuery = '';
  final bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    // FIXED: Only show approved mentees
    final mentees = [
  ...appState.mentees.where((m) => m.approved),
  ...appState.mentors.where((m) => m.approved),
];

    // Filter mentees based on search query
    final filteredMentees = mentees.where((mentee) => 
      _searchQuery.isEmpty || 
      mentee.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      mentee.email.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isToDoctor ? 'Assign to Doctor' : 'Assign to Mentor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search approved mentees...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            SizedBox(height: 16),
            
            Text(
              'Select an approved mentee to assign',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            Expanded(
              child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredMentees.isEmpty
                  ? Center(
                      child: Text('No approved mentees found'),
                    )
                  : ListView.builder(
                      itemCount: filteredMentees.length,
                      itemBuilder: (context, index) {
                        final mentee = filteredMentees[index];
                        
                        // Check if mentee already has a doctor/mentor assigned
                        final bool hasAssignee = widget.isToDoctor 
                            ? mentee.doctorId != null 
                            : mentee.mentorId != null;
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: Text(
                                mentee.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(mentee.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(mentee.email),
                                // Show approval status
                                Text(
                                  'Approved ✓',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (hasAssignee)
                                  Text(
                                    widget.isToDoctor 
                                        ? 'Already has a doctor assigned' 
                                        : 'Already has a mentor assigned',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => widget.isToDoctor
                                      ? SelectDoctorScreen(menteeId: mentee.uid)
                                        : SelectMentorScreen(menteeId: mentee.uid),
                                  ),
                                ).then((_) {
                                  // Refresh the UI when returning from selection screen
                                  setState(() {});
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasAssignee ? Colors.orange : Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: hasAssignee ? Text('Reassign') : Text('Assign'),
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
    );
  }
}


class SelectDoctorScreen extends StatefulWidget {
  final String menteeId;
  
  const SelectDoctorScreen({super.key, required this.menteeId});

  @override
  _SelectDoctorScreenState createState() => _SelectDoctorScreenState();
}

class _SelectDoctorScreenState extends State<SelectDoctorScreen> {
  String _searchQuery = '';
  bool _isAssigning = false;
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // FIXED: Filter doctors to only show approved ones
    final filteredDoctors = appState.doctors.where((doctor) => 
      doctor.approved && (
        _searchQuery.isEmpty || 
        doctor.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        doctor.email.toLowerCase().contains(_searchQuery.toLowerCase())
      )
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Doctor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select an approved doctor to assign to the mentee',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            TextField(
              decoration: InputDecoration(
                hintText: 'Search approved doctors...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            SizedBox(height: 16),
            
            Expanded(
              child: filteredDoctors.isEmpty
                ? Center(
                    child: Text('No approved doctors available'),
                  )
                : ListView.builder(
                    itemCount: filteredDoctors.length,
                    itemBuilder: (context, index) {
                      final doctor = filteredDoctors[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: Text(
                              doctor.name[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text('Dr. ${doctor.name}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(doctor.email),
                              Text(
                                'Approved ✓',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                             onPressed: _isAssigning
  ? null
  : () async {
      setState(() {
        _isAssigning = true;
      });
      
      try {
        // Assign doctor to mentee
        await FirebaseFirestore.instance.collection('users').doc(widget.menteeId).update({
          'doctorId': doctor.uid
        });
        
        // Create notifications for mentee and doctor - these are important for alerting both parties
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': widget.menteeId,
          'message': 'You have been assigned to Dr. ${doctor.name}',
          'timestamp': Timestamp.now(),
          'read': false
        });
        
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': doctor.uid,
          'message': 'A new mentee has been assigned to you',
          'timestamp': Timestamp.now(),
          'read': false
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Doctor assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload mentees list
        await appState.loadMentees();
        
        // Navigate back
        Navigator.pop(context);
      } catch (e) {
        print('Error assigning doctor: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign doctor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isAssigning = false;
        });
      }
    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: Size(80, 36),
                            ),
                            child: _isAssigning
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text('Assign'),
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
    );
  }
}


class SelectMentorScreen extends StatelessWidget {
  final String menteeId;
  
  const SelectMentorScreen({super.key, required this.menteeId});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // FIXED: Only show approved mentors
    final approvedMentors = appState.mentors.where((mentor) => mentor.approved).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Mentor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select an approved mentor to assign to the mentee',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            Expanded(
              child: approvedMentors.isEmpty
                ? Center(
                    child: Text('No approved mentors available'),
                  )
                : ListView.builder(
                    itemCount: approvedMentors.length,
                    itemBuilder: (context, index) {
                      final mentor = approvedMentors[index];
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
                          title: Text(mentor.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(mentor.email),
                              Text(
                                'Approved ✓',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              await appState.assignMenteeToMentor(menteeId, mentor.uid);
                              Navigator.pop(context);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Mentee assigned to mentor successfully')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('+ Assign'),
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
    );
  }
}

class AssignMentorScreen extends StatefulWidget {
  final UserData mentee;
  
  const AssignMentorScreen({super.key, required this.mentee});
  
  @override
  _AssignMentorScreenState createState() => _AssignMentorScreenState();
}

class _AssignMentorScreenState extends State<AssignMentorScreen> {
  String _searchQuery = '';
  bool _isAssigning = false;
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    // ALREADY FIXED: Filter mentors to only show approved ones (this was already correct)
    final filteredMentors = appState.mentors.where((mentor) => 
      mentor.approved && (
        _searchQuery.isEmpty || 
        mentor.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        mentor.email.toLowerCase().contains(_searchQuery.toLowerCase())
      )
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Mentor'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header text showing which mentee we're assigning a mentor to
            Text(
              'Assign approved mentor to ${widget.mentee.name}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search approved mentors...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            SizedBox(height: 16),
            
            // List of mentors
            Expanded(
              child: appState.isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredMentors.isEmpty
                  ? Center(child: Text('No approved mentors available'))
                  : ListView.builder(
                      itemCount: filteredMentors.length,
                      itemBuilder: (context, index) {
                        final mentor = filteredMentors[index];
                        
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
                            title: Text(mentor.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mentor'),
                                Text(
                                  'Approved ✓',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Mentees: ${appState.mentees.where((m) => m.approved && m.mentorId == mentor.uid).length}',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: _isAssigning
                                ? null
                                : () async {
                                    setState(() {
                                      _isAssigning = true;
                                    });
                                    
                                    try {
                                      if (appState.isDoctor) {
                                        // Use the specialized method if the current user is a doctor
                                        await appState.assignMentorToMenteeByDoctor(
                                          widget.mentee.uid,
                                          mentor.uid,
                                        );
                                      } else {
                                        // Admin assignment
                                        await appState.assignMenteeToMentor(
                                          widget.mentee.uid,
                                          mentor.uid,
                                        );
                                      }
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${widget.mentee.name} assigned to ${mentor.name}'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      
                                      Navigator.pop(context);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to assign mentor: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } finally {
                                      setState(() {
                                        _isAssigning = false;
                                      });
                                    }
                                  },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: _isAssigning
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text('+ Assign'),
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
    );
  }
}