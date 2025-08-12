// lib/services/smart_dental_ai.dart - FULL GEMINI INTEGRATION
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/api_keys.dart';


class SmartDentalAI {
  static const String AGENT_ID = 'smart_dental_ai';
  static const String AGENT_NAME = 'SmileAI';
  
static const String GEMINI_API_KEY = ApiKeys.GEMINI_API_KEY;  
  // Try multiple Gemini models for best results
  static const List<String> GEMINI_MODELS = [
    'gemini-1.5-pro-latest',
    'gemini-1.5-pro',
    'gemini-1.5-flash-latest', 
    'gemini-1.5-flash',
    'gemini-pro'
  ];
  
  /// FULL GEMINI INTEGRATION with all features
  static Future<String> getAIResponse(String userMessage) async {
    print('🚀 FULL GEMINI INTEGRATION - Processing: "$userMessage"');
    
    // Try different models until one works
    for (int i = 0; i < GEMINI_MODELS.length; i++) {
      final model = GEMINI_MODELS[i];
      print('🎯 Trying model: $model');
      
      try {
        final response = await _callGeminiModel(model, userMessage);
        if (response.isNotEmpty) {
          print('✅ SUCCESS with model: $model');
          return response;
        }
      } catch (e) {
        print('❌ Model $model failed: $e');
        continue;
      }
    }
    
    print('💀 All models failed, using intelligent response');
    return _getIntelligentResponse(userMessage);
  }
  
  /// Call specific Gemini model
  static Future<String> _callGeminiModel(String model, String userMessage) async {
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
    
    // Build intelligent prompt
    final prompt = _buildIntelligentPrompt(userMessage);
    
    final requestBody = {
      'contents': [{
        'parts': [{'text': prompt}]
      }],
      'generationConfig': {
        'temperature': 0.9,           // Natural and creative
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 8192,      // Maximum length
        'candidateCount': 1,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_ONLY_HIGH'
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_ONLY_HIGH'
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_ONLY_HIGH'
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_ONLY_HIGH'
        }
      ]
    };
    
    print('📡 API Request to: $url');
    print('🔧 Request body keys: ${requestBody.keys}');
    
    final response = await http.post(
      Uri.parse('$url?key=$GEMINI_API_KEY'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Flutter-App/1.0',
      },
      body: jsonEncode(requestBody),
    ).timeout(Duration(seconds: 45));
    
    print('📊 Response Status: ${response.statusCode}');
    print('📊 Response Headers: ${response.headers}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('📋 Response structure: ${data.keys}');
      
      // Handle successful response
      final candidates = data['candidates'] as List?;
      print('👥 Candidates: ${candidates?.length ?? 0}');
      
      if (candidates != null && candidates.isNotEmpty) {
        final candidate = candidates[0];
        print('🔍 Candidate structure: ${candidate.keys}');
        
        final finishReason = candidate['finishReason'];
        print('🏁 Finish reason: $finishReason');
        
        // Handle different finish reasons
        if (finishReason == 'STOP') {
          final content = candidate['content'];
          final parts = content['parts'] as List;
          
          if (parts.isNotEmpty) {
            final text = parts[0]['text'] ?? '';
            if (text.trim().isNotEmpty) {
              print('✅ Got response: ${text.length} characters');
              return text.trim();
            }
          }
        } else if (finishReason == 'SAFETY') {
          print('🛡️ Response blocked by safety filters');
          // Try with safer prompt
          return await _trySaferPrompt(model, userMessage);
        } else if (finishReason == 'MAX_TOKENS') {
          print('📏 Response truncated - getting partial response');
          final content = candidate['content'];
          final parts = content['parts'] as List;
          if (parts.isNotEmpty) {
            final text = parts[0]['text'] ?? '';
            return text.trim() + "\n\n[Response was truncated due to length]";
          }
        } else if (finishReason == 'RECITATION') {
          print('📝 Response blocked due to recitation - retrying with different approach');
          return await _tryAlternativePrompt(model, userMessage);
        }
      }
      
      // Handle other response structures
      final error = data['error'];
      if (error != null) {
        print('⚠️ API returned error: ${error['message']}');
        throw Exception('API Error: ${error['message']}');
      }
      
    } else if (response.statusCode == 400) {
      print('❌ Bad Request (400)');
      print('❌ Response body: ${response.body}');
      
      try {
        final errorData = jsonDecode(response.body);
        final error = errorData['error'];
        print('🔍 Error details: ${error['message']}');
        
        if (error['message'].toString().contains('API key')) {
          throw Exception('Invalid API key');
        }
      } catch (e) {
        print('🔍 Could not parse error response');
      }
      
      throw Exception('Bad request to Gemini API');
      
    } else if (response.statusCode == 403) {
      print('❌ Forbidden (403) - API key or quota issue');
      throw Exception('API access forbidden - check API key and quota');
      
    } else if (response.statusCode == 429) {
      print('❌ Rate Limited (429) - too many requests');
      await Future.delayed(Duration(seconds: 2));
      throw Exception('Rate limited - retrying...');
      
    } else {
      print('❌ HTTP Error: ${response.statusCode}');
      print('❌ Response: ${response.body}');
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
    
    return '';
  }
  
  /// Build intelligent prompt that works with Gemini
  static String _buildIntelligentPrompt(String userMessage) {
    return '''You are SmileAI, an intelligent and friendly AI assistant. You have extensive knowledge across all topics and special expertise in health and dental care.

Instructions:
- Respond naturally and conversationally
- Be helpful, knowledgeable, and engaging
- Show appropriate intelligence for the question asked
- For medical questions, provide detailed but accessible information
- For casual questions, be warm and personable
- Always be helpful and informative

User message: "$userMessage"

Respond as SmileAI:''';
  }
  
  /// Try safer prompt if blocked by safety
  static Future<String> _trySaferPrompt(String model, String userMessage) async {
    print('🛡️ Trying safer prompt approach...');
    
    final saferPrompt = '''Please provide helpful information about: "$userMessage"
    
Keep the response educational and appropriate.''';
    
    final requestBody = {
      'contents': [{
        'parts': [{'text': saferPrompt}]
      }],
      'generationConfig': {
        'temperature': 0.5,
        'maxOutputTokens': 2048,
      }
    };
    
    try {
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
      final response = await http.post(
        Uri.parse('$url?key=$GEMINI_API_KEY'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        
        if (candidates != null && candidates.isNotEmpty) {
          final candidate = candidates[0];
          if (candidate['finishReason'] == 'STOP') {
            final content = candidate['content'];
            final parts = content['parts'] as List;
            if (parts.isNotEmpty) {
              final text = parts[0]['text'] ?? '';
              if (text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ Safer prompt failed: $e');
    }
    
    return '';
  }
  
  /// Try alternative prompt for recitation blocks
  static Future<String> _tryAlternativePrompt(String model, String userMessage) async {
    print('📝 Trying alternative approach for recitation block...');
    
    final altPrompt = '''As an AI assistant, help with this question: "$userMessage"
    
Provide original, helpful information in your own words.''';
    
    final requestBody = {
      'contents': [{
        'parts': [{'text': altPrompt}]
      }],
      'generationConfig': {
        'temperature': 0.8,
        'maxOutputTokens': 2048,
      }
    };
    
    try {
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
      final response = await http.post(
        Uri.parse('$url?key=$GEMINI_API_KEY'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        
        if (candidates != null && candidates.isNotEmpty) {
          final candidate = candidates[0];
          if (candidate['finishReason'] == 'STOP') {
            final content = candidate['content'];
            final parts = content['parts'] as List;
            if (parts.isNotEmpty) {
              final text = parts[0]['text'] ?? '';
              if (text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ Alternative prompt failed: $e');
    }
    
    return '';
  }
  
  /// Intelligent response when all API calls fail
  static String _getIntelligentResponse(String message) {
    final lowerMessage = message.toLowerCase().trim();
    
    // Greetings
    if (_contains(lowerMessage, ['hello', 'hi', 'hey', 'good morning', 'good afternoon'])) {
      return "Hello! I'm SmileAI, your friendly AI assistant! 😊 I'm here to help with any questions you have, from general topics to health and dental care. How can I assist you today?";
    }
    
    // How are you
    if (_contains(lowerMessage, ['how are you', 'how do you feel', 'what\'s up'])) {
      return "I'm doing great, thank you for asking! I'm always excited to chat and help people learn new things. I particularly enjoy discussing health topics and helping people understand complex subjects. How are you doing today?";
    }
    
    // Medical questions
    if (_contains(lowerMessage, ['pain', 'symptom', 'disease', 'health', 'medical', 'gum', 'tooth', 'dental'])) {
      return "I'd love to help with your health question! While I'm having some technical difficulties connecting to my full knowledge base right now, I can tell you that for any concerning symptoms or health issues, it's always best to consult with a healthcare professional who can properly evaluate your specific situation. Is there a particular health topic you'd like to discuss?";
    }
    
    // General questions
    return "That's an interesting question! I'm experiencing some technical issues connecting to my full knowledge base at the moment, but I'm still here to help as best I can. Could you tell me more about what you're curious about? I'll do my best to provide useful information!";
  }
  
  static bool _contains(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
  
  static bool shouldRespond(String message) => message.trim().isNotEmpty;
  
  static Future<bool> sendAgentMessage({
    required String chatId,
    required String recipientId,
    required String message,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': AGENT_ID,
        'recipientId': recipientId,
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'isDeleted': false,
        'isAgentMessage': true,
        'agentType': 'full_gemini_integration',
        'participants': [AGENT_ID, recipientId],
        'deletedBy': [],
      });
      return true;
    } catch (e) {
      print('❌ Error saving message: $e');
      return false;
    }
  }
  
  static Widget getAgentAvatar({double radius = 20}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue[100],
      child: Text('🤖', style: TextStyle(fontSize: radius * 0.8)),
    );
  }
  
  static String getIntroMessage() {
    return '''Hi there! I'm SmileAI! 🤖

I'm your intelligent AI assistant with knowledge across many topics and special expertise in health and dental care. I'm here to:

💬 Have natural conversations about any topic
🧠 Answer questions with helpful, detailed information  
🦷 Provide expert insights on dental and health topics
🤝 Help you learn and understand complex subjects

What would you like to chat about today?''';
  }
}