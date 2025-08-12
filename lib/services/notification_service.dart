import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static Timer? _timer;
  static List<String> _debugLogs = [];
  
  // 🔑 Track current user sign-in status
  static User? _currentUser;
  static StreamSubscription<User?>? _authSubscription;

  // Debug logging
  static void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = "[$timestamp] $message";
    print("🔔 $logMessage");
    _debugLogs.insert(0, logMessage);
    if (_debugLogs.length > 100) _debugLogs.removeRange(100, _debugLogs.length);
  }

  static List<String> getDebugLogs() => List.from(_debugLogs);
  static void clearDebugLogs() => _debugLogs.clear();

  // 🔑 Check if user is currently signed in
  static bool get isUserSignedIn => _currentUser != null;
  static String? get currentUserId => _currentUser?.uid;

  static Future<void> init() async {
    try {
      _log('🚀 Initializing Enhanced Notification System with Calendar Integration...');
      
      // 🔑 Listen to auth state changes
      _startAuthListener();
      
      tz.initializeTimeZones();
      _log('✅ Timezone initialized');
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      bool? initialized = await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      _log('✅ Plugin initialized: $initialized');

      // Create notification channels
      if (Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              'medication_reminders',
              'Medication Reminders',
              description: 'Medication reminder notifications',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            ),
          );
          
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              'messages',
              'Messages',
              description: 'Message notifications',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            ),
          );
          
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              'system',
              'System Notifications',
              description: 'System and app notifications',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            ),
          );
          await androidImplementation.createNotificationChannel(
  const AndroidNotificationChannel(
    'medication_reminders_v2', // <-- This matches your scheduled notifications
    'Medication Reminders',
    description: 'Medication reminder notifications (v2)',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('ringtone126505'), // custom sound
    enableVibration: true,
    showBadge: true,
  ),
);
          
          _log('✅ All notification channels created');
        }
      }

      // Request permissions
      await _requestPermissions();
      
      _isInitialized = true;
      _log('✅ Enhanced notification system with calendar integration ready!');
      
    } catch (e) {
      _log('❌ Error initializing: $e');
      _isInitialized = false;
    }
  }

  // 🔑 Listen to authentication state changes
  static void _startAuthListener() {
    _authSubscription?.cancel();
    
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      final wasSignedIn = _currentUser != null;
      _currentUser = user;
      final isNowSignedIn = _currentUser != null;
      
      _log('🔑 Auth state changed: ${user?.uid ?? 'signed out'}');
      
      if (!wasSignedIn && isNowSignedIn) {
        // User just signed in
        _log('👋 User signed in - enabling notifications and calendar sync');
        _onUserSignedIn();
      } else if (wasSignedIn && !isNowSignedIn) {
        // User just signed out
        _log('👋 User signed out - disabling notifications');
        _onUserSignedOut();
      }
    });
  }

  // 🔑 Handle user sign in
  static Future<void> _onUserSignedIn() async {
    try {
      _log('🔓 Processing user sign-in with calendar sync...');
      
      // Wait a moment for Firebase to be ready
      await Future.delayed(Duration(seconds: 1));
      
      // Check for missed content while user was signed out - only create in-app notifications
      await checkMissedRemindersOnSignIn();
      await checkAndCreateNotificationsForFiredReminders(_currentUser!.uid);
      await checkMissedMessagesOnSignIn();
      
      // Reschedule all active reminders for this user
      await _rescheduleUserReminders();
      
      _log('✅ Sign-in processing with calendar sync complete');
    } catch (e) {
      _log('❌ Error processing sign-in: $e');
    }
  }

  // 🔑 Handle user sign out
  static Future<void> _onUserSignedOut() async {
    try {
      _log('🔒 Processing user sign-out...');
      
      // Cancel all scheduled notifications when user signs out
      await _notificationsPlugin.cancelAll();
      _log('🗑️ All notifications cancelled due to sign-out');
      
      _log('✅ Sign-out processing complete');
    } catch (e) {
      _log('❌ Error processing sign-out: $e');
    }
  }

  // 🔧 ENHANCED: Reschedule all reminders when user signs in
  static Future<void> _rescheduleUserReminders() async {
    if (!isUserSignedIn) return;
    
    try {
      _log('🔄 Rescheduling all reminders for signed-in user...');
      
      final reminders = await _firestore
          .collection('medication_reminders')
          .where('userId', isEqualTo: currentUserId)
          .where('active', isEqualTo: true)
          .get();
      
      _log('📋 Found ${reminders.docs.length} active reminders to reschedule');
      
      for (final doc in reminders.docs) {
        final data = doc.data();
        final medicationId = doc.id;
        final medicationName = data['medication'] ?? 'Your medication';
        final hour = data['hour'] ?? 0;
        final minute = data['minute'] ?? 0;
        final daysOfWeek = List<bool>.from(data['daysOfWeek'] ?? []);
        
        _log('📅 Rescheduling: $medicationName at $hour:$minute');
        
        // Use internal method that doesn't send confirmation
        await _scheduleMedicationReminderInternal(
          medicationId: medicationId,
          medicationName: medicationName,
          hour: hour,
          minute: minute,
          daysOfWeek: daysOfWeek,
          userId: currentUserId!,
          sendConfirmation: false, // Don't send confirmation when rescheduling
        );
      }
      
      _log('✅ All reminders rescheduled');
    } catch (e) {
      _log('❌ Error rescheduling reminders: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    _log('📱 Requesting permissions...');
    
    if (Platform.isAndroid) {
      var status = await Permission.notification.request();
      _log('📱 Notification permission: $status');
      
      
      
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final bool? areEnabled = await androidImplementation.areNotificationsEnabled();
        _log('🔔 Notifications enabled: $areEnabled');
        
        if (areEnabled == false) {
          _log('❌ CRITICAL: Notifications are disabled in system settings!');
        }
      }
      
    } else if (Platform.isIOS) {
      final bool? result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      _log('🍎 iOS permissions granted: $result');
    }
  }

  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    _log('🔔 Notification tapped: ${notificationResponse.payload}');
  }

  // 🔧 MAIN METHOD: Schedule medication reminders - public interface with calendar integration
  static Future<void> scheduleMedicationReminder({
    required String medicationId,
    required String medicationName,
    required int hour,
    required int minute,
    required List<bool> daysOfWeek,
    String? userId,
  }) async {
    await _scheduleMedicationReminderInternal(
      medicationId: medicationId,
      medicationName: medicationName,
      hour: hour,
      minute: minute,
      daysOfWeek: daysOfWeek,
      userId: userId,
      sendConfirmation: true, // Send confirmation for new reminders
    );
  }

  // 🔧 INTERNAL METHOD: Schedule medication reminders with confirmation control and calendar integration
  static Future<void> _scheduleMedicationReminderInternal({
    required String medicationId,
    required String medicationName,
    required int hour,
    required int minute,
    required List<bool> daysOfWeek,
    String? userId,
    required bool sendConfirmation,
  }) async {
    try {
      _log('📅 Scheduling medication reminder for $medicationName at $hour:$minute with calendar integration');
      _log('📅 Days: ${daysOfWeek.toString()}');
      _log('📅 User signed in: $isUserSignedIn');
      _log('📅 Send confirmation: $sendConfirmation');
      
      if (!_isInitialized) {
        _log('🔄 NotificationService not initialized, initializing now...');
        await init();
      }

      // Cancel any existing reminders for this medication
      await cancelMedicationReminder(medicationId);
      
      // Only schedule device notifications if user is signed in
      if (isUserSignedIn) {
        final daysOfWeekNumbers = [1, 2, 3, 4, 5, 6, 7]; // Monday=1, Sunday=7
        int scheduledCount = 0;
        
        for (int i = 0; i < daysOfWeek.length; i++) {
          if (daysOfWeek[i]) {
            final dayOfWeek = daysOfWeekNumbers[i];
            DateTime scheduledDate = _getNextOccurrence(dayOfWeek, hour, minute);
            final notificationId = _generateNotificationId(medicationId, dayOfWeek);
            
            _log('📅 Scheduling for ${_getDayName(dayOfWeek)}: ID=$notificationId, Time=$scheduledDate');
            
            await _scheduleWeeklyNotification(
              id: notificationId,
              title: 'Medication Reminder',
              body: 'Time to take your $medicationName',
              scheduledDate: scheduledDate,
              payload: 'medication:$medicationId:$medicationName',
              medicationName: medicationName,
            );
            
            scheduledCount++;
          }
        }
        
        _log('✅ Total device notifications scheduled: $scheduledCount');
        await _verifyScheduledNotifications(medicationId);
      }
      
      // 🔧 ENHANCED: Store reminder in Firestore for backup checking AND calendar integration
      await _firestore.collection('medication_reminders').doc(medicationId).set({
        'userId': userId ?? currentUserId,
        'medication': medicationName,
        'hour': hour,
        'minute': minute,
        'daysOfWeek': daysOfWeek,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // 🔧 NEW: Calendar integration fields
        'calendarIntegration': true,
        'type': 'medication',
        'title': medicationName,
        'description': 'Medication reminder at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      });
      
      _log('✅ Reminder stored in Firestore with calendar integration enabled');
      
      // Only send confirmation notification when requested
      if (sendConfirmation && (userId != null || isUserSignedIn)) {
        await sendReminderNotification(
          userId: userId ?? currentUserId!,
          title: 'Medication Reminder Set',
          message: 'You will get notified at $hour:${minute.toString().padLeft(2, '0')} for $medicationName. This reminder will also appear in your calendar.',
          medicationName: medicationName,
        );
        _log('✅ Confirmation notification sent with calendar info');
      } else {
        _log('⏭️ Confirmation notification skipped (rescheduling or not requested)');
      }
      
      _log('✅ Medication reminder setup completed for $medicationName (integrated with calendar)');
    } catch (e) {
      _log('❌ Error scheduling medication reminder: $e');
    }
  }

  static Future<void> _verifyScheduledNotifications(String medicationId) async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      final medicationNotifications = pending.where((req) => 
          req.payload?.contains(medicationId) == true).toList();
      
      _log('🔍 Verification: Found ${medicationNotifications.length} scheduled notifications for $medicationId');
      
      for (final notif in medicationNotifications) {
        _log('   - ID: ${notif.id}, Title: ${notif.title}');
      }
      
    } catch (e) {
      _log('❌ Error verifying notifications: $e');
    }
  }
static Future<void> _scheduleWeeklyNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledDate,
  required String medicationName,
  String? payload,
}) async {
  try {
    final now = tz.TZDateTime.now(tz.local);
    if (scheduledDate.isBefore(now)) {
      _log('⚠️ Scheduled date $scheduledDate is in the past. Adjusting to next week.');
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_reminders_v2',
          'Medication Reminders',
          channelDescription: 'Medication reminder notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('ringtone126505'),
          autoCancel: true,
          ongoing: false,
          styleInformation: BigTextStyleInformation(
            body.isNotEmpty ? body : 'Time to take your medication',
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'medication_reminder',
        ),
      ),
      payload: payload,
      // ✅ SAFE for Google Play (no special permission needed)
      androidScheduleMode: AndroidScheduleMode.inexact,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    _log('✅ Weekly notification scheduled successfully (ID: $id) at $scheduledDate');
  } catch (e, stacktrace) {
    _log('❌ Error scheduling weekly notification: $e\n$stacktrace');
  }
}


static int _generateNotificationId(String medicationId, int dayOfWeek) {
  final baseId = medicationId.hashCode.abs() % 100000;
  return baseId * 10 + dayOfWeek;
}



  static DateTime _getNextOccurrence(int dayOfWeek, int hour, int minute) {
    final now = DateTime.now();
    DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    
    int targetWeekday = dayOfWeek;
    int daysToAdd = (targetWeekday - now.weekday) % 7;
    
    if (daysToAdd == 0 && now.isAfter(scheduled)) {
      daysToAdd = 7;
    }
    
    scheduled = scheduled.add(Duration(days: daysToAdd));
    
    _log('📅 Next $targetWeekday occurrence: $scheduled');
    return scheduled;
  }

  static String _getDayName(int dayOfWeek) {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[dayOfWeek];
  }

  // 🔧 ENHANCED: Cancel medication reminder with calendar integration
  static Future<void> cancelMedicationReminder(String medicationId) async {
    try {
      _log('🗑️ Cancelling notifications for medication: $medicationId');
      
      for (int day = 1; day <= 7; day++) {
        final notificationId = _generateNotificationId(medicationId, day);
        await _notificationsPlugin.cancel(notificationId);
      }
      
      // Mark as inactive in Firestore (this will remove from calendar)
      await _firestore.collection('medication_reminders').doc(medicationId).update({
        'active': false,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      _log('✅ All notifications cancelled for medication: $medicationId (removed from calendar)');
    } catch (e) {
      _log('❌ Error cancelling notifications: $e');
    }
  }

  static Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      _log('📱 Showing immediate notification: $title');
      
      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Immediate notifications',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
      
      _log('✅ Immediate notification shown');
    } catch (e) {
      _log('❌ Error showing immediate notification: $e');
    }
  }

  // Test methods
  static Future<void> testNotification() async {
    _log('🧪 Testing immediate notification...');
    await showImmediateNotification(
      title: 'Test Notification',
      body: 'This is a test notification that works!',
      payload: 'test',
    );
  }

  static Future<void> testAlarmInOneMinute(String medicationName) async {
    final testTime = DateTime.now().add(Duration(minutes: 1));
    
    _log('🧪 Scheduling test notification for 1 minute from now...');
    
    try {
      await _notificationsPlugin.zonedSchedule(
        999999,
        'TEST: Medication Reminder',
        'This is a test for $medicationName - scheduled for ${testTime.toString().substring(11, 16)}',
        tz.TZDateTime.from(testTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Test notification',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            styleInformation: BigTextStyleInformation(
              'This is a test notification to verify the system is working properly.',
            ),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'test:$medicationName',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      _log('🧪 Test notification scheduled for ${testTime.hour}:${testTime.minute}');
    } catch (e) {
      _log('❌ Test notification failed: $e');
    }
  }

  static Future<void> testAlarmIn30Seconds(String medicationName) async {
    final testTime = DateTime.now().add(Duration(seconds: 30));
    
    _log('🧪 Scheduling test notification for 30 seconds from now...');
    
    try {
      await _notificationsPlugin.zonedSchedule(
        999997,
        'TEST: 30-Second Reminder',
        'This is a 30-second test for $medicationName',
        tz.TZDateTime.from(testTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: '30-second test',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'test30:$medicationName',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      _log('🧪 30-second test notification scheduled');
    } catch (e) {
      _log('❌ 30-second test notification failed: $e');
    }
  }

  // 🔧 ENHANCED: Task assignment notification with calendar integration
  static Future<bool> sendTaskNotification({
    required String userId,
    required String title,
    required String message,
    required DateTime dueDate,
    String? doctorName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      _log('📋 Sending task notification to $userId: $title with calendar integration');
      
      // Always create in-app notification
      final inAppSuccess = await sendNotification(
        userId: userId,
        title: 'New Task Assigned',
        message: message,
        type: 'task',
        data: {
          'taskTitle': title,
          'dueDate': dueDate.toIso8601String(),
          'doctorName': doctorName,
          'timestamp': DateTime.now().toIso8601String(),
          'calendarIntegration': true,
          ...?additionalData,
        },
      );
      
      // Send FCM push notification
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken != null) {
        await sendFcmPushNotification(
          token: fcmToken,
          title: 'New Task Assigned',
          body: message,
          data: {
            'taskTitle': title,
            'dueDate': dueDate.toIso8601String(),
            'doctorName': doctorName ?? '',
            'type': 'task',
          },
        );
      }
      
      _log('✅ Task notification sent with calendar integration');
      return inAppSuccess;
      
    } catch (e) {
      _log('❌ Error sending task notification: $e');
      return false;
    }
  }

  // 🔧 ENHANCED: Event notification with calendar integration
  static Future<bool> sendEventNotification({
    required String userId,
    required String title,
    required String message,
    required DateTime eventDate,
    String? doctorName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      _log('📅 Sending event notification to $userId: $title with calendar integration');
      
      // Always create in-app notification
      final inAppSuccess = await sendNotification(
        userId: userId,
        title: 'New Event: $title',
        message: message,
        type: 'event',
        data: {
          'eventTitle': title,
          'eventDate': eventDate.toIso8601String(),
          'doctorName': doctorName,
          'timestamp': DateTime.now().toIso8601String(),
          'calendarIntegration': true,
          ...?additionalData,
        },
      );
      
      // Send FCM push notification
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken != null) {
        await sendFcmPushNotification(
          token: fcmToken,
          title: 'New Event: $title',
          body: message,
          data: {
            'eventTitle': title,
            'eventDate': eventDate.toIso8601String(),
            'doctorName': doctorName ?? '',
            'type': 'event',
          },
        );
      }
      
      _log('✅ Event notification sent with calendar integration');
      return inAppSuccess;
      
    } catch (e) {
      _log('❌ Error sending event notification: $e');
      return false;
    }
  }

  // Check missed reminders - ONLY create in-app notifications, not device notifications
  static Future<void> checkMissedRemindersOnSignIn() async {
    if (!isUserSignedIn) return;

    try {
      final now = DateTime.now();
      _log('🔍 Checking for missed reminders since app opened...');
      
      final reminders = await _firestore
          .collection('medication_reminders')
          .where('active', isEqualTo: true)
          .where('userId', isEqualTo: currentUserId)
          .get();
      
      _log('📋 Found ${reminders.docs.length} active reminders for signed-in user');
      
      for (final doc in reminders.docs) {
        final data = doc.data();
        final medicationName = data['medication'] ?? 'Your medication';
        final reminderHour = data['hour'] ?? 0;
        final reminderMinute = data['minute'] ?? 0;
        final daysOfWeek = List<bool>.from(data['daysOfWeek'] ?? []);
        
        int dayIndex = now.weekday == 7 ? 6 : now.weekday - 1;
        
        if (dayIndex < daysOfWeek.length && daysOfWeek[dayIndex]) {
          final todayReminder = DateTime(
            now.year,
            now.month, 
            now.day,
            reminderHour,
            reminderMinute,
          );
          
          if (now.isAfter(todayReminder)) {
            final timeDifference = now.difference(todayReminder);
            
            _log('🚨 MISSED: $medicationName was ${timeDifference.inMinutes} minutes ago');
            
            if (timeDifference.inHours < 12) {
              final todayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
              
              // Check if we already created a notification for this missed reminder today
              final existingNotifications = await _firestore
                  .collection('notifications')
                  .where('userId', isEqualTo: currentUserId)
                  .where('type', isEqualTo: 'missed_reminder')
                  .where('data.medicationName', isEqualTo: medicationName)
                  .where('data.dateString', isEqualTo: todayString)
                  .get();
              
              if (existingNotifications.docs.isEmpty) {
                _log('📝 Creating in-app notification for missed $medicationName');
                
                // Only create in-app notification, no device notification
                await sendNotification(
                  userId: currentUserId!,
                  title: 'Missed Medication Reminder',
                  message: 'You missed your $medicationName at ${reminderHour}:${reminderMinute.toString().padLeft(2, '0')}',
                  type: 'missed_reminder',
                  data: {
                    'medicationName': medicationName,
                    'reminderType': 'missed_medication',
                    'originalTime': '${reminderHour}:${reminderMinute}',
                    'timeDifference': '${timeDifference.inMinutes} minutes ago',
                    'dateString': todayString,
                    'actualMissedTime': todayReminder.toIso8601String(),
                    'calendarIntegration': true,
                  },
                );
                
                _log('✅ In-app notification created for missed $medicationName');
              }
            }
          }
        }
      }
    } catch (e) {
      _log('❌ Error checking missed reminders: $e');
    }
  }

  // Check and create notifications for reminders that fired while user was signed out
  static Future<void> checkAndCreateNotificationsForFiredReminders(String userId) async {
    if (!isUserSignedIn || currentUserId != userId) return;

    try {
      _log('🔍 Checking for reminders that fired while signed out...');
      
      final now = DateTime.now();
      final oneDayAgo = now.subtract(Duration(days: 1));
      
      final reminders = await _firestore
          .collection('medication_reminders')
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();
      
      _log('📋 Found ${reminders.docs.length} active reminders for user');
      
      for (final doc in reminders.docs) {
        final data = doc.data();
        final medicationName = data['medication'] ?? 'Your medication';
        final reminderHour = data['hour'] ?? 0;
        final reminderMinute = data['minute'] ?? 0;
        final daysOfWeek = List<bool>.from(data['daysOfWeek'] ?? []);
        
        // Check last 24 hours for any reminders that should have fired
        for (int hoursBack = 0; hoursBack < 24; hoursBack++) {
          final checkTime = now.subtract(Duration(hours: hoursBack));
          final checkDayIndex = checkTime.weekday == 7 ? 6 : checkTime.weekday - 1;
          
          if (checkDayIndex < daysOfWeek.length && daysOfWeek[checkDayIndex]) {
            final reminderTime = DateTime(
              checkTime.year,
              checkTime.month,
              checkTime.day,
              reminderHour,
              reminderMinute,
            );
            
            if (reminderTime.isBefore(now) && reminderTime.isAfter(oneDayAgo)) {
              final dateString = "${reminderTime.year}-${reminderTime.month.toString().padLeft(2, '0')}-${reminderTime.day.toString().padLeft(2, '0')}";
              
              // Check if we already have a notification for this specific reminder time
              final existingNotifications = await _firestore
                  .collection('notifications')
                  .where('userId', isEqualTo: userId)
                  .where('data.medicationName', isEqualTo: medicationName)
                  .where('data.dateString', isEqualTo: dateString)
                  .where('data.originalTime', isEqualTo: '${reminderHour}:${reminderMinute}')
                  .get();
              
              if (existingNotifications.docs.isEmpty) {
                _log('📝 Creating in-app notification for $medicationName reminder from ${reminderTime.toString()}');
                
                // Only create in-app notification
                await sendNotification(
                  userId: userId,
                  title: 'Medication Reminder',
                  message: 'Time to take your $medicationName (scheduled for ${reminderHour}:${reminderMinute.toString().padLeft(2, '0')})',
                  type: 'medication_reminder',
                  data: {
                    'medicationName': medicationName,
                    'reminderType': 'medication',
                    'originalTime': '${reminderHour}:${reminderMinute}',
                    'scheduledTime': reminderTime.toIso8601String(),
                    'dateString': dateString,
                    'wasAutoCreated': true,
                    'calendarIntegration': true,
                  },
                );
                
                _log('✅ Created in-app notification for $medicationName');
              }
            }
          }
        }
      }
      
    } catch (e) {
      _log('❌ Error checking fired reminders: $e');
    }
  }

  // Check for missed messages
  static Future<void> checkMissedMessagesOnSignIn() async {
    if (!isUserSignedIn) return;

    try {
      _log('📨 Checking for messages received while signed out...');
      
      final now = DateTime.now();
      final oneDayAgo = now.subtract(Duration(days: 1));
      
      // Check for unread messages from the last 24 hours
      final recentMessages = await _firestore
          .collection('messages')
          .where('recipientId', isEqualTo: currentUserId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .where('read', isEqualTo: false)
          .get();
      
      _log('📨 Found ${recentMessages.docs.length} unread messages');
      
      for (final messageDoc in recentMessages.docs) {
        final messageData = messageDoc.data();
        
        // Check if we already have a notification for this message
        final existingNotifications = await _firestore
            .collection('notifications')
            .where('type', isEqualTo: 'message')
            .where('data.messageId', isEqualTo: messageDoc.id)
            .get();
        
        if (existingNotifications.docs.isEmpty) {
          // Create notification for missed message
          await sendNotification(
            userId: messageData['recipientId'],
            title: 'New Message from ${messageData['senderName']}',
            message: messageData['content'],
            type: 'message',
            data: {
              'messageId': messageDoc.id,
              'senderId': messageData['senderId'],
              'senderName': messageData['senderName'],
              'wasAutoCreated': true,
            },
          );

          final userDoc = await _firestore.collection('users').doc(messageData['recipientId']).get();
          final fcmToken = userDoc.data()?['fcmToken'];
          if (fcmToken != null) {
            await sendFcmPushNotification(
              token: fcmToken,
              title: 'New Message from ${messageData['senderName']}',
              body: messageData['content'],
              data: {
                'senderId': messageData['senderId'],
                'senderName': messageData['senderName'],
                'messageContent': messageData['content'],
              },
            );
          }
        }
      }
      
      _log('✅ Missed message check completed');
      
    } catch (e) {
      _log('❌ Error checking missed messages: $e');
    }
  }

  // 🔧 ENHANCED: Message notifications with FCM
  static Future<bool> sendMessageNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String messageContent,
  }) async {
    try {
      _log('📨 Sending message notification to $recipientId from $senderName');
      
      final truncatedMessage = messageContent.length > 60 
          ? '${messageContent.substring(0, 60)}...'
          : messageContent;
      
      // Always create in-app notification
      final inAppSuccess = await sendNotification(
        userId: recipientId,
        title: 'New Message from $senderName',
        message: truncatedMessage,
        type: 'message',
        data: {
          'senderId': senderId,
          'senderName': senderName,
          'messageContent': messageContent,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Send FCM push notification
      final userDoc = await _firestore.collection('users').doc(recipientId).get();
      final fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken != null) {
        await sendFcmPushNotification(
          token: fcmToken,
          title: 'New Message from $senderName',
          body: messageContent,
          data: {
            'senderId': senderId,
            'senderName': senderName,
            'messageContent': messageContent,
          },
        );
      }

      _log('✅ Both in-app and push notifications sent to user: $recipientId');
      return inAppSuccess;
      
    } catch (e) {
      _log('❌ Error sending message notification: $e');
      return false;
    }
  }

  // FCM Push notification
  static Future<void> sendFcmPushNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final url = Uri.parse('https://fcm-node-backend.onrender.com/send-fcm');
    print('Sending FCM push to $url');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'title': title,
        'body': body,
      }),
    );

    if (response.statusCode != 200) {
      print('Failed to send FCM: ${response.body}');
    } else {
      print('FCM push response: ${response.statusCode} ${response.body}');
    }
  }

  // Base notification method (creates in-app notifications only)
  static Future<bool> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _log('❌ Error sending Firestore notification: $e');
      return false;
    }
  }

  static Future<bool> sendReminderNotification({
    required String userId,
    required String title,
    required String message,
    String? medicationName,
  }) async {
    final success = await sendNotification(
      userId: userId,
      title: title,
      message: message,
      type: 'reminder',
      data: {
        'medicationName': medicationName,
        'reminderType': 'medication',
        'timestamp': DateTime.now().toIso8601String(),
        'calendarIntegration': true,
      },
    );
    
    return success;
  }

  // 🔧 ENHANCED: System notifications
  static Future<bool> sendSystemNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    _log('🔔 Sending system notification: $title to $userId');
    
    // Always create in-app notification
    final inAppSuccess = await sendNotification(
      userId: userId,
      title: title,
      message: message,
      type: 'system',
      data: {
        ...?data,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    // Send FCM push notification
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final fcmToken = userDoc.data()?['fcmToken'];
    if (fcmToken != null) {
      await sendFcmPushNotification(
        token: fcmToken,
        title: title,
        body: message,
        data: data,
      );
    }
    
    return inAppSuccess;
  }

  // 🔧 ENHANCED: Assignment notifications
  static Future<bool> sendAssignmentNotification({
    required String userId,
    required String assignmentType,
    required String assignedToName,
    String? assignedById,
    String? assignedByName,
  }) async {
    String title;
    String message;
    
    switch (assignmentType) {
      case 'mentor':
        title = 'Mentor Assigned';
        message = 'Mentor  $assignedToName has been assigned as your mentor';
        break;
      case 'doctor':
        title = 'Doctor Assigned';
        message = 'Dr. $assignedToName has been assigned as your doctor';
        break;
      case 'mentee':
        title = 'New Mentee';
        message = '$assignedToName has been assigned as your mentee';
        break;
      case 'patient':
        title = 'New Patient';
        message = '$assignedToName has been assigned as your patient';
        break;
      default:
        title = 'New Assignment';
        message = 'You have been assigned to $assignedToName';
    }
    
    _log('👥 Sending assignment notification: $title to $userId');
    
    return await sendSystemNotification(
      userId: userId,
      title: title,
      message: message,
      data: {
        'assignmentType': assignmentType,
        'assignedToName': assignedToName,
        'assignedById': assignedById,
        'assignedByName': assignedByName,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // 🔧 ENHANCED: Bulk notifications
  static Future<bool> sendBulkNotifications({
    required List<String> userIds,
    required String title,
    required String message,
    String type = 'system',
    Map<String, dynamic>? data,
    bool sendPushNotifications = true,
  }) async {
    try {
      _log('📢 Sending bulk notifications to ${userIds.length} users: $title');
      
      final batch = _firestore.batch();
      
      // Create in-app notifications for all users
      for (String userId in userIds) {
        final docRef = _firestore.collection('notifications').doc();
        batch.set(docRef, {
          'userId': userId,
          'title': title,
          'message': message,
          'type': type,
          'data': {
            ...?data,
            'timestamp': DateTime.now().toIso8601String(),
            'isBulk': true,
          },
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      // Send push notifications
      if (sendPushNotifications) {
        for (String userId in userIds) {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          final fcmToken = userDoc.data()?['fcmToken'];
          if (fcmToken != null) {
            await sendFcmPushNotification(
              token: fcmToken,
              title: title,
              body: message,
              data: data,
            );
          }
          
          // Small delay to prevent overwhelming the system
          if (userIds.length > 10) {
            await Future.delayed(Duration(milliseconds: 100));
          }
        }
      }
      
      _log('✅ Bulk notifications sent successfully');
      return true;
    } catch (e) {
      _log('❌ Error sending bulk notifications: $e');
      return false;
    }
  }

  // Role-based notifications
  static Future<bool> sendRoleBasedNotification({
    required String role,
    required String title,
    required String message,
    String type = 'system',
    Map<String, dynamic>? data,
    bool sendPushNotifications = true,
  }) async {
    try {
      _log('👥 Sending role-based notification to $role users: $title');
      
      final usersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      
      if (usersQuery.docs.isEmpty) {
        _log('⚠️ No users found with role: $role');
        return true;
      }
      
      final userIds = usersQuery.docs.map((doc) => doc.id).toList();
      _log('📋 Found ${userIds.length} users with role: $role');
      
      return await sendBulkNotifications(
        userIds: userIds,
        title: title,
        message: message,
        type: type,
        data: {
          ...?data,
          'targetRole': role,
        },
        sendPushNotifications: sendPushNotifications,
      );
    } catch (e) {
      _log('❌ Error sending role-based notification: $e');
      return false;
    }
  }

  // Send appointment notifications
  static Future<bool> sendAppointmentNotification({
    required String userId,
    required String title,
    required String message,
    required DateTime appointmentTime,
    required String doctorName,
    String? appointmentId,
  }) async {
    _log('📅 Sending appointment notification: $title to $userId');
    
    return await sendSystemNotification(
      userId: userId,
      title: title,
      message: message,
      data: {
        'appointmentTime': appointmentTime.toIso8601String(),
        'doctorName': doctorName,
        'appointmentId': appointmentId,
        'timestamp': DateTime.now().toIso8601String(),
        'calendarIntegration': true,
      },
    );
  }

  // Debug and utility methods
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      _log('📱 Found ${pending.length} pending notifications');
      for (final notification in pending) {
        _log('   ID: ${notification.id}, Title: ${notification.title}');
      }
      return pending;
    } catch (e) {
      _log('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  static Future<void> forceCheckReminders() async {
    _log('🔍 Force check disabled - relying on scheduled notifications');
  }

  static Future<void> debugMedicationSetup() async {
    _log('🔧 DEBUG: Medication setup status with calendar integration');
    _log('🔑 User signed in: $isUserSignedIn');
    _log('🔑 Current user ID: $currentUserId');
    
    if (!isUserSignedIn) {
      _log('🔒 Cannot debug - user not signed in');
      return;
    }
    
    try {
      final reminders = await _firestore
          .collection('medication_reminders')
          .where('active', isEqualTo: true)
          .where('userId', isEqualTo: currentUserId)
          .get();
      
      _log('📋 Database reminders: ${reminders.docs.length}');
      
      for (final doc in reminders.docs) {
        final data = doc.data();
        _log('   ${data['medication']}: ${data['hour']}:${data['minute']} on ${data['daysOfWeek']} (Calendar: ${data['calendarIntegration'] ?? false})');
      }
      
      final pending = await getPendingNotifications();
      
      if (Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          final bool? areEnabled = await androidImplementation.areNotificationsEnabled();
          _log('🔔 System notifications enabled: $areEnabled');
        }
      }
      
    } catch (e) {
      _log('❌ Debug setup error: $e');
    }
  }

  // Utility methods
  static Future<Map<String, dynamic>> getNotificationStats(String userId) async {
    try {
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();
      
      final notifications = notificationsQuery.docs;
      final unreadCount = notifications.where((doc) => 
          (doc.data()['read'] ?? true) == false).length;
      
      return {
        'total': notifications.length,
        'unread': unreadCount,
        'read': notifications.length - unreadCount,
      };
    } catch (e) {
      _log('❌ Error getting notification stats: $e');
      return {'total': 0, 'unread': 0, 'read': 0};
    }
  }

  static Future<bool> cleanupOldNotifications() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      
      final oldNotificationsQuery = await _firestore
          .collection('notifications')
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      if (oldNotificationsQuery.docs.isEmpty) return true;
      
      final batch = _firestore.batch();
      for (final doc in oldNotificationsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      _log('❌ Error cleaning up old notifications: $e');
      return false;
    }
  }

  static Future<bool> scheduleNotification({
    required String userId,
    required String title,
    required String message,
    required DateTime scheduledTime,
    String type = 'reminder',
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('scheduled_notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'scheduledFor': Timestamp.fromDate(scheduledTime),
        'sent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      _log('❌ Error scheduling notification: $e');
      return false;
    }
  }

  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      _log('❌ Error marking notification as read: $e');
      return false;
    }
  }

  static Future<bool> markAllAsReadForUser(String userId) async {
    try {
      final unreadQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      if (unreadQuery.docs.isEmpty) return true;
      
      final batch = _firestore.batch();
      for (final doc in unreadQuery.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      _log('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  // Cleanup method when user signs out
  static Future<void> dispose() async {
    _log('🧹 Disposing notification service...');
    
    _timer?.cancel();
    _timer = null;
    
    _authSubscription?.cancel();
    _authSubscription = null;
    
    _currentUser = null;
    _isInitialized = false;
    
    _log('✅ Notification service disposed');
  }
}