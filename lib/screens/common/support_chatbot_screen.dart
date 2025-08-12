import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// IMPORTANT: Make sure this imports the file with GingivalDiseaseGPT class
import '../../services/support_chatbot_service.dart';

class SupportChatbotScreen extends StatefulWidget {
  const SupportChatbotScreen({super.key});

  @override
  _SupportChatbotScreenState createState() => _SupportChatbotScreenState();
}

class _SupportChatbotScreenState extends State<SupportChatbotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    
    // Reset context for new conversation
    GingivalDiseaseGPT.resetContext();
    
    // Initialize typing animation
    _typingAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _typingAnimationController, curve: Curves.easeInOut),
    );
    _typingAnimationController.repeat(reverse: true);
    
    // Add welcome message using GingiGPT
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addBotMessage(GingivalDiseaseGPT.getBotWelcomeMessage());
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _addBotMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(
        message: message,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(
        message: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();
    
    // Add user message
    _addUserMessage(userMessage);
    
    // Show typing indicator
    setState(() => _isTyping = true);
    
    // Variable thinking time based on message complexity
    int thinkingTime = 800 + (userMessage.length * 30);
    if (userMessage.contains('?')) thinkingTime += 500; // Questions take longer
    if (userMessage.split(' ').length > 10) thinkingTime += 1000; // Complex messages
    
    await Future.delayed(Duration(milliseconds: thinkingTime));
    
    // Get response from GingiGPT (the advanced AI)
    final botResponse = GingivalDiseaseGPT.getBotResponse(userMessage);
    
    // Hide typing indicator and add bot response
    setState(() => _isTyping = false);
    _addBotMessage(botResponse);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    GingivalDiseaseGPT.BOT_AVATAR,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              SizedBox(width: 12),
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

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: message.isUser ? 48 : 0,
        right: message.isUser ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  GingivalDiseaseGPT.BOT_AVATAR,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            SizedBox(width: 12),
          ],
          
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.blue[100] : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isUser) ...[
                    Text(
                      GingivalDiseaseGPT.BOT_NAME,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 4),
                  ],
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  GingivalDiseaseGPT.BOT_AVATAR,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  GingivalDiseaseGPT.BOT_NAME,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Gingival Disease Specialist',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              if (value == 'clear') {
                setState(() {
                  _messages.clear();
                });
                GingivalDiseaseGPT.resetContext();
                _addBotMessage(GingivalDiseaseGPT.getBotWelcomeMessage());
              } else if (value == 'analytics') {
                // Show conversation analytics
                final analytics = GingivalDiseaseGPT.getConversationAnalytics();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Conversation Analytics'),
                    content: Text(
                      'Exchanges: ${analytics['total_exchanges']}\n'
                      'User Level: ${_getExpertiseLevelName(analytics['user_expertise_level'])}\n'
                      'Mood: ${analytics['conversation_mood']}\n'
                      'Current Topic: ${analytics['current_topic']}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 12),
                    Text('Start New Chat'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'analytics',
                child: Row(
                  children: [
                    Icon(Icons.analytics, size: 20),
                    SizedBox(width: 12),
                    Text('Analytics'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced info banner
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
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.psychology, color: Colors.white, size: 16),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Gingival Disease Specialist',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                      Text(
                        'ChatGPT-level AI specialized in gum health. I adapt to your expertise level!',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Messages area
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            GingivalDiseaseGPT.BOT_AVATAR,
                            style: TextStyle(fontSize: 48),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          GingivalDiseaseGPT.BOT_NAME,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Advanced AI specialized in gingival disease\nChat naturally - I understand context!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          
          // Enhanced quick suggestions
          if (_messages.length <= 1 && !_isTyping)
            Container(
              height: 100,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildQuickSuggestion('Hi! How are you?', Icons.waving_hand, isGreeting: true),
                  _buildQuickSuggestion('My gums are bleeding', Icons.bloodtype),
                  _buildQuickSuggestion('What is gingivitis?', Icons.help_outline),
                  _buildQuickSuggestion('Prevention tips', Icons.shield),
                  _buildQuickSuggestion('Gum pain relief', Icons.healing),
                  _buildQuickSuggestion('Thanks for the help!', Icons.favorite, isAcknowledgment: true),
                ],
              ),
            ),
          
          // Message input area
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
                            hintText: 'Chat naturally - I understand context!',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            hintStyle: TextStyle(color: Colors.grey[500]),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 3,
                          minLines: 1,
                          onSubmitted: (_) => _sendMessage(),
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
                        icon: Icon(
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
    );
  }

  Widget _buildQuickSuggestion(String text, IconData icon, {bool isGreeting = false, bool isAcknowledgment = false}) {
    Color bgColor = Colors.white;
    Color borderColor = Colors.grey[300]!;
    Color iconColor = Colors.blue[600]!;
    
    if (isGreeting) {
      bgColor = Colors.green[50]!;
      borderColor = Colors.green[200]!;
      iconColor = Colors.green[600]!;
    } else if (isAcknowledgment) {
      bgColor = Colors.purple[50]!;
      borderColor = Colors.purple[200]!;
      iconColor = Colors.purple[600]!;
    }
    
    return Container(
      margin: EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          _messageController.text = text;
          _sendMessage();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getExpertiseLevelName(int level) {
    switch (level) {
      case 0: return 'Beginner';
      case 1: return 'Intermediate';
      case 2: return 'Advanced';
      default: return 'Unknown';
    }
  }
}

class ChatMessage {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.message,
    required this.isUser,
    required this.timestamp,
  });
}