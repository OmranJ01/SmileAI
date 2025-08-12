import 'dart:math';

class GingivalDiseaseGPT {
  static const String BOT_NAME = "GingiGPT";
  static const String BOT_AVATAR = "🦷";
  
  // Conversation state management
  static List<Map<String, dynamic>> _conversationHistory = [];
  static Map<String, dynamic> _userContext = {
    'name': null,
    'symptoms': [],
    'concerns': [],
    'mood': 'neutral',
    'lastTopic': null,
  };
  
  // Main response engine
  static String getBotResponse(String userMessage) {
    final message = userMessage.toLowerCase().trim();
    
    if (message.isEmpty) {
      return "I'm here to help! Feel free to ask me anything about gum health or just say hi! 😊";
    }
    
    // Add to conversation history
    _conversationHistory.add({
      'role': 'user',
      'message': userMessage,
      'timestamp': DateTime.now(),
    });
    
    // Analyze message intent
    String response = _generateResponse(message, userMessage);
    
    // Add bot response to history
    _conversationHistory.add({
      'role': 'bot',
      'message': response,
      'timestamp': DateTime.now(),
    });
    
    // Keep conversation history manageable
    if (_conversationHistory.length > 50) {
      _conversationHistory = _conversationHistory.sublist(20);
    }
    
    return response;
  }
  
  static String _generateResponse(String message, String originalMessage) {
    // Check for greetings first
    if (_isGreeting(message)) {
      return _getGreetingResponse(message);
    }
    
    // Check for how are you type questions
    if (_isHowAreYou(message)) {
      return _getHowAreYouResponse();
    }
    
    // Check for acknowledgments
    if (_isAcknowledgment(message)) {
      return _getAcknowledgmentResponse();
    }
    
    // Check for personal statements
    if (_isPersonalStatement(message)) {
      return _getPersonalResponse(message);
    }
    
    // Check for goodbye
    if (_isGoodbye(message)) {
      return _getGoodbyeResponse();
    }
    
    // Check for gingival disease related content
    if (_isGingivalRelated(message)) {
      return _getGingivalResponse(message, originalMessage);
    }
    
    // Check for general health questions
    if (_isGeneralHealthQuestion(message)) {
      return _redirectToGingivalFocus(message);
    }
    
    // Default conversational response
    return _getDefaultConversationalResponse(message);
  }
  
  // === GREETING DETECTION AND RESPONSES ===
  static bool _isGreeting(String message) {
    final greetings = [
      'hi', 'hello', 'hey', 'hola', 'greetings', 'sup', 'yo',
      'good morning', 'good afternoon', 'good evening', 'good day',
      'morning', 'afternoon', 'evening', 'howdy', 'hiya'
    ];
    
    return greetings.any((greeting) => 
      message == greeting || 
      message.startsWith('$greeting ') ||
      message.contains(' $greeting') ||
      message.endsWith(' $greeting')
    );
  }
  
  static String _getGreetingResponse(String message) {
    final responses = [
      "Hello! 😊 I'm GingiGPT, your friendly gum health specialist. How can I help you today? Whether you have questions about gum disease, bleeding gums, or just want to chat about oral health, I'm here for you!",
      
      "Hi there! 👋 Great to meet you! I'm GingiGPT - think of me as your personal gum health expert. I can help with everything from understanding symptoms to prevention tips. What brings you here today?",
      
      "Hey! Welcome! 🦷 I'm GingiGPT, and I absolutely love talking about gum health (I know, specific interest, right? 😄). Is there anything about your gums or oral health that's been on your mind?",
      
      "Hello, friend! 🌟 I'm GingiGPT, your AI companion for all things gum-related. From bleeding gums to prevention strategies, I'm here to help. How are you doing today?",
      
      "Greetings! 😊 I'm GingiGPT - your specialized AI for gingival disease and gum health. I'm here to answer questions, provide advice, or just chat about keeping your smile healthy. What can I do for you?"
    ];
    
    if (message.contains('morning')) {
      return "Good morning! ☀️ I'm GingiGPT, your gum health specialist. Starting the day with good oral care? I'm here to help with any questions about gum disease, bleeding, or general oral health. How can I assist you this morning?";
    } else if (message.contains('evening') || message.contains('night')) {
      return "Good evening! 🌙 I'm GingiGPT, here to help with all your gum health questions. Evening is a great time to focus on oral care! Is there anything about gum disease or oral hygiene you'd like to discuss?";
    }
    
    return responses[Random().nextInt(responses.length)];
  }
  
  // === HOW ARE YOU DETECTION AND RESPONSES ===
  static bool _isHowAreYou(String message) {
    final patterns = [
      'how are you', 'how r u', 'how are u', 'hows it going',
      'how\'s it going', 'whats up', 'what\'s up', 'how do you do',
      'how are things', 'how\'s life', 'how you doing', 'how ya doing',
      'you good', 'you okay', 'everything okay', 'you alright'
    ];
    
    return patterns.any((pattern) => message.contains(pattern));
  }
  
  static String _getHowAreYouResponse() {
    final responses = [
      "I'm doing wonderfully, thank you for asking! 😊 I'm always excited to talk about gum health. How are YOU doing? Any concerns about your gums or teeth I can help with?",
      
      "I'm great, thanks! 🦷 Always ready to chat about oral health. How about you - how are your gums treating you? Any questions or concerns?",
      
      "Fantastic, thank you! I love when people ask. 😄 I'm functioning perfectly and ready to help with any gum-related questions. How are you feeling today?",
      
      "I'm excellent! Thank you for the kind inquiry. 🌟 As an AI focused on gum health, I'm always eager to help. How are you doing? Everything good with your oral health?",
      
      "I'm doing really well! It's nice of you to ask. 💙 I'm here and ready to discuss anything about gum disease, prevention, or oral care. What about you - how are things?"
    ];
    
    return responses[Random().nextInt(responses.length)];
  }
  
  // === ACKNOWLEDGMENT DETECTION AND RESPONSES ===
  static bool _isAcknowledgment(String message) {
    final patterns = [
      'thank', 'thanks', 'thx', 'ty', 'appreciate',
      'helpful', 'great', 'awesome', 'perfect', 'good',
      'nice', 'cool', 'ok', 'okay', 'alright', 'understood',
      'got it', 'i see', 'makes sense', 'clear'
    ];
    
    return patterns.any((pattern) => message.contains(pattern)) && message.length < 20;
  }
  
  static String _getAcknowledgmentResponse() {
    final responses = [
      "You're very welcome! 😊 Is there anything else about gum health I can help you with?",
      "My pleasure! I'm here whenever you need advice about gums or oral care. 🦷",
      "Glad I could help! Feel free to ask me anything else about gingival disease or prevention.",
      "Happy to help! 🌟 Any other questions about your oral health?",
      "You're welcome! Remember, I'm always here for your gum health questions. 😊"
    ];
    
    return responses[Random().nextInt(responses.length)];
  }
  
  // === PERSONAL STATEMENT DETECTION ===
  static bool _isPersonalStatement(String message) {
    final patterns = [
      RegExp(r"^i'm\s+(good|fine|great|okay|ok|well|better|sick|tired|worried)"),
      RegExp(r"^im\s+(good|fine|great|okay|ok|well|better|sick|tired|worried)"),
      RegExp(r"^i\s+am\s+(good|fine|great|okay|ok|well|better|sick|tired|worried)"),
      RegExp(r"^i\s+feel\s+"),
      RegExp(r"^i\s+have\s+"),
      RegExp(r"^my\s+(gums?|teeth?|mouth)\s+"),
    ];
    
    return patterns.any((pattern) => pattern.hasMatch(message));
  }
  
  static String _getPersonalResponse(String message) {
    if (message.contains(RegExp(r'good|fine|great|well|better'))) {
      return "That's wonderful to hear! 😊 I'm glad you're doing well. Since you're here, is there anything about gum health you'd like to learn about? Even when we're feeling good, prevention is key!";
    }
    
    if (message.contains(RegExp(r'sick|tired|worried|anxious|scared'))) {
      _userContext['mood'] = 'concerned';
      return "I'm sorry to hear you're not feeling your best. 💙 If any of your concerns are related to your gums or oral health, I'm here to help. Sometimes gum problems can affect how we feel overall. What's troubling you?";
    }
    
    if (message.contains(RegExp(r'gum|tooth|teeth|mouth|oral|bleed|pain|hurt'))) {
      return _getGingivalResponse(message, message);
    }
    
    return "Thanks for sharing! If anything about your oral health is concerning you, I'm here to help. Otherwise, how can I assist you today? 😊";
  }
  
  // === GOODBYE DETECTION ===
  static bool _isGoodbye(String message) {
    final patterns = [
      'bye', 'goodbye', 'see you', 'later', 'farewell',
      'take care', 'gotta go', 'have to go', 'talk later',
      'see ya', 'cya', 'peace', 'cheers'
    ];
    
    return patterns.any((pattern) => message.contains(pattern));
  }
  
  static String _getGoodbyeResponse() {
    final responses = [
      "Take care! 👋 Remember to brush and floss daily. Come back anytime you have questions about gum health!",
      "Goodbye! 😊 Keep up the good oral hygiene habits. I'm always here if you need gum health advice!",
      "See you later! 🦷 Don't forget - healthy gums mean a healthy smile. Feel free to return with any questions!",
      "Bye for now! Take care of those gums, and don't hesitate to come back if you need help! 🌟",
      "Farewell! Remember: prevention is the best medicine for gum disease. See you next time! 😊"
    ];
    
    return responses[Random().nextInt(responses.length)];
  }
  
  // === GINGIVAL DISEASE DETECTION ===
  static bool _isGingivalRelated(String message) {
    final keywords = [
      // Direct gum terms
      'gum', 'gums', 'gingiv', 'periodon', 'gingiva',
      
      // Symptoms
      'bleed', 'bleeding', 'blood', 'swell', 'swollen', 'swelling',
      'inflam', 'red', 'tender', 'sore', 'pain', 'hurt', 'ache',
      'sensitive', 'receding', 'recession', 'loose teeth',
      
      // Conditions
      'gingivitis', 'periodontitis', 'gum disease', 'pyorrhea',
      'plaque', 'tartar', 'calculus', 'pocket', 'bone loss',
      
      // Oral hygiene
      'brush', 'floss', 'toothbrush', 'toothpaste', 'mouthwash',
      'rinse', 'clean', 'hygiene', 'oral care',
      
      // Treatment
      'scaling', 'root planing', 'deep clean', 'treatment',
      'dentist', 'periodontist', 'dental',
      
      // Other related
      'bad breath', 'halitosis', 'mouth', 'teeth', 'tooth'
    ];
    
    return keywords.any((keyword) => message.contains(keyword));
  }
  
  // === COMPREHENSIVE GINGIVAL DISEASE RESPONSES ===
  static String _getGingivalResponse(String message, String originalMessage) {
    // Check for specific conditions and symptoms
    if (_isAboutBleeding(message)) {
      return _getBleedingGumsResponse(message);
    }
    
    if (_isAboutPain(message)) {
      return _getGumPainResponse(message);
    }
    
    if (_isAboutSwelling(message)) {
      return _getSwellingResponse();
    }
    
    if (_isAboutGingivitis(message)) {
      return _getGingivitisResponse();
    }
    
    if (_isAboutPeriodontitis(message)) {
      return _getPeriodontitisResponse();
    }
    
    if (_isAboutPrevention(message)) {
      return _getPreventionResponse();
    }
    
    if (_isAboutTreatment(message)) {
      return _getTreatmentResponse();
    }
    
    if (_isAboutOralHygiene(message)) {
      return _getOralHygieneResponse();
    }
    
    if (_isAboutCauses(message)) {
      return _getCausesResponse();
    }
    
    if (_isAboutSymptoms(message)) {
      return _getSymptomsResponse();
    }
    
    // Default gingival response
    return _getGeneralGingivalInfo();
  }
  
  // === SPECIFIC CONDITION CHECKS ===
  static bool _isAboutBleeding(String message) {
    return message.contains('bleed') || message.contains('blood');
  }
  
  static bool _isAboutPain(String message) {
    return message.contains('pain') || message.contains('hurt') || 
           message.contains('ache') || message.contains('sore');
  }
  
  static bool _isAboutSwelling(String message) {
    return message.contains('swell') || message.contains('swollen') || 
           message.contains('puffy') || message.contains('inflam');
  }
  
  static bool _isAboutGingivitis(String message) {
    return message.contains('gingivitis') || 
           (message.contains('gum disease') && !message.contains('advanced'));
  }
  
  static bool _isAboutPeriodontitis(String message) {
    return message.contains('periodont') || message.contains('advanced') || 
           message.contains('bone loss') || message.contains('loose teeth');
  }
  
  static bool _isAboutPrevention(String message) {
    return message.contains('prevent') || message.contains('avoid') || 
           message.contains('stop') || message.contains('keep healthy');
  }
  
  static bool _isAboutTreatment(String message) {
    return message.contains('treat') || message.contains('cure') || 
           message.contains('fix') || message.contains('help with');
  }
  
  static bool _isAboutOralHygiene(String message) {
    return message.contains('brush') || message.contains('floss') || 
           message.contains('clean') || message.contains('hygiene');
  }
  
  static bool _isAboutCauses(String message) {
    return message.contains('cause') || message.contains('why') || 
           message.contains('reason') || message.contains('how do i get');
  }
  
  static bool _isAboutSymptoms(String message) {
    return message.contains('symptom') || message.contains('sign') || 
           message.contains('how do i know') || message.contains('what does');
  }
  
  // === DETAILED RESPONSES FOR SPECIFIC CONDITIONS ===
  
  static String _getBleedingGumsResponse(String message) {
    if (_userContext['mood'] == 'concerned' || message.contains('worried') || message.contains('scared')) {
      return """I understand bleeding gums can be concerning, but I have good news! 💙 

**Bleeding gums are usually reversible with proper care.**

Here's what you need to know:

🩸 **Why Gums Bleed:**
• Usually due to plaque buildup causing inflammation
• Your body's way of fighting bacteria
• NOT a sign to stop cleaning - it means clean more gently but thoroughly!

✅ **What To Do Right Now:**
1. **Continue brushing** - Use a soft brush, gentle circular motions
2. **Start flossing daily** - Yes, even if it bleeds at first
3. **Rinse with warm salt water** - 1/2 tsp salt in warm water, 2-3x daily
4. **Be patient** - Bleeding should decrease within 1-2 weeks

📈 **Expected Timeline:**
• Days 1-3: Might bleed more as you clean better
• Week 1: Noticeable improvement
• Week 2: Significant reduction in bleeding
• Week 3-4: Healthy, firm gums!

🚨 **See a dentist if:**
• Bleeding doesn't improve after 2 weeks of good care
• You have severe pain or swelling
• Bleeding is heavy or spontaneous

You're already taking the right step by asking about it! Most people see great improvement quickly. How long have you noticed the bleeding?""";
    }
    
    return """**Bleeding Gums - Here's Everything You Need to Know! 🩸**

Bleeding gums are super common and usually very treatable! Let me explain:

**🔍 Understanding the Bleeding:**
• **Main cause**: Bacterial plaque irritating your gums (gingivitis)
• **Good news**: Early gum disease is 100% reversible!
• **Key point**: Bleeding means "help me!" not "stop cleaning"

**🎯 Your Action Plan:**
1. **Gentle but thorough brushing** (2x daily, 2 minutes)
2. **Daily flossing** (yes, even if it bleeds!)
3. **Antibacterial mouthwash** (helps reduce bacteria)
4. **Salt water rinses** (natural healing boost)

**📊 What to Expect:**
• Week 1: Bleeding may initially increase (you're cleaning better!)
• Week 2: Noticeable improvement
• Week 3-4: Minimal to no bleeding

**💡 Pro Tips:**
• Use a soft-bristled brush
• Focus on the gum line where plaque hides
• Don't avoid bleeding areas - they need cleaning most!
• Stay consistent - it really works!

**⚕️ Professional Help:**
If bleeding persists beyond 2 weeks despite good care, see your dentist. You might need professional cleaning to remove hardened tartar.

What specific concerns do you have about the bleeding? When do you notice it most?""";
  }
  
  static String _getGumPainResponse(String message) {
    return """**Gum Pain Relief Guide 😣**

I'm sorry you're experiencing gum pain. Let's get you some relief and figure out what's going on:

**🆘 Immediate Relief (Next few hours):**
• **Ibuprofen**: 400-600mg (best for gum pain - reduces inflammation)
• **Cold compress**: Apply to outside of face, 20 min on/off
• **Salt water rinse**: Warm water + 1/2 tsp salt, swish gently
• **Avoid**: Hot, spicy, acidic, or crunchy foods

**🔍 Common Causes of Gum Pain:**
1. **Gingivitis**: Inflammation from plaque (most common)
2. **Food trauma**: Something stuck or injury from hard foods
3. **Aggressive brushing**: Using hard bristles or too much pressure
4. **Infection**: More serious, needs professional care

**📋 Assess Your Pain:**
• **Mild discomfort**: Try home care for 2-3 days
• **Moderate pain**: See dentist within a week
• **Severe pain**: See dentist within 1-2 days
• **With swelling/fever**: Seek immediate care

**🏠 Home Care Plan:**
1. Gentle brushing with ultra-soft brush
2. Warm salt water rinses 3-4x daily
3. Anti-inflammatory medication as directed
4. Soft, cool foods only
5. No tobacco or alcohol

**💡 Healing Tip:**
Even though it hurts, gentle cleaning is crucial. Avoiding the area can make it worse!

Can you describe your pain? Is it sharp, throbbing, or aching? How long have you had it?""";
  }
  
  static String _getSwellingResponse() {
    return """**Swollen Gums - Complete Guide 🔴**

Swollen gums are your body's inflammatory response to irritation. Here's what you need to know:

**🔍 Why Gums Swell:**
• **#1 cause**: Bacterial plaque accumulation
• **Other causes**: Hormonal changes, medications, vitamin deficiency
• **The swelling**: Blood vessels dilate to bring immune cells to fight bacteria

**📊 Assessing Your Swelling:**
• **Mild**: Slight puffiness, gums look shiny
• **Moderate**: Obvious swelling, may cover more of teeth
• **Severe**: Major swelling, possible pain, may affect face

**✅ Treatment Approach:**

**Immediate Care:**
1. **Gentle cleaning**: Soft brush, careful flossing
2. **Anti-inflammatory rinse**: Salt water or antiseptic mouthwash
3. **Cold compress**: Reduces swelling from outside
4. **Ibuprofen**: Reduces inflammation from inside

**This Week:**
• Excellent oral hygiene (even if tender!)
• Massage gums gently with clean finger
• Stay hydrated
• Avoid irritants (smoking, alcohol, spicy foods)

**📈 Expected Recovery:**
• Days 1-3: May feel worse before better
• Week 1: Noticeable improvement with good care
• Week 2-3: Return to normal if gingivitis
• Week 4+: If not better, need professional evaluation

**🚨 Red Flags - See Dentist Immediately:**
• Facial swelling
• Fever
• Difficulty swallowing
• Pus or discharge
• Severe pain

**Prevention is Key**: Once healed, maintain excellent oral hygiene to prevent recurrence!

How long have your gums been swollen? Is it throughout your mouth or in specific areas?""";
  }
  
  static String _getGingivitisResponse() {
    return """**Understanding Gingivitis - Your Complete Guide 🦷**

Great question! Gingivitis is the earliest stage of gum disease, and here's the fantastic news: **it's completely reversible!**

**📚 What is Gingivitis?**
• Inflammation of the gums caused by bacterial plaque
• The mildest form of gum disease
• Affects 75% of adults at some point
• 100% reversible with proper care!

**🔍 How to Recognize It:**
• **Red, puffy gums** (instead of pink and firm)
• **Bleeding** when brushing or flossing
• **Bad breath** that doesn't go away
• **Tender or sensitive** gums
• **No pain** in early stages (tricky!)

**🧫 What's Happening:**
1. Bacteria in plaque release toxins
2. Your immune system responds with inflammation
3. Blood vessels in gums become leaky (hence bleeding)
4. Without treatment, can progress to periodontitis

**💪 Your Treatment Plan:**

**Week 1-2: Intensive Care**
• Brush 2x daily (2 minutes, soft brush)
• Floss daily (yes, every single day!)
• Antibacterial mouthwash 2x daily
• Warm salt water rinses 3x daily

**Week 3-4: Establishing Routine**
• Continue excellent hygiene
• Consider electric toothbrush
• Focus on gum line cleaning
• Monitor improvement

**📈 Success Timeline:**
• Days 1-7: Increased bleeding (normal!)
• Week 2: Noticeable improvement
• Week 3-4: Dramatic improvement
• Week 6: Complete reversal possible!

**🎯 Professional Care:**
• Dental cleaning removes tartar you can't
• Usually need cleaning every 6 months
• More frequent if prone to gingivitis

**⚡ Prevention Forever:**
• 2-minute brushing, twice daily
• Daily flossing (non-negotiable!)
• Regular dental visits
• Limit sugary snacks
• Don't smoke

**The best part? You caught it early! With consistent care, you can have perfectly healthy gums.**

Have you noticed any of these symptoms? How long do you think you've had gingivitis?""";
  }
  
  static String _getPeriodontitisResponse() {
    return """**Periodontitis - Advanced Gum Disease Explained 🦷**

Periodontitis is a more serious form of gum disease, but don't panic - modern treatments are very effective!

**📚 Understanding Periodontitis:**
• Advanced stage of gum disease
• Involves bone and tissue loss around teeth
• Cannot be completely reversed BUT can be controlled
• Affects 47% of adults over 30

**🔍 How It Differs from Gingivitis:**
• **Gingivitis**: Just gum inflammation (reversible)
• **Periodontitis**: Permanent damage to support structures
• **Key difference**: Attachment loss and bone destruction

**⚠️ Warning Signs:**
• Gums pulling away from teeth (pockets)
• Persistent bad breath or bad taste
• Loose or shifting teeth
• Changes in bite or how teeth fit together
• Pus between teeth and gums
• Tooth sensitivity

**🏥 Professional Treatment Options:**

**1. Non-Surgical:**
• **Scaling & Root Planing**: Deep cleaning under gums
• **Antibiotics**: Topical or oral to fight infection
• **Laser therapy**: Removes infected tissue

**2. Surgical (if needed):**
• **Flap surgery**: Access for deep cleaning
• **Bone grafts**: Restore lost bone
• **Tissue grafts**: Cover exposed roots

**🏠 Your Role in Treatment:**
• Meticulous oral hygiene (critical!)
• Quit smoking (biggest risk factor)
• Manage diabetes if present
• Regular professional maintenance
• Follow all treatment recommendations

**📊 Treatment Success:**
• With good care: 85% success in halting progression
• Key factor: Your daily home care
• Maintenance visits: Every 3-4 months

**💡 Living with Periodontitis:**
• It's a chronic condition (like diabetes)
• Requires lifelong management
• Can keep your teeth with proper care!
• Many people live normally with controlled periodontitis

**🎯 Next Steps:**
1. See a periodontist for evaluation
2. Get comprehensive treatment plan
3. Commit to excellent home care
4. Keep all maintenance appointments

Remember: While periodontitis is serious, it's very manageable with proper treatment and care!

Do you have specific symptoms you're concerned about? Have you seen a dentist recently?""";
  }
  
  static String _getPreventionResponse() {
    return """**Complete Gum Disease Prevention Guide 🛡️**

Prevention is SO much easier (and cheaper!) than treatment. Here's your comprehensive plan:

**🏆 The Foundation - Daily Habits:**

**🪥 Brushing Excellence:**
• **2 minutes, 2x daily** (set a timer!)
• **45° angle** toward gum line
• **Gentle pressure** - let bristles do the work
• **Systematic approach** - don't miss spots
• **Soft bristles only** - replace every 3 months

**🧵 Flossing Mastery:**
• **Once daily minimum** (bedtime is best)
• **18 inches** of floss, wrap around fingers
• **C-shape** around each tooth
• **Below gum line** - that's where bacteria hide
• **Fresh section** for each tooth

**🧪 Chemical Support:**
• **Fluoride toothpaste** - strengthens teeth
• **Antibacterial mouthwash** - reduces bacteria
• **Not a substitute** for brushing/flossing!

**🍎 Lifestyle Prevention:**

**Diet:**
• Limit sugary snacks between meals
• Choose water over sugary drinks
• Eat crunchy vegetables (natural cleaners!)
• Dairy products help neutralize acids
• Green tea has natural antibacterials

**Habits:**
• **Don't smoke** - #1 preventable risk factor
• **Manage stress** - weakens immune system
• **Stay hydrated** - dry mouth increases risk
• **Breathe through nose** - mouth breathing dries gums

**📅 Professional Prevention:**
• **Cleanings every 6 months** (or as recommended)
• **Annual comprehensive exams**
• **X-rays as needed** to catch hidden problems
• **Discuss risk factors** with dentist

**⚡ Power-Up Your Prevention:**

**Advanced Tools:**
• Electric toothbrush (21% better plaque removal)
• Water flosser (great addition, not replacement)
• Interdental brushes for larger spaces
• Tongue scraper (removes bacteria)

**🎯 High-Risk? Extra Steps:**
• **Diabetes?** Keep blood sugar controlled
• **Pregnant?** Extra vigilant care needed
• **Family history?** May need 3-4 month cleanings
• **Smoker?** Quit programs available!

**📊 Prevention Success Rate:**
• With good hygiene: 95% prevention rate
• With excellent hygiene + professional care: 98%+
• Even high-risk individuals: 80-85% with extra care

**💡 The 2-Minute Rule:**
Most gum disease starts because people rush. Those 2 minutes of brushing seem long but save hours in the dental chair!

**Your Prevention Score:**
Rate yourself 1-10 on:
• Brushing consistency
• Flossing frequency  
• Professional visits
• Lifestyle factors

Where do you think you need the most improvement? I can give specific tips!""";
  }
  
  static String _getTreatmentResponse() {
    return """**Gum Disease Treatment Options - Complete Guide 💊**

The treatment depends on severity, but all gum disease is treatable! Here's what to expect:

**📊 Treatment by Stage:**

**Stage 1: Gingivitis (Reversible!)**
• **Professional cleaning** to remove tartar
• **Improved home care** routine
• **Antibacterial rinses** if needed
• **Timeline**: 2-4 weeks to reverse
• **Success rate**: Nearly 100%

**Stage 2: Early Periodontitis**
• **Scaling & root planing** (deep cleaning)
• **Possible antibiotics** (pills or gels)
• **More frequent cleanings** (every 3-4 months)
• **Timeline**: 4-6 weeks initial healing
• **Success rate**: 85-90% halt progression

**Stage 3-4: Advanced Periodontitis**
• **Surgical options** may be needed
• **Bone/tissue grafts** for severe cases
• **Tooth extraction** if not savable
• **Ongoing maintenance** critical
• **Success varies** based on compliance

**🏠 Home Treatment Essentials:**

**Immediate Relief:**
• Warm salt water rinses (3-4x daily)
• Gentle brushing with soft brush
• Antibacterial mouthwash
• Anti-inflammatory diet
• Pain management as needed

**Daily Protocol:**
1. Morning: Thorough brushing + mouthwash
2. After meals: Rinse or gentle brush
3. Evening: Brush + floss + rinse
4. Throughout: Stay hydrated

**🏥 Professional Treatments:**

**Non-Surgical:**
• **Regular cleaning**: Removes plaque/tartar above gums
• **Deep cleaning**: Below gum line, may need anesthetic
• **Laser therapy**: Removes diseased tissue precisely
• **Antibiotic therapy**: Local or systemic

**Surgical (Advanced Cases):**
• **Pocket reduction**: Easier cleaning access
• **Regeneration**: Restore lost bone/tissue
• **Soft tissue grafts**: Cover exposed roots
• **Guided tissue regeneration**: Regrow support

**💰 Treatment Costs (Approximate):**
• Basic cleaning: \$75-200
• Deep cleaning: \$500-1000
• Antibiotics: \$50-300
• Surgery: \$1000-3000 per area
• *Insurance often covers 50-80%*

**📈 Success Factors:**
1. **Early detection** (huge difference!)
2. **Patient compliance** (#1 factor)
3. **Professional skill**
4. **Overall health management**
5. **Lifestyle factors** (smoking cessation)

**⏰ Treatment Timeline:**
• Week 1-2: Initial treatment/healing
• Month 1-3: Major improvement phase
• Month 3-6: Stabilization
• Ongoing: Maintenance for life

**💡 Key to Success:**
The BEST treatment is the one you'll stick with! Consistency beats perfection.

What stage do you think you're at? Or are you asking about treatment options in general?""";
  }
  
  static String _getOralHygieneResponse() {
    return """**Master-Level Oral Hygiene Guide 🦷✨**

Let me teach you the techniques that dental professionals use themselves!

**🪥 PERFECT BRUSHING TECHNIQUE:**

**The Modified Bass Method (Gold Standard):**
1. **45° angle** - Bristles toward gum line
2. **Gentle vibration** - Small circular motions
3. **10-15 strokes** per area
4. **Systematic path** - Same route every time
5. **2 full minutes** - 30 seconds per quadrant

**Toothbrush Selection:**
• **Soft bristles ONLY** - Medium/hard damage gums
• **Small head** - Reaches back teeth better
• **Replace every 3 months** - Or when frayed
• **Electric?** Even better! 21% more effective

**🧵 FLOSSING LIKE A PRO:**

**Perfect Technique:**
1. **18 inches** of floss (wrap around middle fingers)
2. **Leave 1-2 inches** between hands
3. **Gentle sawing** to get past contact point
4. **C-shape** around tooth (hug it!)
5. **Up and down** below gum line
6. **New section** for each space

**Can't Floss? Alternatives:**
• Water flossers (great for braces)
• Interdental brushes (wider spaces)
• Floss picks (better than nothing)
• Floss threaders (for bridges)

**🧪 MOUTHWASH FACTS:**

**Types & Benefits:**
• **Antibacterial**: Reduces gingivitis-causing bacteria
• **Fluoride**: Strengthens teeth
• **Cosmetic**: Just freshens breath
• **Prescription**: For severe cases

**How to Use:**
• AFTER brushing/flossing
• Swish 30-60 seconds
• Don't rinse with water after
• Wait 30 minutes before eating/drinking

**⏰ OPTIMAL TIMING:**

**Morning Routine:**
1. Brush BEFORE breakfast (protects teeth)
2. Or wait 30-60 min after eating
3. Quick rinse after coffee/juice

**Evening Routine (MOST IMPORTANT):**
1. Floss first (loosens debris)
2. Brush thoroughly
3. Mouthwash last
4. Nothing but water after!

**🎯 PROBLEM AREAS:**

**Often Missed Spots:**
• Behind lower front teeth
• Back sides of molars
• Along the gum line
• Tongue surface (lots of bacteria!)

**💡 PRO TIPS:**

**Level Up Your Routine:**
• Use disclosing tablets occasionally (shows missed plaque)
• Brush your tongue or use scraper
• Time yourself (most people only brush 45 seconds)
• Put toothbrush in non-dominant hand monthly (finds missed spots)

**🚫 COMMON MISTAKES:**

• Brushing too hard (causes recession)
• Horizontal scrubbing (use circles/vibration)
• Rinsing after brushing (removes fluoride)
• Sharing toothbrushes (spreads bacteria)
• Brushing immediately after acids (wait 30 min)

**📊 HYGIENE SCORE CARD:**

Rate yourself:
□ Brush 2x daily for 2 minutes
□ Floss every single day
□ Use proper technique
□ Replace brush regularly
□ See dentist 2x yearly

**5/5 = Excellent**
**3-4/5 = Good (room to improve)**
**<3/5 = Need to step it up!**

**🎬 VISUAL LEARNER?**
Ask your dental hygienist to demonstrate at your next visit - they love teaching proper technique!

What part of your oral hygiene routine would you like to improve? I can give specific guidance!""";
  }
  
  static String _getCausesResponse() {
    return """**What Causes Gum Disease? The Complete Picture 🔍**

Understanding the causes helps you prevent it! Here's everything you need to know:

**🦠 THE MAIN CULPRIT: Bacterial Plaque**

**What is Plaque?**
• Sticky, colorless film of bacteria
• Forms on teeth within 4-12 hours
• Contains 300+ species of bacteria
• Some bacteria are harmful, others helpful

**How Plaque Causes Disease:**
1. Bacteria produce toxins and acids
2. These irritate and inflame gums
3. Your immune system responds (redness, swelling)
4. Without removal, damages supporting structures

**⚡ RISK FACTORS THAT INCREASE YOUR CHANCES:**

**🚬 #1 Risk Factor: SMOKING**
• 4-6x higher risk of gum disease
• Masks symptoms (less bleeding)
• Slows healing dramatically
• Reduces treatment success

**🍬 Diet & Nutrition:**
• High sugar = more bacterial food
• Frequent snacking = constant acid attacks
• Vitamin C deficiency = weak gums
• Poor nutrition = weak immune response

**🧬 Genetics (30% of population):**
• Family history increases risk
• Some people more susceptible
• Need extra preventive care
• Can still prevent with good habits!

**⚕️ Medical Conditions:**
• **Diabetes** - 3x higher risk
• **Heart disease** - linked inflammation
• **Rheumatoid arthritis** - shared pathways
• **Osteoporosis** - bone density issues

**💊 Medications That Increase Risk:**
• Drugs causing dry mouth (antihistamines, antidepressants)
• Drugs causing gum overgrowth (some blood pressure meds)
• Immunosuppressants
• Oral contraceptives (hormonal changes)

**🔄 Hormonal Changes:**
• **Puberty** - increased blood flow to gums
• **Menstruation** - monthly sensitivity
• **Pregnancy** - "pregnancy gingivitis" in 70%
• **Menopause** - decreased estrogen affects gums

**😰 Stress & Lifestyle:**
• Weakens immune system
• Often leads to poor self-care
• Grinding/clenching damages gums
• Poor sleep affects healing

**🦷 Local Factors:**
• Crooked teeth (harder to clean)
• Old fillings with rough edges
• Mouth breathing (dries out gums)
• Tongue/lip piercings (irritation)

**📊 RISK ASSESSMENT:**

**Low Risk:**
✓ No smoking
✓ Good oral hygiene
✓ Healthy diet
✓ No medical conditions
✓ Regular dental visits

**Moderate Risk:**
• 1-2 risk factors
• Inconsistent hygiene
• Occasional dental visits

**High Risk:**
• Smoking
• Diabetes
• Family history
• Poor oral hygiene
• Multiple risk factors

**💡 THE GOOD NEWS:**
Even with multiple risk factors, excellent oral hygiene can prevent gum disease in most people!

**🎯 YOUR PERSONAL ACTION PLAN:**
1. Identify your risk factors
2. Control what you can (hygiene, smoking, diet)
3. Manage medical conditions
4. More frequent dental visits if high risk
5. Don't give up - prevention works!

Which risk factors apply to you? I can help you create a personalized prevention strategy!""";
  }
  
  static String _getSymptomsResponse() {
    return """**Gum Disease Symptoms - Complete Recognition Guide 👀**

Catching symptoms early makes ALL the difference! Here's what to watch for:

**🟢 HEALTHY GUMS LOOK LIKE:**
• **Color**: Coral pink (varies by skin tone)
• **Texture**: Firm, stippled (like orange peel)
• **Shape**: Fits snugly around teeth
• **Feel**: No pain or sensitivity
• **Function**: No bleeding with normal brushing

**🟡 EARLY WARNING SIGNS (Gingivitis):**

**Visual Changes:**
• Gums turning red, especially at gum line
• Slight puffiness or swelling
• Loss of stippled texture (smooth/shiny)
• Gum margin looks rolled or rounded

**Functional Changes:**
• Bleeding during brushing/flossing
• Occasional bleeding when eating hard foods
• Tender when touched
• Mild bad breath

**What You Feel:**
• Usually NO pain (tricky!)
• Slight sensitivity
• "Different" feeling in mouth

**🟠 MODERATE SYMPTOMS (Early Periodontitis):**

**Visual:**
• Darker red or purplish gums
• More obvious swelling
• Gums starting to pull away
• Visible plaque/tartar buildup
• Spaces appearing between teeth

**Functional:**
• Bleeding more easily
• Persistent bad breath/taste
• Sensitive to hot/cold
• Discomfort when chewing

**New Problems:**
• Food getting stuck more
• Teeth looking "longer"
• Black triangles between teeth

**🔴 ADVANCED SYMPTOMS (Serious):**

**Major Warning Signs:**
• Gums severely receded
• Pus between teeth and gums
• Teeth feeling loose/shifting
• Changes in bite/jaw alignment
• Painful chewing
• Partial tooth loss

**Systemic Effects:**
• Constant bad taste
• Severe halitosis
• Possible fever/malaise
• Swollen lymph nodes

**🎯 SELF-CHECK GUIDE:**

**Daily Mirror Check:**
1. Lift lips, check gum color
2. Look for swelling/puffiness
3. Check for receding gums
4. Note any changes

**Weekly Assessment:**
• Do gums bleed when brushing?
• Any persistent bad breath?
• Teeth feel different?
• Food trapping more?

**Monthly Deep Check:**
• Take photos to track changes
• Feel teeth for looseness
• Check for widening gaps
• Note sensitivity changes

**⚡ SYMPTOMS THAT NEED IMMEDIATE ATTENTION:**

**See Dentist Within 24-48 Hours:**
• Severe pain
• Facial swelling
• Pus/discharge
• Fever with gum symptoms
• Sudden loosening of teeth

**See Dentist Within 1 Week:**
• Bleeding that won't stop
• Rapid changes in gums
• New spaces between teeth
• Persistent bad taste

**📊 SYMPTOM PROGRESSION TIMELINE:**

**Without Treatment:**
• Week 1-2: Mild gingivitis begins
• Month 1-6: Gingivitis worsens
• Year 1-2: May progress to periodontitis
• Year 2-5: Significant damage possible
• Year 5+: Risk of tooth loss

**With Treatment:**
• Week 1-2: Symptoms stabilize
• Week 3-4: Major improvement
• Month 2-3: Resolution of gingivitis
• Ongoing: Maintained health!

**💡 TRICKY TRUTHS:**

• **Smoking masks symptoms** (less bleeding)
• **No pain ≠ no problem** (gum disease is often painless)
• **Symptoms can come and go** (disease still progressing)
• **Some people show fewer symptoms** (still have disease)

**YOUR SYMPTOM CHECKLIST:**
□ Red or purple gums
□ Bleeding when brushing
□ Swollen/puffy gums
□ Bad breath
□ Receding gums
□ Loose teeth
□ Pain or tenderness
□ Pus or discharge

**How many did you check? Even 1-2 means you should take action!**

Which symptoms are you experiencing? I can help you understand what they mean and what to do next!""";
  }
  
  static String _getGeneralGingivalInfo() {
    return """**Welcome to Your Gum Health Journey! 🦷**

I'm so glad you're interested in learning about gum health. It's one of the most important (yet overlooked) aspects of overall health!

**📚 Gum Disease Basics:**

**What is it?**
• Infection of tissues supporting your teeth
• Ranges from mild (gingivitis) to severe (periodontitis)
• Affects 75% of adults at some point
• Good news: Early stages are completely reversible!

**Why Should You Care?**
• #1 cause of tooth loss in adults
• Linked to heart disease, diabetes, pregnancy complications
• Can affect your confidence and quality of life
• Prevention is SO much easier than treatment!

**🎯 Quick Facts:**
• Caused mainly by bacterial plaque
• Often painless in early stages
• Bleeding gums are NOT normal
• Can develop in just 2 weeks of poor hygiene
• Reversible with good care in early stages

**🛡️ Your Defense Strategy:**
1. **Daily habits** - Brush 2x, floss 1x
2. **Regular checkups** - Every 6 months
3. **Know the signs** - Red, bleeding, swollen gums
4. **Act quickly** - Early treatment = easy fix!

**💡 Remember:**
Your mouth is the gateway to your body. Healthy gums = healthier you!

**What specific aspect of gum health interests you most?**
• Preventing problems
• Understanding symptoms
• Treatment options
• Connection to overall health
• Something else?

I'm here to help with whatever you need! 😊""";
  }
  
  // === GENERAL HEALTH QUESTIONS ===
  static bool _isGeneralHealthQuestion(String message) {
    final nonGingivalHealth = [
      'headache', 'stomach', 'back pain', 'cold', 'flu', 'fever',
      'diabetes', 'heart', 'blood pressure', 'cancer', 'arthritis'
    ];
    
    return nonGingivalHealth.any((term) => message.contains(term)) && 
           !_isGingivalRelated(message);
  }
  
  static String _redirectToGingivalFocus(String message) {
    return """I understand you're asking about ${_extractHealthTopic(message)}. While I'd love to help with all health topics, I'm specifically designed as a gum health specialist! 🦷

However, did you know that gum health is connected to many other health conditions? For example:
• Gum disease is linked to heart disease and diabetes
• Good oral health supports overall immune function
• Many medications can affect your gums

Is there anything about your gum health or oral care I can help you with? Or would you like to know how gum health might relate to your other health concerns? 😊""";
  }
  
  static String _extractHealthTopic(String message) {
    final topics = ['headache', 'stomach', 'back pain', 'cold', 'flu', 'fever',
                    'diabetes', 'heart', 'blood pressure', 'cancer', 'arthritis'];
    
    for (final topic in topics) {
      if (message.contains(topic)) return topic;
    }
    return "general health";
  }
  
  // === DEFAULT CONVERSATIONAL RESPONSES ===
  static String _getDefaultConversationalResponse(String message) {
    final responses = [
      "That's interesting! While I'm specifically trained in gum health and oral care, I'm happy to chat. Is there anything about your dental health you'd like to discuss? 😊",
      
      "I appreciate you sharing that! As a gum health specialist, I'm always here if you have any questions about oral care, bleeding gums, or preventing gum disease. How are your gums doing these days?",
      
      "Thanks for chatting with me! 🦷 I'm designed to be an expert on all things related to gum health. If you ever have questions about gingivitis, oral hygiene, or keeping your smile healthy, I'm your go-to AI!",
      
      "I enjoy our conversation! While my expertise is in gingival disease and oral health, I'm here to help however I can. Have you had any concerns about your gums or teeth lately?",
      
      "That's great to hear! By the way, when was your last dental check-up? As your friendly gum health AI, I'm always curious about how people are taking care of their smiles! 😊"
    ];
    
    return responses[Random().nextInt(responses.length)];
  }
  
  // === SPECIAL FEATURES ===
  
  static String getBotWelcomeMessage() {
    return """🦷 **Welcome! I'm GingiGPT - Your Personal Gum Health AI Assistant!**

Hello! I'm so excited to meet you! I'm an AI specifically designed to be your expert companion for everything related to gum health and gingival disease. Think of me as a friendly, knowledgeable friend who happens to know A LOT about keeping your gums healthy! 😊

**💬 How I Can Help You:**
• Answer any questions about gum disease, bleeding gums, or oral health
• Explain symptoms and what they mean
• Guide you through prevention and treatment options
• Share tips for better oral hygiene
• Provide emotional support if you're worried about your gums
• Just chat about dental health in a friendly, approachable way!

**🌟 What Makes Me Special:**
• I understand context and remember our conversation
• I can explain things simply or in detail - whatever you prefer
• I'm available 24/7 to answer your questions
• I combine expert knowledge with a caring, conversational approach
• I'll never judge - I'm here to help and support!

**💡 Fun Fact:** Did you know that 75% of adults will experience gum disease at some point? The good news is that early gum disease is completely reversible with proper care!

**So, what brings you here today?**
• Concerned about bleeding gums?
• Want to learn about prevention?
• Questions about symptoms you're experiencing?
• Just want to improve your oral health?
• Or simply want to say hi? 

Whatever it is, I'm here to help! Feel free to ask me anything or just chat. I love talking about gum health (yes, I'm that enthusiastic about it! 😄).

How can I help you today? 🦷✨""";
  }
  
  static void resetContext() {
    _conversationHistory.clear();
    _userContext = {
      'name': null,
      'symptoms': [],
      'concerns': [],
      'mood': 'neutral',
      'lastTopic': null,
    };
  }
  
  static Map<String, dynamic> getConversationAnalytics() {
    final topics = <String>[];
    for (var entry in _conversationHistory) {
      if (entry['role'] == 'user') {
        final msg = entry['message'].toString().toLowerCase();
        if (msg.contains('bleed')) topics.add('bleeding');
        if (msg.contains('pain')) topics.add('pain');
        if (msg.contains('gingiv')) topics.add('gingivitis');
        if (msg.contains('prevent')) topics.add('prevention');
      }
    }
    
    return {
      'total_messages': _conversationHistory.length,
      'user_mood': _userContext['mood'],
      'discussed_topics': topics.toSet().toList(),
      'symptoms_mentioned': _userContext['symptoms'],
      'concerns': _userContext['concerns'],
    };
  }
}