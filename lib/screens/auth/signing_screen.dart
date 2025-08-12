import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/app_state.dart';
import '../../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  String? _successMessage;
  bool _isResettingPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email address first";
        _successMessage = null;
      });
      return;
    }

    if (!email.contains('@')) {
      setState(() {
        _errorMessage = "Please enter a valid email address";
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isResettingPassword = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      setState(() {
        _isResettingPassword = false;
        _successMessage = "Password reset email sent! Check your inbox.";
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isResettingPassword = false;
        _successMessage = null;
        
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'user-not-found':
              _errorMessage = "No account found with this email address";
              break;
            case 'invalid-email':
              _errorMessage = "Invalid email address";
              break;
            case 'too-many-requests':
              _errorMessage = "Too many requests. Please wait and try again.";
              break;
            default:
              _errorMessage = "Failed to send reset email. Please try again.";
          }
        } else {
          _errorMessage = "Failed to send reset email. Please try again.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sign In'),
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
            SizedBox(height: 8),
            
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
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 24),
            if (appState.isLoading)
              CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _errorMessage = null;
                    _successMessage = null;
                  });
                  
                  try {
                    await appState.signInWithEmailAndPassword(
                      _emailController.text,
                      _passwordController.text,
                    );
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
            // Forgot Password Button
            TextButton(
              onPressed: _isResettingPassword ? null : _resetPassword,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: _isResettingPassword 
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Sending...', style: TextStyle(color: Colors.blue)),
                    ],
                  )
                : Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Account'),
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
                  if (_emailController.text.isEmpty ||
                      _passwordController.text.isEmpty) {
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
                      _successMessage =
                          "Account created! You will be notified once approved.";
                    });

                    // Send notification to all admins about the new signup
                    final adminQuery = await FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'admin')
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
                    }

                    // Navigate to pending approval screen after a delay
                    Future.delayed(Duration(seconds: 2), () {
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  PendingApprovalScreen()),
                        );
                      }
                    });
                  } catch (e) {
                    setState(() {
                      if (e.toString().contains('email-already-in-use')) {
                        _errorMessage = "This email is already registered";
                      } else if (e
                          .toString()
                          .contains('weak-password')) {
                        _errorMessage =
                            "Password is too weak (at least 6 characters)";
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
          ],
        ),
      ),
    );
  }
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

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
              SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await appState.refreshUserData();
                },
                child: Text('Check Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}