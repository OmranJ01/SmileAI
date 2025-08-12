import 'package:flutter/material.dart';
import '../screens/common/support_chatbot_screen.dart';
import '../screens/smart_ai_chat_screen.dart';
//SupportChatbotScreen
class FloatingSupportButton extends StatelessWidget {
  const FloatingSupportButton({super.key});

  void _openSupportChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SmartAIChatScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.support_agent, color: Colors.blue),
      tooltip: 'Support Chat',
      onPressed: () => _openSupportChat(context),
    );
  }
}