import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'Providers/app_state.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/doctor/doctor_home_screen.dart';
import 'screens/mentor/mentor_home_screen.dart';
import 'screens/mentee/mentee_home_screen.dart';
import 'services/notification_service.dart'; // NEW
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // NEW: Initialize notification service
  await NotificationService.init();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging messaging = FirebaseMessaging.instance;
NotificationSettings settings = await messaging.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);
print('User granted permission: ${settings.authorizationStatus}');
// adding listeners for foreground and background messages
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Received a message in the foreground!');
  // Optionally show a local notification here
});

FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  print('User tapped on a notification!');
});

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: SmileAIApp(),
    ),
  );
}

class SmileAIApp extends StatelessWidget {
  const SmileAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmileAI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthWrapper(),
    );
  }
}

// 🔧 IMPROVED AuthWrapper to handle role changes
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  String? lastRole;
  bool isTransitioning = false;
  bool showRoleChangeDialog = false;
  String? roleChangeMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Set up role change callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).setRoleChangeCallback(_handleRoleChange);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleRoleChange(String oldRole, String newRole) {
    print('🔄 Handling role change in AuthWrapper: $oldRole → $newRole');
    
    if (!mounted) return;
    
    setState(() {
      isTransitioning = true;
      roleChangeMessage = _getRoleChangeMessage(oldRole, newRole);
    });

    // Show role change notification
    if (newRole == 'mentor' && oldRole == 'mentee') {
      _showPromotionDialog();
    } else {
      _showRoleChangeNotification(oldRole, newRole);
    }

    // Handle the transition
    _performRoleTransition(oldRole, newRole);
  }

  String _getRoleChangeMessage(String oldRole, String newRole) {
    if (newRole == 'mentor' && oldRole == 'mentee') {
      return "🎉 Congratulations! You've been promoted to Mentor!";
    } else {
      return "Your role has been updated to ${newRole.toUpperCase()}";
    }
  }

  void _showPromotionDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Congratulations!',
                style: TextStyle(color: Colors.orange[700]),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'You have been promoted to Mentor!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'You can now guide and help other mentees on their journey to better dental health.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeTransition();
            },
            child: Text('Continue to Mentor Dashboard'),
          ),
        ],
      ),
    );
  }

  void _showRoleChangeNotification(String oldRole, String newRole) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your role has been updated to ${newRole.toUpperCase()}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
    
    // Auto-complete transition after a delay
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        _completeTransition();
      }
    });
  }

  void _performRoleTransition(String oldRole, String newRole) {
    // Force reload of role-specific data
    final appState = Provider.of<AppState>(context, listen: false);
    
    // Reload all user data to ensure proper role-specific data is loaded
    appState.loadAllUsersNow();
  }

  void _completeTransition() {
    if (!mounted) return;
    
    setState(() {
      isTransitioning = false;
      showRoleChangeDialog = false;
      roleChangeMessage = null;
    });
  }

  // Alternative: Restart app option (if smooth transition doesn't work)
  void _showRestartOption(String newRole) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Role Updated'),
        content: Text(
          'Your role has been changed to $newRole. Would you like to restart the app for the best experience?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeTransition();
            },
            child: Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              // Force app restart by clearing everything and reloading
              _restartApp();
            },
            child: Text('Restart App'),
          ),
        ],
      ),
    );
  }

  void _restartApp() {
    // Sign out and sign back in to force complete reload
    final appState = Provider.of<AppState>(context, listen: false);
    appState.signOut().then((_) {
      // The auth state change will handle the rest
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        print("🔍 AuthWrapper State:");
        print("  User: ${appState.user?.uid}");
        print("  UserData: ${appState.userData?.name}");
        print("  Role: ${appState.userData?.role}");
        print("  Approved: ${appState.userData?.approved}");
        print("  Disapproved: ${appState.userData?.wasDisapproved}");
        print("  Loading: ${appState.isLoading}");
        print("  Last Role: $lastRole");
        print("  Transitioning: $isTransitioning");
        
        // Check for role change
        if (appState.userData != null && lastRole != null && lastRole != appState.userData!.role && !isTransitioning) {
          print("🔄 Role change detected in build: $lastRole -> ${appState.userData!.role}");
          // This will be handled by the listener callback, so we don't need to do anything here
        }
        
        // Update last known role
        if (appState.userData != null) {
          lastRole = appState.userData!.role;
        }
        
        // Show loading screen if loading or transitioning
        if (appState.isLoading || isTransitioning) {
          return LoadingScreen(
            message: isTransitioning 
                ? (roleChangeMessage ?? "Updating your account...") 
                : "Loading...",
          );
        }
        
        if (appState.user == null) {
          return WelcomeScreen();
        }
        
        if (appState.userData == null) {
          return LoadingScreen(message: "Setting up your account...");
        }
        
        // 🔧 NEW: Check if user was disapproved
        if (!appState.userData!.approved) {
          if (appState.userData!.wasDisapproved) {
            return AdminDisapprovedScreen(); // Show disapproved screen
          } else {
            return PendingApprovalScreen(); // Show pending screen
          }
        }
        
        // Route to correct screen based on role
        try {
          print("🔄 Routing user to ${appState.userData!.role} screen");
          
          Widget targetScreen;
          if (appState.isAdmin) {
            targetScreen = AdminHomeScreen();
          } else if (appState.isDoctor) {
            targetScreen = DoctorHomeScreen();
          } else if (appState.isMentor) {
            print("👨‍🏫 Loading mentor home screen");
            targetScreen = MentorHomeScreen();
          } else {
            targetScreen = MenteeHomeScreen();
          }
          
          // Wrap in a container to prevent widget disposal issues
          return Container(
            key: ValueKey('${appState.userData!.role}_${appState.userData!.uid}'), // Force rebuild on role change
            child: targetScreen,
          );
          
        } catch (e) {
          print("❌ Error routing user: $e");
          return ErrorScreen(error: "Navigation Error: $e");
        }
      },
    );
  }
}

// 🔧 IMPROVED LoadingScreen with custom messages
class LoadingScreen extends StatelessWidget {
  final String message;
  
  const LoadingScreen({super.key, this.message = "Loading..."});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (message.contains("Updating"))
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Please wait while we set up your new role",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 🔧 NEW: Error screen for debugging
class ErrorScreen extends StatelessWidget {
  final String error;
  
  const ErrorScreen({super.key, required this.error});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  final appState = Provider.of<AppState>(context, listen: false);
                  await appState.signOut();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔧 NEW: Professional Admin Disapproved Screen
class AdminDisapprovedScreen extends StatelessWidget {
  const AdminDisapprovedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Add some top spacing to center content when not scrolled
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block,
                  size: 60,
                  color: Colors.red[400],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Title
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 16),
              
              // Subtitle
              Text(
                'Account Disapproved',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 24),
              
              // Description
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey[600],
                      size: 24,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Your account has been reviewed and unfortunately was not approved for access to this platform.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Contact support section
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.support_agent,
                      color: Colors.blue[600],
                      size: 24,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Need Help?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'if you are having trouble deleting your account, please contact our support team at smileai.anwi25@gmail.com .',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 40),
              
              // Sign out button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Contact support button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    // Add your support contact logic here
                    _showContactSupport(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                    side: BorderSide(color: Colors.blue[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              // Add bottom spacing for better scrolling experience
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showContactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.support_agent, color: Colors.blue[600]),
            SizedBox(width: 8),
            Text('Contact Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get in touch with our support team:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.email, color: Colors.grey[600], size: 20),
                SizedBox(width: 8),
                Text('smileai.anwi25@gmail.com'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, color: Colors.grey[600], size: 20),
                SizedBox(width: 8),
                Text('+1 (555) 123-4567'),
              ],
            ),
          ],
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
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to SmileAI!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 40),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Create an account',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      'Enter your email to sign up for this app',
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUpScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: Text('Sign Up'),
                    ),
                    SizedBox(height: 10),
                    Text('or'),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignInScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: Text('Sign In'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'By clicking continue, you agree to our Terms of Service and Privacy Policy',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign In'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome Back to SmileAI!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(height: 8),
                // NEW: Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text('Forgot Password?'),
                  ),
                ),
                SizedBox(height: 16),
                if (appState.isLoading)
                  CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await appState.signInWithEmailAndPassword(
                          _emailController.text,
                          _passwordController.text,
                        );
                        // Wait a moment for auth state to update, then navigate
                        if (mounted) {
                          await Future.delayed(Duration(milliseconds: 500));
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        setState(() {
                          _errorMessage = "Invalid email or password";
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('Sign In'),
                  ),
                SizedBox(height: 20),
                Text(
                  'By clicking continue, you agree to our Terms of Service and Privacy Policy',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// NEW: Forgot Password Screen
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email address";
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      
      setState(() {
        _successMessage = "Password reset email sent! Check your inbox.";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e.toString().contains('user-not-found')) {
          _errorMessage = "No account found with this email address";
        } else if (e.toString().contains('invalid-email')) {
          _errorMessage = "Please enter a valid email address";
        } else {
          _errorMessage = "Failed to send reset email. Please try again.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Password'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_reset,
              size: 80,
              color: Colors.blue[600],
            ),
            SizedBox(height: 32),
            Text(
              'Reset Your Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[600], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 32),
            if (_isLoading)
              CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _sendPasswordResetEmail,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Send Reset Email'),
              ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Back to Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'mentee';
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Account'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Join SmileAI!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    helperText: 'At least 6 characters',
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedRole,
                  items: [
                    DropdownMenuItem(value: 'mentee', child: Text('Mentee')),
                    DropdownMenuItem(value: 'mentor', child: Text('Mentor')),
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                if (_successMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _successMessage!,
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                SizedBox(height: 24),
                if (appState.isLoading)
                  CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: () async {
                      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
                        setState(() {
                          _errorMessage = "Please fill in all fields";
                          _successMessage = null;
                        });
                        return;
                      }
                      
                      setState(() {
                        _errorMessage = null;
                        _successMessage = null;
                      });
                      
                      try {
                        await appState.signUpWithEmailAndPassword(
                          _emailController.text,
                          _passwordController.text,
                          _selectedRole,
                        );
                        
                        setState(() {
                          _successMessage = "Account created! You will be notified once approved.";
                          
                        });
                         final adminQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .where('approved', isEqualTo: true)
        .get();

    for (final adminDoc in adminQuery.docs) {
  await NotificationService.sendNotification(
    userId: adminDoc.id,
    title: 'New User Signup',
    message: '${_emailController.text} signed up as $_selectedRole.',
    type: 'signup',
    data: {
      'userEmail': _emailController.text,
      'userRole': _selectedRole,
    },
  );
  // --- ADD THIS ---
  final fcmToken = adminDoc.data()?['fcmToken'];
  if (fcmToken != null) {
    await NotificationService.sendFcmPushNotification(
      token: fcmToken,
      title: 'New User Signup',
      body: '${_emailController.text} signed up as $_selectedRole.',
      data: {
        'userEmail': _emailController.text,
        'userRole': _selectedRole,
      },
    );
  }
}
                        // Wait a moment for auth state to update, then navigate
                        if (mounted) {
                          await Future.delayed(Duration(milliseconds: 500));
                          Navigator.of(context).pop();
                        }
                        
                      } catch (e) {
                        setState(() {
                          if (e.toString().contains('email-already-in-use')) {
                            _errorMessage = "This email is already registered";
                          } else if (e.toString().contains('weak-password')) {
                            _errorMessage = "Password is too weak (at least 6 characters)";
                          } else if (e.toString().contains('invalid-email')) {
                            _errorMessage = "Invalid email address";
                          } else {
                            _errorMessage = "Account creation failed: ${e.toString()}";
                          }
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('Create Account'),
                  ),
                SizedBox(height: 20),
                Text(
                  'By clicking continue, you agree to our Terms of Service and Privacy Policy',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  _PendingApprovalScreenState createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  StreamSubscription? _userSubscription;

  @override
  void initState() {
    super.initState();
    _listenToApprovalStatus();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _listenToApprovalStatus() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.user == null) return;

    print('🔔 Setting up approval status listener for user: ${appState.user!.uid}');

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(appState.user!.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final isApproved = data['approved'] ?? false;
        final wasDisapproved = data['wasDisapproved'] ?? false;
        final disapprovedAt = data['disapprovedAt'];
        
        print('📊 Approval status - Approved: $isApproved, Disapproved: $wasDisapproved');
        
        if (mounted) {
          if (isApproved) {
            print('✅ User approved! Refreshing user data...');
            // Refresh the user data in AppState which will trigger navigation
            appState.refreshUserData();
          } else if (wasDisapproved || disapprovedAt != null) {
            print('❌ User disapproved! Refreshing user data...');
            // Refresh the user data in AppState which will trigger navigation to disapproved screen
            appState.refreshUserData();
          }
        }
        
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.hourglass_bottom,
                    size: 80,
                    color: Colors.amber,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Account Pending Approval',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your account is currently pending approval by an administrator. You will be notified when your account is approved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      await appState.signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}