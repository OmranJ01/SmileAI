import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../models/messages.dart';
import '../../models/user_data.dart';
import '../../Providers/app_state.dart';
import '../../services/chat_service.dart';
import '../../services/chat_agent_service.dart';
import '../../widgets/floating_support_button.dart';
import '../../services/smart_dental_ai.dart'; 

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;

  const ChatScreen({super.key, required this.recipientId, required this.recipientName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver, TickerProviderStateMixin {

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isRecipientTyping = false;
  bool _showScrollToBottom = false;
  bool _isOnline = true;
  bool _isAgentEnabled = true;
  bool _showAgentBanner = false;

  UserData? _recipientData;
  String _recipientRole = '';
  Timer? _refreshTimer;
  Timer? _typingTimer;
  Timer? _onlineTimer;
  Timer? _readMarkTimer;

  StreamSubscription? _messagesSubscription;

  final Set<String> _selectedMessages = {};
  bool _isSelectionMode = false;

  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  late AnimationController _messageAnimationController;
bool _doctorChatbotEnabled = false;

Future<void> _loadDoctorChatbotState(String doctorId) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(doctorId).get();
    if (doc.exists && doc.data()?['chatbotEnabled'] == true) {
      setState(() {
        _doctorChatbotEnabled = true;
      });
    } else {
      setState(() {
        _doctorChatbotEnabled = false;
      });
    }
  } catch (e) {
    setState(() {
      _doctorChatbotEnabled = false;
    });
  }
}
Future<void> _setOnlineStatus(bool isOnline) async {
  final appState = Provider.of<AppState>(context, listen: false);
  if (appState.userData?.role == 'doctor') {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(appState.user!.uid)
        .update({'isOnline': isOnline});
  }
}

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _typingAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _typingAnimationController, curve: Curves.easeInOut),
    );

    _messageAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _typingAnimationController.repeat(reverse: true);

    _setupScrollListener();
    _loadChatData();
    _setupRealTimeListener();
    _startTimers();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _loadRecipientData();
    if (_recipientRole == 'doctor') {
      await _loadDoctorChatbotState(widget.recipientId);
    }
    _markAllMessagesAsRead();
    _messageFocusNode.requestFocus();
  });
  final appState = Provider.of<AppState>(context, listen: false);
  if (appState.userData?.role == 'doctor') {
    _setOnlineStatus(true);
  }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final showButton = _scrollController.offset > 100;
      if (showButton != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = showButton;
        });
      }
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreMessages();
      }
    });
  }

  void _startTimers() {
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) _loadMessages();
    });
    _onlineTimer = Timer.periodic(Duration(seconds: 45), (timer) {
      if (mounted) {
        setState(() {
          _isOnline = !_isOnline;
        });
      }
    });
    _readMarkTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (mounted) {
        _markAllMessagesAsRead();
      }
    });
  }

  void _setupRealTimeListener() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;
    _messagesSubscription = FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: appState.user!.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _checkRecipientTypingStatus(snapshot);
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            if (participants.contains(widget.recipientId)) {
              _loadMessages();
              Future.delayed(Duration(milliseconds: 500), () {
                _markAllMessagesAsRead();
              });
              break;
            }
          }
        }
      }
    });
  }

  void _checkRecipientTypingStatus(QuerySnapshot snapshot) {
    bool recipientIsTyping = false;
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'];
      final typing = data['typing'] ?? false;
      final typingTimestamp = data['typingTimestamp'] as Timestamp?;
      if (senderId == widget.recipientId && typing && typingTimestamp != null) {
        final now = DateTime.now();
        final typingTime = typingTimestamp.toDate();
        if (now.difference(typingTime).inSeconds < 3) {
          recipientIsTyping = true;
          break;
        }
      }
    }
    if (_isRecipientTyping != recipientIsTyping) {
      setState(() {
        _isRecipientTyping = recipientIsTyping;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appState = Provider.of<AppState>(context, listen: false);
  if (appState.userData?.role == 'doctor') {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached||
               state == AppLifecycleState.inactive) {
      _setOnlineStatus(false);
    }
  }

    if (state == AppLifecycleState.resumed) {
      _loadMessages();
      _markAllMessagesAsRead();
    } else if (state == AppLifecycleState.paused) {
      _markAllMessagesAsRead();
    }
  }

  Future<void> _loadChatData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadRecipientData(),
      _loadMessages(),
    ]);
    await _markAllMessagesAsRead();
    setState(() => _isLoading = false);
  }

  Future<void> _loadMessages() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: appState.user!.uid)
            .where('recipientId', isEqualTo: widget.recipientId)
            .get(),
        FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: widget.recipientId)
            .where('recipientId', isEqualTo: appState.user!.uid)
            .get(),
        FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: ChatAgentService.AGENT_ID)
            .where('recipientId', isEqualTo: appState.user!.uid)
            .get(),
      ]);
      final allMessages = <Message>[];
      for (final querySnapshot in results) {
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data();
            final isDeleted = data['isDeleted'] ?? false;
            final deletedBy = List<String>.from(data['deletedBy'] ?? []);
            if (!isDeleted && !deletedBy.contains(appState.user!.uid)) {
              final senderId = data['senderId'] ?? '';
              final isAgentMessage = senderId == ChatAgentService.AGENT_ID || data['isAgentMessage'] == true;
              final message = Message.fromMap(data, doc.id);
              allMessages.add(message);
            }
          } catch (e) {}
        }
      }
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (mounted) {
        setState(() {
          _messages = allMessages;
        });
        if (allMessages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients && _scrollController.offset < 100) {
              _scrollToBottom();
            }
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _loadMoreMessages() async {}

  Future<void> _loadRecipientData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.recipientId)
          .get();
      if (doc.exists && mounted) {
        final userData = UserData.fromMap(doc.data() as Map<String, dynamic>);
        setState(() {
          _recipientData = userData;
          _recipientRole = userData.role;
        });
      }
    } catch (e) {}
  }

  Future<void> _markAllMessagesAsRead() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;
    try {
      await ChatService.markMessagesAsRead(
        senderId: widget.recipientId,
        recipientId: appState.user!.uid,
      );
    } catch (e) {}
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    if (animate) {
      _scrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void dispose() {
    _setOnlineStatus(false);
    _markAllMessagesAsRead();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _refreshTimer?.cancel();
    _typingTimer?.cancel();
    _onlineTimer?.cancel();
    _readMarkTimer?.cancel();
    _messagesSubscription?.cancel();
    _typingAnimationController.dispose();
    _messageAnimationController.dispose();
    super.dispose();
  }
  Future<bool> _isDoctorOnline(String doctorId) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(doctorId).get();
    return doc.exists && doc.data()?['isOnline'] == true;
  } catch (e) {
    return false;
  }
}

  Future<void> _sendMessage() async {
  if (_messageController.text.trim().isEmpty || _isSending) return;
  final messageText = _messageController.text.trim();
  final appState = Provider.of<AppState>(context, listen: false);
  if (appState.user == null) return;
  _messageController.clear();
  _messageFocusNode.unfocus();
  setState(() {
    _isSending = true;
  });

  final optimisticMessage = Message(
    id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
    senderId: appState.user!.uid,
    recipientId: widget.recipientId,
    content: messageText,
    timestamp: Timestamp.now(),
    read: false,
    isDeleted: false,
    participants: [appState.user!.uid, widget.recipientId],
    deletedBy: [],
  );
  setState(() {
    _messages.add(optimisticMessage);
  });
  _messageAnimationController.forward();
  _scrollToBottom();

  try {
    final success = await ChatService.sendMessageWithNotification(
      senderId: appState.user!.uid,
      recipientId: widget.recipientId,
      content: messageText,
      senderName: appState.userData?.name ?? 'User',
    );
    if (success) {
      setState(() {
        _messages.removeWhere((msg) => msg.id == optimisticMessage.id);
      });
      await Future.delayed(Duration(milliseconds: 500));
      await _loadMessages();

      // --- AI AUTO-REPLY LOGIC ---
      final currentUserRole = appState.userData?.role ?? '';
      final isDoctorPatientChat =
          (_recipientRole == 'doctor' && (currentUserRole == 'mentee' || currentUserRole == 'mentor'));
      if (isDoctorPatientChat ) {
        await _loadDoctorChatbotState(widget.recipientId); // fetch latest value
  if (_doctorChatbotEnabled) {
        final doctorOnline = await _isDoctorOnline(widget.recipientId);
        if (!doctorOnline) {
          // Use your AI service here (choose one)
          // Example with GingivalDiseaseGPT:
         // final aiReply = await GingivalDiseaseGPT.getBotResponse(messageText);
          // Or, if using SmartDentalAI:
           final aiReply = await SmartDentalAI.getAIResponse(messageText);

          // Send as doctor
          await ChatService.sendMessageWithNotification(
            senderId: widget.recipientId, // doctor's ID
            recipientId: appState.user!.uid, // mentee/mentor's ID
            content: aiReply,
            senderName: _recipientData?.name ?? 'Dr.',
          );
          await Future.delayed(Duration(seconds: 2));
          await _loadMessages();
        }
  }}
      // --- END AI AUTO-REPLY LOGIC ---

    } else {
      throw Exception('Failed to send');
    }
  } catch (e) {
    setState(() {
      _messages.removeWhere((msg) => msg.id == optimisticMessage.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Message failed to send')),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _messageController.text = messageText;
                  _messageFocusNode.requestFocus();
                },
                child: Text('RETRY', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: Colors.red[600],
          duration: Duration(seconds: 4),
        ),
      );
    }
  } finally {
    setState(() => _isSending = false);
    _messageFocusNode.requestFocus();
  }
}

  void _onTyping() {
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 1), () {
      _sendTypingIndicator(true);
    });
    Timer(Duration(seconds: 3), () {
      _sendTypingIndicator(false);
    });
  }

  Future<void> _sendTypingIndicator(bool isTyping) async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('typing_indicators')
          .doc('${appState.user!.uid}_${widget.recipientId}')
          .set({
        'senderId': appState.user!.uid,
        'recipientId': widget.recipientId,
        'typing': isTyping,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
        if (_selectedMessages.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessages.add(messageId);
        _isSelectionMode = true;
      }
    });
  }

  void _showDeleteOptions(Message message) {
    final appState = Provider.of<AppState>(context, listen: false);
    final isSentByMe = message.senderId == appState.user?.uid;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete Message',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, color: Colors.orange[600]),
              ),
              title: Text('Delete for me'),
              subtitle: Text('Message will be removed from your chat only'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message.id, false);
              },
            ),
            if (isSentByMe) ...[
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_forever, color: Colors.red[600]),
                ),
                title: Text('Delete for everyone'),
                subtitle: Text('Message will be removed from both chats'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message.id, true);
                },
              ),
            ],
            SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId, bool deleteForEveryone) async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;
    try {
      await ChatService.deleteMessage(
        messageId: messageId,
        deletedBy: appState.user!.uid,
        deleteForEveryone: deleteForEveryone,
      );
      await _loadMessages();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deleteForEveryone ? 'Message deleted for everyone' : 'Message deleted for you'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete message'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedMessages.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessages.isEmpty) return;
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;
    try {
      await ChatService.deleteMultipleMessages(
        messageIds: _selectedMessages.toList(),
        deletedBy: appState.user!.uid,
        deleteForEveryone: true,
      );
      _exitSelectionMode();
      await _loadMessages();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Messages deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete messages'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);
    if (difference.inDays > 6) {
      return DateFormat('MMM d, y').format(messageTime);
    } else if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else {
        return DateFormat('EEEE').format(messageTime);
      }
    } else {
      return DateFormat('h:mm a').format(messageTime);
    }
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMMM d, y').format(date);
    }
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dateText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isSentByMe, MaterialColor primaryColor) {
    final isOptimistic = message.id.startsWith('temp_');
    final isSelected = _selectedMessages.contains(message.id);
    final isAgentMessage = message.senderId == ChatAgentService.AGENT_ID;
    return GestureDetector(
      onLongPress: () => _showDeleteOptions(message),
      onTap: () {
        if (_isSelectionMode) {
          _toggleMessageSelection(message.id);
        }
      },
      child: Container(
        margin: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: isSentByMe ? 48 : 0,
          right: isSentByMe ? 0 : 48,
        ),
        child: Row(
          mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isSelectionMode && !isSentByMe)
              Padding(
                padding: EdgeInsets.only(right: 8, bottom: 8),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleMessageSelection(message.id),
                  activeColor: primaryColor,
                ),
              ),
            Flexible(
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor[200]
                      : isAgentMessage
                          ? Colors.blue[50]
                          : isOptimistic
                              ? primaryColor[50]
                              : isSentByMe
                                  ? primaryColor[100]
                                  : Colors.grey[100],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(isSentByMe ? 18 : 4),
                    bottomRight: Radius.circular(isSentByMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                  border: isAgentMessage
                      ? Border.all(color: Colors.blue[200]!, width: 1)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAgentMessage) ...[
                      Row(
                        children: [
                          ChatAgentService.getAgentAvatar(radius: 12),
                          SizedBox(width: 6),
                          Text(
                            ChatAgentService.AGENT_NAME,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                    ],
                    Text(
                      message.isDeleted ? 'This message was deleted' : message.content,
                      style: TextStyle(
                        fontSize: 16,
                        color: message.isDeleted 
                            ? Colors.grey[500]
                            : isOptimistic 
                                ? Colors.grey[600] 
                                : Colors.black87,
                        height: 1.3,
                        fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimestamp(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (isSentByMe && !message.isDeleted) ...[
                          SizedBox(width: 4),
                          if (isOptimistic) ...[
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(primaryColor[400]!),
                              ),
                            ),
                          ] else ...[
                            Icon(
                              message.read ? Icons.done_all : Icons.done,
                              size: 14,
                              color: message.read ? primaryColor[600] : Colors.grey[400],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_isSelectionMode && isSentByMe)
              Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleMessageSelection(message.id),
                  activeColor: primaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: _typingAnimation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.only(right: 48, left: 0, top: 8, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey[400]?.withOpacity(
                            0.4 + 0.6 * ((0.5 + 0.5 * _typingAnimation.value + i * 0.2) % 1.0)
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < 2) SizedBox(width: 4),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final userRole = appState.userData?.role ?? '';
    final showSupportButton =
        (userRole == 'mentee' || userRole == 'mentor') && _recipientRole == 'doctor';

    final MaterialColor primaryColor = _recipientRole == 'doctor'
        ? Colors.blue
        : _recipientRole == 'mentor'
            ? Colors.green
            : Colors.blue;

    return WillPopScope(
    onWillPop: () async {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.userData?.role == 'doctor') {
        await _setOnlineStatus(false);
      }
      _markAllMessagesAsRead();
      return true; // allow pop
    },
    child: Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close, color: Colors.black87),
                onPressed: _exitSelectionMode,
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () async{
                   final appState = Provider.of<AppState>(context, listen: false);
          if (appState.userData?.role == 'doctor') {
            await _setOnlineStatus(false);
          }
                  _markAllMessagesAsRead();
                  Navigator.pop(context);
                },
              ),
        title: _isSelectionMode
            ? Text(
                '${_selectedMessages.length} selected',
                style: TextStyle(color: Colors.black87, fontSize: 18),
              )
            : Row(
                children: [
                  Hero(
                    tag: 'avatar_${widget.recipientId}',
                    child: CircleAvatar(
                      backgroundColor: primaryColor[100],
                      radius: 20,
                      child: _recipientData?.photoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                _recipientData!.photoUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              widget.recipientName[0].toUpperCase(),
                              style: TextStyle(
                                color: primaryColor[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _recipientRole == 'doctor'
                              ? 'Dr. ${widget.recipientName}'
                              : widget.recipientName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[600]),
                  onPressed: _selectedMessages.isNotEmpty ? _deleteSelectedMessages : null,
                ),
              ]
            : [
                if (showSupportButton)
                  FloatingSupportButton(),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.black87),
                  onSelected: (value) {
                    switch (value) {
                      case 'refresh':
                        _loadMessages();
                        break;
                      case 'select':
                        setState(() => _isSelectionMode = true);
                        break;
                      case 'clear':
                        // Show clear chat confirmation
                        break;
                      case 'test_agent':
                        ChatAgentService.sendAgentMessage(
                          chatId: '${appState.user!.uid}_${widget.recipientId}',
                          recipientId: appState.user!.uid,
                          message: "Test message from SmileAI Assistant! 🦷 This is a test to ensure the agent is working properly.",
                        ).then((_) {
                          Future.delayed(Duration(seconds: 1), () => _loadMessages());
                        });
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 20),
                          SizedBox(width: 12),
                          Text('Refresh'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'select',
                      child: Row(
                        children: [
                          Icon(Icons.checklist, size: 20),
                          SizedBox(width: 12),
                          Text('Select messages'),
                        ],
                      ),
                    ),
                  
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          if (_showAgentBanner && _isAgentEnabled)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  ChatAgentService.getAgentAvatar(radius: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Dental Assistant Active',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        Text(
                          'I can help answer dental health questions during your chat!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _showAgentBanner = false;
                      });
                    },
                    color: Colors.blue[600],
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: primaryColor),
                            SizedBox(height: 16),
                            Text(
                              'Loading messages...',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: primaryColor[50],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.chat_bubble_outline,
                                    size: 48,
                                    color: primaryColor[400],
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'Start your conversation',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Send a message to begin chatting with ${widget.recipientName}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              await _loadMessages();
                              await _markAllMessagesAsRead();
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              reverse: true,
                              itemCount: _messages.length + (_isRecipientTyping ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == 0 && _isRecipientTyping) {
                                  return _buildTypingIndicator();
                                }
                                final messageIndex = _isRecipientTyping ? index - 1 : index;
                                final reversedIndex = _messages.length - 1 - messageIndex;
                                final message = _messages[reversedIndex];
                                final isSentByMe = message.senderId == appState.user?.uid;
                                bool showDateSeparator = false;
                                if (reversedIndex == 0) {
                                  showDateSeparator = true;
                                } else {
                                  final prevMessage = _messages[reversedIndex - 1];
                                  final currentDate = message.timestamp.toDate();
                                  final prevDate = prevMessage.timestamp.toDate();
                                  if (currentDate.day != prevDate.day ||
                                      currentDate.month != prevDate.month ||
                                      currentDate.year != prevDate.year) {
                                    showDateSeparator = true;
                                  }
                                }
                                return Column(
                                  children: [
                                    if (showDateSeparator)
                                      _buildDateSeparator(message.timestamp.toDate()),
                                    _buildMessageBubble(message, isSentByMe, primaryColor),
                                  ],
                                );
                              },
                            ),
                          ),
                if (_showScrollToBottom)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: primaryColor[600],
                      onPressed: () => _scrollToBottom(),
                      child: Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: primaryColor[50],
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                focusNode: _messageFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  hintStyle: TextStyle(color: Colors.grey[500]),
                                ),
                                textCapitalization: TextCapitalization.sentences,
                                maxLines: 5,
                                minLines: 1,
                                onChanged: (text) => _onTyping(),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[600]),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Emoji picker coming soon')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: primaryColor[600],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isSending
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}