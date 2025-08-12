import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatAgentService {
  static const String AGENT_ID = "smile_ai_assistant";
  static const String AGENT_NAME = "SmileAI Assistant";
  
  // Get agent avatar widget
  static Widget getAgentAvatar({double radius = 16}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue[100],
      child: Text(
        '🦷',
        style: TextStyle(fontSize: radius),
      ),
    );
  }
  
  // Send agent message
  static Future<bool> sendAgentMessage({
    required String chatId,
    required String recipientId,
    required String message,
  }) async {
    try {
      final messageData = {
        'senderId': AGENT_ID,
        'recipientId': recipientId,
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'isDeleted': false,
        'participants': [AGENT_ID, recipientId],
        'isAgentMessage': true,
        'deletedBy': [],
      };

      await FirebaseFirestore.instance.collection('messages').add(messageData);
      print('🤖 Agent message sent successfully');
      return true;
    } catch (e) {
      print('❌ Error sending agent message: $e');
      return false;
    }
  }
  
  // Check if agent should respond
  static Future<void> checkAndRespond({
    required String messageContent,
    required String senderId,
    required String recipientId,
    required String messageId,
  }) async {
    try {
      final message = messageContent.toLowerCase();
      
      // Only respond to dental-related messages
      bool shouldRespond = false;
      String response = '';
      
      // Dental keywords for triggering responses
      final dentalKeywords = [
        'tooth', 'teeth', 'gum', 'gums', 'brush', 'floss', 'pain', 'ache',
        'bleeding', 'dental', 'cavity', 'filling', 'crown', 'root canal',
        'mouthwash', 'toothpaste', 'sensitive', 'sensitivity', 'plaque',
        'tartar', 'cleaning', 'whitening', 'braces', 'retainer', 'extraction',
        'implant', 'denture', 'bad breath', 'halitosis', 'gingiv', 'periodont'
      ];
      
      // Check if message contains dental keywords
      for (final keyword in dentalKeywords) {
        if (message.contains(keyword)) {
          shouldRespond = true;
          break;
        }
      }
      
      if (shouldRespond) {
        response = _generateDentalResponse(message);
        
        if (response.isNotEmpty) {
          await Future.delayed(Duration(seconds: 2)); // Simulate thinking
          
          await sendAgentMessage(
            chatId: '${senderId}_$recipientId',
            recipientId: senderId,
            message: response,
          );
        }
      }
    } catch (e) {
      print('❌ Error in agent response check: $e');
    }
  }
  
  // Generate comprehensive dental responses
  static String _generateDentalResponse(String message) {
    // Pain-related responses
    if (message.contains('pain') || message.contains('hurt') || message.contains('ache')) {
      if (message.contains('gum')) {
        return "🦷 **Gum Pain Relief:**\n• Rinse with warm salt water (1/2 tsp salt in warm water)\n• Gentle brushing with soft bristles\n• Apply cold compress if swollen\n• Avoid irritating foods (spicy, acidic)\n• If pain persists >2 days, see your dentist\n\nGum pain often indicates inflammation - proper oral hygiene usually helps!";
      } else {
        return "🦷 **Tooth Pain Management:**\n• Take ibuprofen 400-600mg for pain & inflammation\n• Cold compress on outside of face (20 min on/off)\n• Rinse with warm salt water\n• Avoid very hot/cold foods\n• **See dentist ASAP** - tooth pain usually means something needs treatment!\n\nDon't put aspirin directly on the tooth - it can burn your gums.";
      }
    }
    
    // Bleeding gums
    if (message.contains('bleed') && (message.contains('gum') || message.contains('brush') || message.contains('floss'))) {
      return "🦷 **Bleeding Gums Guide:**\n• **Don't stop brushing/flossing!** Bleeding often improves with consistent care\n• Use gentle technique with soft bristles\n• Rinse with salt water 2x daily\n• Bleeding should reduce within 1-2 weeks\n• If it continues or gets worse, see your dentist\n\n**Why gums bleed:** Usually inflammation from plaque buildup. Regular cleaning helps!";
    }
    
    // Brushing technique
    if (message.contains('brush') && (message.contains('how') || message.contains('technique') || message.contains('proper'))) {
      return "🦷 **Perfect Brushing Technique:**\n• **2 minutes, twice daily** with fluoride toothpaste\n• 45° angle toward gums\n• Gentle circular motions (not scrubbing!)\n• Cover all surfaces: outer, inner, chewing\n• Don't forget your tongue!\n• Replace brush every 3 months\n\n**Pro tip:** Electric toothbrushes make it easier to get the right technique!";
    }
    
    // Flossing
    if (message.contains('floss')) {
      return "🦷 **Flossing Made Easy:**\n• **Daily flossing** prevents gum disease & cavities between teeth\n• Use 18 inches, wrap around middle fingers\n• Gentle up-and-down motion, curve around each tooth\n• Don't snap into gums!\n• If gums bleed at first, keep going - it should improve\n\n**Alternatives:** Water flossers work great too, especially for braces!";
    }
    
    // Sensitivity
    if (message.contains('sensitive') || message.contains('sensitivity')) {
      return "🦷 **Tooth Sensitivity Solutions:**\n• **Sensitive toothpaste** (use for 2 weeks to see results)\n• Soft-bristled toothbrush\n• Avoid acidic foods/drinks for a while\n• Don't brush immediately after eating citrus\n• Rinse with fluoride mouthwash\n\n**When to see dentist:** If sensitivity is severe or doesn't improve with sensitive toothpaste.";
    }
    
    // Gum disease / gingivitis
    if (message.contains('gingiv') || message.contains('gum disease') || message.contains('red gums') || message.contains('swollen gums')) {
      return "🦷 **Gum Disease (Gingivitis) Care:**\n• **Early stage is reversible!** With good oral care\n• Brush gently 2x daily, floss daily\n• Rinse with antibacterial mouthwash\n• Professional cleaning may be needed\n• Avoid smoking/tobacco\n\n**Signs:** Red, swollen, bleeding gums, bad breath. See your dentist for proper diagnosis!";
    }
    
    // Bad breath
    if (message.contains('bad breath') || message.contains('halitosis') || message.contains('breath smell')) {
      return "🦷 **Fresh Breath Solutions:**\n• **Clean your tongue** - major source of bacteria!\n• Brush & floss daily to remove food particles\n• Drink plenty of water\n• Rinse with antibacterial mouthwash\n• Chew sugar-free gum after meals\n\n**Persistent bad breath?** Could indicate gum disease or other issues - see your dentist!";
    }
    
    // Cavity concerns
    if (message.contains('cavity') || message.contains('cavities') || message.contains('hole') || message.contains('decay')) {
      return "🦷 **Cavity Prevention & Care:**\n• **Fluoride toothpaste** helps remineralize early decay\n• Limit sugary/acidic foods & drinks\n• Don't sip sodas or juices throughout the day\n• Chew sugar-free gum after meals\n• Regular dental checkups catch cavities early\n\n**If you think you have a cavity:** See your dentist soon - early treatment is much easier!";
    }
    
    // General dental health
    if (message.contains('dental health') || message.contains('oral health') || message.contains('healthy teeth')) {
      return "🦷 **Healthy Teeth & Gums Formula:**\n• Brush 2x daily with fluoride toothpaste\n• Floss daily (removes 40% more plaque!)\n• Limit sugary snacks between meals\n• Drink plenty of water\n• See dentist every 6 months\n• Don't use teeth as tools!\n\n**Remember:** Prevention is always easier and cheaper than treatment!";
    }
    
    // Mouthwash questions
    if (message.contains('mouthwash') || message.contains('mouth wash') || message.contains('rinse')) {
      return "🦷 **Mouthwash Tips:**\n• **Not a replacement** for brushing & flossing\n• Use **after** brushing for best results\n• Antibacterial types help with gum health\n• Fluoride rinses help prevent cavities\n• Swish for 30-60 seconds, then spit\n\n**Alcohol-free** options are gentler and just as effective!";
    }
    
    // Teeth whitening
    if (message.contains('whiten') || message.contains('white teeth') || message.contains('stain') || message.contains('yellow')) {
      return "🦷 **Safe Teeth Whitening:**\n• **Professional whitening** is safest & most effective\n• Whitening toothpaste helps remove surface stains\n• Avoid DIY remedies (baking soda, lemon) - can damage enamel\n• Limit staining foods: coffee, tea, red wine\n• Drink through a straw when possible\n\n**Good oral hygiene** is the best foundation for a bright smile!";
    }
    
    // Emergency situations
    if (message.contains('emergency') || message.contains('urgent') || message.contains('broken') || message.contains('knocked out')) {
      return "🚨 **Dental Emergency - Act Fast:**\n• **Knocked out tooth:** Find it, rinse gently, try to put back in socket, store in milk if not possible\n• **Broken tooth:** Save pieces, rinse mouth, cold compress for swelling\n• **Severe pain:** Ibuprofen + cold compress, see dentist ASAP\n• **Bleeding won't stop:** Apply pressure, call dentist immediately\n\n**Time matters** in dental emergencies - don't wait!";
    }
    
    // Diet and teeth
    if (message.contains('food') || message.contains('diet') || message.contains('sugar') || message.contains('what to eat')) {
      return "🦷 **Tooth-Friendly Diet:**\n• **Great choices:** Cheese, yogurt, leafy greens, almonds, fish\n• **Limit:** Sticky candies, sodas, citrus, crackers\n• **Smart tips:** Eat sweets with meals, rinse with water after\n• **Best drink:** Water (especially fluoridated)\n• **Snack smart:** Choose nuts, cheese, or veggies over chips\n\nYour teeth will thank you for making healthy choices!";
    }
    
    // Default dental response for other dental keywords
    return "🦷 That's a great dental question! For specific concerns like yours, I'd recommend discussing with your dentist who can examine your individual situation. \n\nIn the meantime:\n• Keep up good oral hygiene (brush 2x daily, floss daily)\n• Rinse with warm salt water if there's any discomfort\n• Avoid very hot/cold foods if you have sensitivity\n\nIs there anything specific about brushing, flossing, or general oral care I can help you with?";
  }
}