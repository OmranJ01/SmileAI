import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'doctor_dashboard_screen.dart';
import 'doctor_chat_screen.dart';
import '../common/discover_screen.dart';
import '../common/notifications_screen.dart';
import '../common/settings_screen.dart';
import '../../Providers/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  _DoctorHomeScreenState createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _selectedIndex = 0;
  int _unreadNotificationCount = 0;
  int _newArticlesCount = 0; // NEW: Articles badge counter
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _articlesSubscription; // NEW: Articles subscription

  // Create screens for the doctor's bottom navigation
  late final List<Widget> _screens;
  
  // Define tab titles
  final List<String> _tabTitles = [
    'Dashboard',
    'Messages',
    'Discover',
    'Notifications',
  ];
  
  @override
  void initState() {
    super.initState();
    _screens = [
      DoctorDashboardScreen(),
      DoctorChatScreen(),     // Messages tab
      DiscoverScreen(),       // Discover tab for articles
      NotificationsScreen(),  // Notifications tab
    ];
    _setupNotificationBadgeListener();
    _setupArticlesBadgeListener(); // NEW: Setup articles badge
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _articlesSubscription?.cancel(); // NEW: Cancel articles subscription
    super.dispose();
  }

  void _setupNotificationBadgeListener() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;

    print('🔔 Setting up notification badge listener for doctor ${appState.user!.uid}');

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

  // NEW: Setup articles badge listener
  void _setupArticlesBadgeListener() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenArticleTime = prefs.getInt('last_seen_article_time') ?? 0;
    final lastSeenTimestamp = Timestamp.fromMillisecondsSinceEpoch(lastSeenArticleTime);

    print('📰 Setting up articles badge listener');
    print('📰 Last seen article time: ${DateTime.fromMillisecondsSinceEpoch(lastSeenArticleTime)}');

    _articlesSubscription = FirebaseFirestore.instance
        .collection('articles')
        .where('createdAt', isGreaterThan: lastSeenTimestamp)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _newArticlesCount = snapshot.docs.length;
        });
        print('📰 New articles count: $_newArticlesCount');
      }
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // If user tapped on notifications tab, mark all as read after a short delay
    if (index == 3 && _unreadNotificationCount > 0) {
      print('📖 User opened notifications tab, will mark as read...');
      _markNotificationsAsReadWithDelay();
    }

    // NEW: If user tapped on discover tab (articles), clear articles badge
    if (index == 2 && _newArticlesCount > 0) {
      print('📰 User opened discover tab, clearing articles badge...');
      _clearArticlesBadge();
    }
  }

  // NEW: Clear articles badge when user opens discover
  void _clearArticlesBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('last_seen_article_time', now);
      
      setState(() {
        _newArticlesCount = 0;
      });
      
      print('📰 Articles badge cleared');
    } catch (e) {
      print('❌ Error clearing articles badge: $e');
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

  // NEW: Build articles icon with badge
  Widget _buildArticlesIcon() {
    return Stack(
      children: [
        Icon(Icons.article),
        if (_newArticlesCount > 0)
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
                _newArticlesCount > 99 ? '99+' : '$_newArticlesCount',
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

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
     // ...existing code...
appBar: AppBar(
  title: Text(_tabTitles[_selectedIndex]), // Dynamic title based on selected tab
  actions: [
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
    ),
  ],
),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: _buildArticlesIcon(), // NEW: Articles icon with badge
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: _buildNotificationIcon(),
            label: 'Notifications',
          ),
        ],
      ),
    );
  }
}