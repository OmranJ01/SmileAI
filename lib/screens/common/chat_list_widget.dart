import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../models/messages.dart';
import '../../models/user_data.dart';
import '../common/chatScreen.dart';
import '../../services/chat_service.dart';

class ChatListWidget extends StatefulWidget {
  final List<UserData> users;
  final String currentUserId;
  final String userType;
  final Function(UserData)? onUserTap;
  final Function(UserData)? onUserLongPress;
  final bool showLastMessage;
  final bool showUnreadCount;
  final bool refreshable;
  
  const ChatListWidget({super.key, 
    required this.users,
    required this.currentUserId,
    required this.userType,
    this.onUserTap,
    this.onUserLongPress,
    this.showLastMessage = true,
    this.showUnreadCount = true,
    this.refreshable = true,
  });
  
  @override
  _ChatListWidgetState createState() => _ChatListWidgetState();
}

class _ChatListWidgetState extends State<ChatListWidget> with AutomaticKeepAliveClientMixin {
  final Map<String, Message?> _lastMessages = {};
  final Map<String, int> _unreadCounts = {};
  final Map<String, StreamSubscription> _messageStreams = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  @override
  void didUpdateWidget(ChatListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.users.length != widget.users.length ||
        !_areUserListsEqual(oldWidget.users, widget.users)) {
      _disposeStreams();
      _initializeData();
    }
  }
  
  bool _areUserListsEqual(List<UserData> list1, List<UserData> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].uid != list2[i].uid) return false;
    }
    return true;
  }
  
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _lastMessages.clear();
      _unreadCounts.clear();
    });
    
    // Load initial data
    await _loadInitialData();
    
    // Set up real-time listeners
    _setupRealTimeListeners();
    
    // Start periodic refresh
    _startPeriodicRefresh();
    
    setState(() {
      _isLoading = false;
    });
  }
  
  Future<void> _loadInitialData() async {
    print('🔄 Loading initial chat data...');
    
    for (final user in widget.users) {
      try {
        // Load last message
        if (widget.showLastMessage) {
          final lastMessage = await ChatService.getLastMessage(
            userId1: widget.currentUserId,
            userId2: user.uid,
          );
          if (mounted) {
            setState(() {
              _lastMessages[user.uid] = lastMessage;
            });
            print('✅ Loaded last message for ${user.name}: ${lastMessage?.content ?? 'No message'}');
          }
        }
        
        // Load unread count
        if (widget.showUnreadCount) {
          final unreadCount = await ChatService.getUnreadMessageCount(
            senderId: user.uid,
            recipientId: widget.currentUserId,
          );
          if (mounted) {
            setState(() {
              _unreadCounts[user.uid] = unreadCount;
            });
            print('✅ Loaded unread count for ${user.name}: $unreadCount');
          }
        }
      } catch (e) {
        print('❌ Error loading data for ${user.name}: $e');
      }
    }
  }
  
  void _setupRealTimeListeners() {
    print('🔄 Setting up real-time listeners...');
    
    for (final user in widget.users) {
      // Listen to messages between current user and this user
      _messageStreams[user.uid] = FirebaseFirestore.instance
          .collection('messages')
          .where('participants', arrayContains: widget.currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots()
          .listen((snapshot) {
        _processMessageUpdates(user.uid, snapshot);
      }, onError: (error) {
        print('❌ Error in message stream for ${user.uid}: $error');
      });
    }
  }
  
  void _processMessageUpdates(String userId, QuerySnapshot snapshot) {
    if (!mounted) return;
    
    Message? lastMessage;
    int unreadCount = 0;
    
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        
        // Check if this message involves the current user and the specific user
        if (participants.contains(widget.currentUserId) && 
            participants.contains(userId) && 
            participants.length == 2) {
          
          final isDeleted = data['isDeleted'] ?? false;
          final deletedBy = List<String>.from(data['deletedBy'] ?? []);
          
          if (!isDeleted && !deletedBy.contains(widget.currentUserId)) {
            final message = Message.fromMap(data, doc.id);
            
            // Get the most recent message
            if (lastMessage == null || message.timestamp.compareTo(lastMessage.timestamp) > 0) {
              lastMessage = message;
            }
            
            // Count unread messages from this user to current user
            if (message.senderId == userId && 
                message.recipientId == widget.currentUserId && 
                !message.read) {
              unreadCount++;
            }
          }
        }
      } catch (e) {
        print('❌ Error processing message: $e');
      }
    }
    
    // Update state
    setState(() {
      _lastMessages[userId] = lastMessage;
      _unreadCounts[userId] = unreadCount;
    });
    
    print('📨 Updated for $userId: lastMessage=${lastMessage?.content ?? 'none'}, unread=$unreadCount');
  }
  
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshData();
      }
    });
  }
  
  Future<void> _refreshData() async {
    if (!mounted) return;
    
    print('🔄 Refreshing chat list data...');
    
    for (final user in widget.users) {
      try {
        if (widget.showLastMessage) {
          final lastMessage = await ChatService.getLastMessage(
            userId1: widget.currentUserId,
            userId2: user.uid,
          );
          if (mounted) {
            setState(() {
              _lastMessages[user.uid] = lastMessage;
            });
          }
        }
        
        if (widget.showUnreadCount) {
          final unreadCount = await ChatService.getUnreadMessageCount(
            senderId: user.uid,
            recipientId: widget.currentUserId,
          );
          if (mounted) {
            setState(() {
              _unreadCounts[user.uid] = unreadCount;
            });
          }
        }
      } catch (e) {
        print('❌ Error refreshing data for ${user.name}: $e');
      }
    }
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _disposeStreams();
    super.dispose();
  }
  
  void _disposeStreams() {
    for (var stream in _messageStreams.values) {
      stream.cancel();
    }
    _messageStreams.clear();
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);
    
    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat('EEEE').format(messageTime);
      } else {
        return DateFormat('MMM d').format(messageTime);
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }
  
  Color _getUserTypeColor(UserData user) {
    if (widget.userType == 'care_team') {
      switch (user.role) {
        case 'doctor':
          return Colors.blue;
        case 'mentor':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }
    
    switch (widget.userType) {
      case 'doctor':
        return Colors.blue;
      case 'mentor':
        return Colors.green;
      case 'mentee':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  
  String _getUserTypeLabel(UserData user) {
    if (widget.userType == 'care_team') {
      switch (user.role) {
        case 'doctor':
          return 'Doctor';
        case 'mentor':
          return 'Mentor';
        default:
          return 'Care Team';
      }
    }
    
    switch (widget.userType) {
      case 'doctor':
        return 'Doctor';
      case 'mentor':
        return 'Mentor';
      case 'mentee':
        return 'Mentee';
      default:
        return 'User';
    }
  }
  
  IconData _getUserIcon(UserData user) {
    if (widget.userType == 'care_team') {
      switch (user.role) {
        case 'doctor':
          return Icons.medical_services;
        case 'mentor':
          return Icons.psychology;
        default:
          return Icons.person;
      }
    }
    
    switch (widget.userType) {
      case 'doctor':
        return Icons.medical_services;
      case 'mentor':
        return Icons.psychology;
      case 'mentee':
        return Icons.person;
      default:
        return Icons.person;
    }
  }
  
  Widget _buildChatItem(UserData user) {
    final lastMessage = _lastMessages[user.uid];
    final unreadCount = _unreadCounts[user.uid] ?? 0;
    final primaryColor = _getUserTypeColor(user);
    final userLabel = _getUserTypeLabel(user);
    final userIcon = _getUserIcon(user);
    final isDoctor = user.role == 'doctor';
    final hasUnread = unreadCount > 0;
    final hasConversation = lastMessage != null;
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: hasUnread ? 2 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: hasUnread ? Colors.blue[50] : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Immediate unread count reset
          final int currentUnreadCount = _unreadCounts[user.uid] ?? 0;
          
          if (currentUnreadCount > 0) {
            setState(() {
              _unreadCounts[user.uid] = 0;
            });
            
            // Mark as read in background
            ChatService.markMessagesAsRead(
              senderId: user.uid,
              recipientId: widget.currentUserId,
            ).then((_) {
              print('✅ Messages marked as read for ${user.name}');
            }).catchError((error) {
              print('❌ Error marking messages as read: $error');
              if (mounted) {
                setState(() {
                  _unreadCounts[user.uid] = currentUnreadCount;
                });
              }
            });
          }
          
          if (widget.onUserTap != null) {
            widget.onUserTap!(user);
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  recipientId: user.uid,
                  recipientName: user.name,
                ),
              ),
            );
            
            // Refresh data when returning from chat
            if (mounted) {
              await _refreshData();
            }
          }
        },
        onLongPress: () {
          if (widget.onUserLongPress != null) {
            widget.onUserLongPress!(user);
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with unread badge
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.1),
                    radius: 28,
                    child: user.photoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.network(
                            user.photoUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(userIcon, color: primaryColor, size: 28);
                            },
                          ),
                        )
                      : Icon(userIcon, color: primaryColor, size: 28),
                  ),
                  // Unread counter
                  if (hasUnread && widget.showUnreadCount)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  // Online status
                  if (!hasUnread)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: DateTime.now().millisecond % 2 == 0 ? Colors.green : Colors.grey[400],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              
              SizedBox(width: 16),
              
              // User info and message preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and timestamp row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isDoctor ? 'Dr. ${user.name}' : user.name,
                            style: TextStyle(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 17,
                              color: hasUnread ? Colors.black : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Show timestamp only if there's a conversation
                        if (hasConversation && widget.showLastMessage)
                          Text(
                            _formatTimestamp(lastMessage.timestamp),
                            style: TextStyle(
                              color: hasUnread ? Colors.green[600] : Colors.grey[500],
                              fontSize: 13,
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    
                    SizedBox(height: 6),
                    
                    // Role badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        userLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    
                    if (widget.showLastMessage) ...[
                      SizedBox(height: 8),
                      
                      // Last message preview
                      Row(
                        children: [
                          Expanded(
                            child: hasConversation
                              ? Row(
                                  children: [
                                    // Sender indicator
                                    if (lastMessage.senderId == widget.currentUserId)
                                      Icon(
                                        Icons.reply,
                                        size: 14,
                                        color: hasUnread ? Colors.blue : Colors.grey[600],
                                      ),
                                    if (lastMessage.senderId == widget.currentUserId)
                                      SizedBox(width: 4),
                                    
                                    Expanded(
                                      child: Text(
                                        lastMessage.isDeleted 
                                            ? '🚫 This message was deleted'
                                            : lastMessage.content,
                                        style: TextStyle(
                                          color: lastMessage.isDeleted 
                                              ? Colors.grey[500]
                                              : hasUnread 
                                                  ? Colors.black87
                                                  : Colors.grey[700],
                                          fontSize: 14,
                                          fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                          fontStyle: lastMessage.isDeleted ? FontStyle.italic : FontStyle.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Tap to start chatting',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                          ),
                          
                          // Read receipt for sent messages
                          if (hasConversation && 
                              !lastMessage.isDeleted && 
                              lastMessage.senderId == widget.currentUserId)
                            Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                lastMessage.read ? Icons.done_all : Icons.done,
                                size: 16,
                                color: lastMessage.read ? Colors.blue : Colors.grey[400],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading conversations...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    if (widget.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              widget.userType == 'care_team' 
                  ? 'No care team members yet'
                  : 'No conversations yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              widget.userType == 'care_team'
                  ? 'Your care team will be assigned soon'
                  : 'Start chatting with your ${widget.userType}s',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    // Sort users: unread first, then by last message time
    final sortedUsers = List<UserData>.from(widget.users);
    sortedUsers.sort((a, b) {
      final aUnread = _unreadCounts[a.uid] ?? 0;
      final bUnread = _unreadCounts[b.uid] ?? 0;
      
      // Unread messages first
      if (aUnread > 0 && bUnread == 0) return -1;
      if (bUnread > 0 && aUnread == 0) return 1;
      
      // Then by last message timestamp
      final aLastMessage = _lastMessages[a.uid];
      final bLastMessage = _lastMessages[b.uid];
      
      if (aLastMessage == null && bLastMessage == null) {
        return a.name.compareTo(b.name);
      }
      if (aLastMessage == null) return 1;
      if (bLastMessage == null) return -1;
      
      return bLastMessage.timestamp.compareTo(aLastMessage.timestamp);
    });
    
    Widget chatList = ListView.builder(
      itemCount: sortedUsers.length,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemBuilder: (context, index) {
        return _buildChatItem(sortedUsers[index]);
      },
    );
    
    if (widget.refreshable) {
      return RefreshIndicator(
        onRefresh: _refreshData,
        child: chatList,
      );
    }
    
    return chatList;
  }
}