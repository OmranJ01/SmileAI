import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'admin_dashboard_screen.dart';
import '../common/notifications_screen.dart';
import '../common/settings_screen.dart';
import '../../Providers/app_state.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  _AdminHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  int _unreadNotificationCount = 0;
  StreamSubscription? _notificationSubscription;

  static final List<Widget> _screens = [
    AdminDashboardScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupNotificationBadgeListener();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupNotificationBadgeListener() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;

    print('🔔 Setting up notification badge listener for admin ${appState.user!.uid}');

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: appState.user!.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = snapshot.docs.length;
        });
        print('🔔 Unread notifications: $_unreadNotificationCount');
      }
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openNotifications() async {
    // Navigate to notifications screen
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotificationsScreen()),
    );
    
    // Mark notifications as read after a delay when returning from notifications screen
    if (_unreadNotificationCount > 0) {
      print('📖 User returned from notifications, will mark as read...');
      _markNotificationsAsReadWithDelay();
    }
  }

  void _markNotificationsAsReadWithDelay() async {
    // Wait a bit for the user to see the notifications
    await Future.delayed(Duration(seconds: 2));
    
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;

    try {
      // Get unread notifications
      final unreadNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: appState.user!.uid)
          .where('read', isEqualTo: false)
          .get();

      if (unreadNotifications.docs.isNotEmpty) {
        print('📖 Marking ${unreadNotifications.docs.length} notifications as read...');
        
        final batch = FirebaseFirestore.instance.batch();
        
        for (final doc in unreadNotifications.docs) {
          batch.update(doc.reference, {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
        
        await batch.commit();
        print('✅ All notifications marked as read');
      }
    } catch (e) {
      print('❌ Error marking notifications as read: $e');
    }
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        Icon(Icons.notifications),
        if (_unreadNotificationCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: BoxConstraints(
                minWidth: 12,
                minHeight: 12,
              ),
              child: Text(
                _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Admin Dashboard';
      case 1:
        return 'Settings';
      default:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
   // ...existing code...
appBar: AppBar(
  title: Text(_getAppBarTitle()),
  actions: [
    // Notifications button
    IconButton(
      icon: _buildNotificationIcon(),
      onPressed: _openNotifications,
      tooltip: 'Notifications',
    ),
    // Sign out button
    IconButton(
      icon: Icon(Icons.exit_to_app),
      onPressed: () async {
        final shouldSignOut = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Sign Out'),
            content: Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Sign Out'),
              ),
            ],
          ),
        );
        if (shouldSignOut == true) {
          await appState.signOut();
        }
      },
      tooltip: 'Sign Out',
    ),
  ],
),
//
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}