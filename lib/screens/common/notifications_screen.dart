import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../Providers/app_state.dart';
import '../../models/notifications.dart';
import '../../services/notification_service.dart';
import '../common/chatScreen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with TickerProviderStateMixin {
  StreamSubscription? _notificationsSubscription;
  List<MyNotification> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _setupRealTimeNotificationsListener(); // FIXED: Real-time listener
  }
  
  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }
  
  // FIXED: Real-time notifications listener with immediate updates
  void _setupRealTimeNotificationsListener() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;
    
    print('🔔 Setting up REAL-TIME notifications listener');
    
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: appState.user!.uid)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        print('🔔 Real-time notification update: ${snapshot.docs.length} notifications');
        
        setState(() {
          _notifications = snapshot.docs
              .map((doc) => MyNotification.fromMap(doc.data(), doc.id))
              .toList();
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('❌ Error in real-time notifications: $error');
      setState(() {
        _isLoading = false;
      });
    });
  }
  
  // IMPROVED: Instant read marking without delay
  Future<void> _markAsRead(String notificationId) async {
    try {
      print('📖 Marking notification as read: $notificationId');
      
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Notification marked as read successfully');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }
  
  // IMPROVED: Instant mark all as read
  Future<void> _markAllAsRead() async {
    try {
      final unreadNotifications = _notifications.where((n) => !n.read).toList();
      
      if (unreadNotifications.isEmpty) {
        _showSnackBar('No unread notifications', Colors.orange);
        return;
      }
      
      print('📖 Marking ${unreadNotifications.length} notifications as read...');
      
      // Batch update for performance
      final batch = FirebaseFirestore.instance.batch();
      
      for (final notification in unreadNotifications) {
        batch.update(
          FirebaseFirestore.instance.collection('notifications').doc(notification.id),
          {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          }
        );
      }
      
      await batch.commit();
      
      _showSnackBar('All notifications marked as read', Colors.green);
      print('✅ All notifications marked as read');
    } catch (e) {
      print('❌ Error marking all as read: $e');
      _showSnackBar('Failed to mark all as read', Colors.red);
    }
  }
  
  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      _showSnackBar('Notification deleted', Colors.green);
    } catch (e) {
      print('❌ Error deleting notification: $e');
      _showSnackBar('Failed to delete notification', Colors.red);
    }
  }
  
  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Notifications'),
        content: Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
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
            child: Text('Clear All'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        // Batch delete for performance
        final batch = FirebaseFirestore.instance.batch();
        
        for (final notification in _notifications) {
          batch.delete(
            FirebaseFirestore.instance.collection('notifications').doc(notification.id)
          );
        }
        
        await batch.commit();
        
        _showSnackBar('All notifications cleared', Colors.green);
      } catch (e) {
        print('❌ Error clearing notifications: $e');
        _showSnackBar('Failed to clear notifications', Colors.red);
      }
    }
  }
  
  void _handleNotificationTap(MyNotification notification) async {
    // Mark as read immediately when tapped
    if (!notification.read) {
      await _markAsRead(notification.id);
    }
    
    // Handle different notification types
    switch (notification.type) {
      case 'message':
        if (notification.data != null && notification.data!['senderId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                recipientId: notification.data!['senderId'],
                recipientName: notification.data!['senderName'] ?? 'User',
              ),
            ),
          );
        }
        break;
        
      case 'appointment':
        _showSnackBar('Opening appointment details...', Colors.blue);
        break;
        
      case 'assignment':
        _showSnackBar('Assignment notification handled', Colors.blue);
        break;
        
      case 'reminder':
        _showSnackBar('Reminder notification handled', Colors.blue);
        break;
        
      default:
        _showSnackBar('Notification opened', Colors.blue);
    }
  }
  
  List<MyNotification> get _filteredNotifications {
    switch (_selectedFilter) {
      case 'unread':
        return _notifications.where((n) => !n.read).toList();
      case 'messages':
        return _notifications.where((n) => n.type == 'message').toList();
      case 'appointments':
        return _notifications.where((n) => n.type == 'appointment').toList();
      case 'system':
        return _notifications.where((n) => ['assignment', 'promotion', 'system'].contains(n.type)).toList();
      default:
        return _notifications;
    }
  }
  
  Widget _buildNotificationItem(MyNotification notification) {
    final isUnread = !notification.read;
    
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        color: Colors.red,
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteNotification(notification.id);
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: isUnread ? 2 : 0.5,
        color: isUnread 
            ? Theme.of(context).cardColor
            : Theme.of(context).cardColor.withOpacity(0.7),
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon section
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isUnread 
                            ? _getNotificationColor(notification.type).withOpacity(0.15)
                            : Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getNotificationIcon(notification.type),
                        color: isUnread 
                            ? _getNotificationColor(notification.type)
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                    if (isUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).cardColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 16),
                // Content section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title ?? _getDefaultTitle(notification.type),
                        style: TextStyle(
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                          color: isUnread 
                              ? Theme.of(context).textTheme.bodyLarge?.color 
                              : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: isUnread 
                              ? Theme.of(context).textTheme.bodyMedium?.color 
                              : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatTimestamp(notification.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                          if (notification.type != null) ...[
                            SizedBox(width: 12),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isUnread
                                    ? _getNotificationColor(notification.type).withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                notification.type!.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isUnread
                                      ? _getNotificationColor(notification.type)
                                      : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Action menu
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'message':
        return Icons.message;
      case 'appointment':
        return Icons.event;
      case 'assignment':
        return Icons.assignment;
      case 'promotion':
        return Icons.celebration;
      case 'reminder':
        return Icons.alarm;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }
  
  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'message':
        return Colors.blue;
      case 'appointment':
        return Colors.green;
      case 'assignment':
        return Colors.orange;
      case 'promotion':
        return Colors.purple;
      case 'reminder':
        return Colors.red;
      case 'system':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
  
  String _getDefaultTitle(String? type) {
    switch (type) {
      case 'message':
        return 'New Message';
      case 'appointment':
        return 'Appointment';
      case 'assignment':
        return 'New Assignment';
      case 'promotion':
        return 'Congratulations!';
      case 'reminder':
        return 'Reminder';
      case 'system':
        return 'System Notification';
      default:
        return 'Notification';
    }
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(messageTime);
    }
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.read).length;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Notifications'),
            if (unreadCount > 0) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount new',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All (${_notifications.length})'),
            Tab(text: 'Unread ($unreadCount)'),
            Tab(text: 'Messages'),
            Tab(text: 'System'),
          ],
          onTap: (index) {
            setState(() {
              switch (index) {
                case 0:
                  _selectedFilter = 'all';
                  break;
                case 1:
                  _selectedFilter = 'unread';
                  break;
                case 2:
                  _selectedFilter = 'messages';
                  break;
                case 3:
                  _selectedFilter = 'system';
                  break;
              }
            });
          },
        ),
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: Icon(Icons.mark_email_read),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _filteredNotifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _filteredNotifications.length,
                  itemBuilder: (context, index) {
                    return _buildNotificationItem(_filteredNotifications[index]);
                  },
                ),
    );
  }
  
  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    switch (_selectedFilter) {
      case 'unread':
        message = 'No unread notifications';
        icon = Icons.mark_email_read;
        break;
      case 'messages':
        message = 'No message notifications';
        icon = Icons.message;
        break;
      case 'system':
        message = 'No system notifications';
        icon = Icons.info;
        break;
      default:
        message = 'No notifications yet';
        icon = Icons.notifications_none;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            _selectedFilter == 'all' 
              ? 'You\'re all caught up!'
              : 'Switch to another tab to see more notifications',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}