import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../models/messages.dart';
import '../Providers/app_state.dart';
import '../services/smart_dental_ai.dart';
import '../screens/common/support_chatbot_screen.dart';

class SmartAIChatScreen extends StatefulWidget {
  @override
  _SmartAIChatScreenState createState() => _SmartAIChatScreenState();
}

class _SmartAIChatScreenState extends State<SmartAIChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isAITyping = false;
  bool _showScrollToBottom = false;
  
  StreamSubscription? _messagesSubscription;
  
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  
  @override
  void initState() {
    super.initState();
    print('🚀 SmartAIChatScreen initialized!');
    
    _typingAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _typingAnimationController, curve: Curves.easeInOut),
    );
    _typingAnimationController.repeat(reverse: true);
    
    _setupScrollListener();
    _loadMessages();
    _setupRealTimeListener();
    _sendWelcomeMessage();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageFocusNode.requestFocus();
    });
  }
  
  void _setupScrollListener() {
    _scrollController.addListener(() {
      final showButton = _scrollController.offset > 100;
      if (showButton != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = showButton;
        });
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
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            
            if (participants.contains(SmartDentalAI.AGENT_ID)) {
              print('🔄 New AI message detected!');
              _loadMessages();
              break;
            }
          }
        }
      }
    });
  }
  
  Future<void> _loadMessages() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      print('📥 Loading AI chat messages...');
      
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: appState.user!.uid)
            .where('recipientId', isEqualTo: SmartDentalAI.AGENT_ID)
            .get(),
        FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: SmartDentalAI.AGENT_ID)
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
              final message = Message.fromMap(data, doc.id);
              allMessages.add(message);
            }
          } catch (e) {
            print('❌ Error parsing message: $e');
          }
        }
      }
      
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      print('📨 Loaded ${allMessages.length} messages');
      
      if (mounted) {
        setState(() {
          _messages = allMessages;
          _isLoading = false;
        });
        
        if (allMessages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollToBottom();
            }
          });
        }
      }
    } catch (e) {
      print('❌ Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _sendWelcomeMessage() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;
    
    bool hasWelcome = _messages.any((msg) => 
        msg.senderId == SmartDentalAI.AGENT_ID && 
        msg.content.contains('Welcome to SmileAI'));
    
    if (!hasWelcome) {
      await Future.delayed(Duration(seconds: 1));
      
      print('🤖 Sending welcome message...');
      await SmartDentalAI.sendAgentMessage(
        chatId: 'ai_chat_${appState.user!.uid}',
        recipientId: appState.user!.uid,
        message: "Welcome to SmileAI! 🤖🦷\n\nI'm your personal dental health assistant. I can chat about anything, but I'm especially passionate about helping you maintain excellent oral health!\n\nFeel free to ask me about:\n• Gingival disease & gum health\n• Brushing & flossing techniques\n• Daily oral care routines\n• General dental questions\n• Or just chat about your day!\n\nWhat would you like to talk about? 😊",
      );
      
      await Future.delayed(Duration(milliseconds: 500));
      _loadMessages();
    }
  }
  
  // SIMPLE TEST VERSION
  Future<void> _sendMessage() async {
    print('🔥🔥🔥 _sendMessage() called!');
    
    if (_messageController.text.trim().isEmpty || _isSending) {
      print('❌ Message empty or already sending');
      return;
    }
    
    final messageText = _messageController.text.trim();
    print('📝 User message: "$messageText"');
    
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) {
      print('❌ No user found');
      return;
    }
    
    _messageController.clear();
    setState(() {
      _isSending = true;
    });
    
    try {
      print('💾 Saving user message...');
      
      // Save user message
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': appState.user!.uid,
        'recipientId': SmartDentalAI.AGENT_ID,
        'content': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'isDeleted': false,
        'participants': [appState.user!.uid, SmartDentalAI.AGENT_ID],
        'deletedBy': [],
      });
      
      print('✅ User message saved!');
      
      // Show AI typing
      setState(() {
        _isAITyping = true;
      });
      
      // Wait a bit
      await Future.delayed(Duration(seconds: 2));
      
      print('🤖 Getting AI response...');
      
      // Get AI response - SIMPLE VERSION
      String aiResponse;
      try {
        aiResponse = await SmartDentalAI.getAIResponse(messageText);
        print('🤖 AI responded: "$aiResponse"');
      } catch (e) {
        print('❌ AI API error: $e');
        aiResponse = "Hi! I'm having trouble with my AI brain right now, but I'm here to help with dental health questions! 🦷 Try asking me about brushing, flossing, or gum care!";
      }
      
      // Send AI response
      await SmartDentalAI.sendAgentMessage(
        chatId: 'ai_chat_${appState.user!.uid}',
        recipientId: appState.user!.uid,
        message: aiResponse,
      );
      
      print('✅ AI response sent!');
      
      // Hide typing and reload
      setState(() {
        _isAITyping = false;
      });
      
      await _loadMessages();
      
    } catch (e) {
      print('❌ Error in send message: $e');
      
      setState(() {
        _isAITyping = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSending = false);
      _messageFocusNode.requestFocus();
    }
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
  
  Widget _buildMessageBubble(Message message, bool isSentByMe) {
    final isOptimistic = message.id.startsWith('temp_');
    final isAIMessage = message.senderId == SmartDentalAI.AGENT_ID;
    
    return Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isSentByMe ? 64 : 0,
        right: isSentByMe ? 0 : 64,
      ),
      child: Row(
        mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isAIMessage
                    ? Colors.blue[50]
                    : isOptimistic
                        ? Colors.blue[50]
                        : isSentByMe
                            ? Colors.blue[500]
                            : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(isSentByMe ? 20 : 4),
                  bottomRight: Radius.circular(isSentByMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
                border: isAIMessage
                    ? Border.all(color: Colors.blue[200]!, width: 1)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAIMessage) ...[
                    Row(
                      children: [
                        SmartDentalAI.getAgentAvatar(radius: 12),
                        SizedBox(width: 8),
                        Text(
                          SmartDentalAI.AGENT_NAME,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                  ],
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16,
                      color: isOptimistic 
                          ? Colors.grey[600]
                          : isSentByMe && !isAIMessage
                              ? Colors.white
                              : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isOptimistic 
                              ? Colors.grey[500]
                              : isSentByMe && !isAIMessage
                                  ? Colors.white70
                                  : Colors.grey[600],
                        ),
                      ),
                      if (isSentByMe && !isAIMessage) ...[
                        SizedBox(width: 4),
                        if (isOptimistic) ...[
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.done_all,
                            size: 14,
                            color: Colors.white70,
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: _typingAnimation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.only(right: 64, left: 0, top: 8, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SmartDentalAI.getAgentAvatar(radius: 10),
                    SizedBox(width: 12),
                    for (int i = 0; i < 3; i++) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.blue[400]?.withOpacity(
                            0.4 + 0.6 * ((0.5 + 0.5 * _typingAnimation.value + i * 0.2) % 1.0)
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < 2) SizedBox(width: 6),
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
  
  String _formatTime(Timestamp timestamp) {
    final messageTime = timestamp.toDate();
    return DateFormat('h:mm a').format(messageTime);
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _messagesSubscription?.cancel();
    _typingAnimationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            SmartDentalAI.getAgentAvatar(radius: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SmartDentalAI.AGENT_NAME,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Your Dental AI Assistant',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
 TextButton(
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SupportChatbotScreen(),
        ),
      );
    },
    child: Text(
      'Custom Chatbot',
      style: TextStyle(color: Colors.blue), // Set your color here
    ),
  ),
  IconButton(
    icon: Icon(Icons.refresh, color: Colors.black87),
    onPressed: _loadMessages,
  ),
],

      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.blue[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology, color: Colors.blue[600], size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chat with AI about anything! I specialize in dental health 🦷',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                            CircularProgressIndicator(color: Colors.blue),
                            SizedBox(height: 16),
                            Text('Loading chat...'),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SmartDentalAI.getAgentAvatar(radius: 40),
                                SizedBox(height: 16),
                                Text(
                                  'Start chatting with SmileAI!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Ask me anything about dental health\nor just have a friendly chat!',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadMessages,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              reverse: true,
                              itemCount: _messages.length + (_isAITyping ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == 0 && _isAITyping) {
                                  return _buildTypingIndicator();
                                }
                                
                                final messageIndex = _isAITyping ? index - 1 : index;
                                final reversedIndex = _messages.length - 1 - messageIndex;
                                final message = _messages[reversedIndex];
                                final appState = Provider.of<AppState>(context);
                                final isSentByMe = message.senderId == appState.user?.uid;
                                
                                return _buildMessageBubble(message, isSentByMe);
                              },
                            ),
                          ),
                
                if (_showScrollToBottom)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.blue[600],
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
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Type "Hello" to test AI...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            hintStyle: TextStyle(color: Colors.grey[500]),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 4,
                          minLines: 1,
                          onSubmitted: (_) {
                            print('👆 User pressed Enter/Send');
                            _sendMessage();
                          },
                        ),
                      ),
                    ),
                    
                    SizedBox(width: 12),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
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
                        onPressed: () {
                          print('👆 User pressed Send button');
                          _sendMessage();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}