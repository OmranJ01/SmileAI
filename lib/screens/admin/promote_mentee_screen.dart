import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/app_state.dart';

class PromoteMenteeScreen extends StatelessWidget {
  const PromoteMenteeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    // Filter to show only approved mentees
    final approvedMentees = appState.mentees.where((mentee) => mentee.approved).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Promote Mentee to Mentor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search mentees...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: approvedMentees.length,
                itemBuilder: (context, index) {
                  final mentee = approvedMentees[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Text(mentee.name[0]),
                    ),
                    title: Text(mentee.name),
                    subtitle: Text(mentee.email),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        // Show confirmation dialog
                        bool confirm = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Confirm Promotion'),
                            content: Text('Are you sure you want to promote ${mentee.name} to mentor status?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Promote'),
                              ),
                            ],
                          ),
                        ) ?? false;
                        
                        if (confirm) {
                          // Show loading state
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => AlertDialog(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Promoting ${mentee.name} to mentor...'),
                                ],
                              ),
                            ),
                          );
                          
                          try {
                            await appState.promoteMenteeToMentor(mentee.uid);
                            
                            // Close loading dialog
                            Navigator.pop(context);
                            
                            // Close promotion screen
                            Navigator.pop(context);
                            
                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.celebration, color: Colors.white),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${mentee.name} has been promoted to mentor!',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          } catch (e) {
                            // Close loading dialog
                            Navigator.pop(context);
                            
                            // Show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error promoting mentee: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Text('Promote'),
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