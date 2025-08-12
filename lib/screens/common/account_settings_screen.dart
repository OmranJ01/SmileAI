import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../models/user_data.dart';
import '../../Providers/app_state.dart';
import '../../services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _locationController = TextEditingController();
  
  bool _isLoading = false;
  bool _isUpdatingProfile = false;
  bool _showEmail = true;
  bool _showPhone = true;
  bool _allowMessages = true;
  bool _allowCalls = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  
  File? _imageFile;
  Uint8List? _webImage;
  String? _currentImageUrl;
  
  UserData? _userData;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _specialtyController.dispose();
    _locationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.userData != null) {
        _userData = appState.userData!;
        
        _nameController.text = _userData!.name;
        _emailController.text = _userData!.email;
        _phoneController.text = _userData!.phone ?? '';
        _bioController.text = _userData!.bio ?? '';
        _specialtyController.text = _userData!.specialty ?? '';
        _locationController.text = _userData!.location ?? '';
        _currentImageUrl = _userData!.photoUrl;
        
        // Load privacy settings (you might want to store these in Firestore)
        _showEmail = _userData!.showEmail ?? true;
        _showPhone = _userData!.showPhone ?? true;
        _allowMessages = _userData!.allowMessages ?? true;
        _allowCalls = _userData!.allowCalls ?? true;
        _emailNotifications = _userData!.emailNotifications ?? true;
        _pushNotifications = _userData!.pushNotifications ?? true;
      }
    } catch (e) {
      print('Error loading user data: $e');
      _showErrorSnackBar('Failed to load user data');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
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
              'Update Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  source: ImageSource.camera,
                ),
                _buildImageSourceButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  source: ImageSource.gallery,
                ),
                if (_currentImageUrl != null)
                  _buildImageSourceButton(
                    icon: Icons.delete,
                    label: 'Remove',
                    onTap: _removeImage,
                    color: Colors.red,
                  ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    ImageSource? source,
    VoidCallback? onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap ?? () {
        Navigator.pop(context);
        if (source != null) {
          _getImage(source);
        }
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: (color ?? Colors.blue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: color ?? Colors.blue,
              size: 30,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.black87,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _getImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        if (Platform.isAndroid || Platform.isIOS) {
          setState(() {
            _imageFile = File(image.path);
            _webImage = null;
          });
        } else {
          // Web platform
          final bytes = await image.readAsBytes();
          setState(() {
            _webImage = bytes;
            _imageFile = null;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorSnackBar('Failed to pick image');
    }
  }
  
  Future<void> _removeImage() async {
    Navigator.pop(context);
    
    setState(() {
      _imageFile = null;
      _webImage = null;
      _currentImageUrl = null;
    });
    
    // Also remove from Firebase Storage if exists
    if (_userData?.photoUrl != null) {
      try {
        await FirebaseStorage.instance.refFromURL(_userData!.photoUrl!).delete();
      } catch (e) {
        print('Error deleting old photo: $e');
      }
    }
  }
  
  Future<String?> _uploadImage() async {
    if (_imageFile == null && _webImage == null) return null;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');
      
      UploadTask uploadTask;
      
      if (_imageFile != null) {
        uploadTask = storageRef.putFile(_imageFile!);
      } else {
        uploadTask = storageRef.putData(_webImage!);
      }
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }
  
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isUpdatingProfile = true;
    });
    
    try {
      String? newImageUrl;
      
      // Upload new image if selected
      if (_imageFile != null || _webImage != null) {
        newImageUrl = await _uploadImage();
      } else if (_currentImageUrl == null) {
        // Image was removed
        newImageUrl = null;
      } else {
        // Keep existing image
        newImageUrl = _currentImageUrl;
      }
      
      // Update user data
      final updatedUserData = UserData(
        uid: _userData!.uid,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: _userData!.role,
        photoUrl: newImageUrl,
        approved: _userData!.approved,
        doctorId: _userData!.doctorId,
        mentorId: _userData!.mentorId,
        createdAt: _userData!.createdAt,
        lastActivity: DateTime.now(),
        assignedAt: _userData!.assignedAt,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
        specialty: _specialtyController.text.trim().isNotEmpty ? _specialtyController.text.trim() : null,
        location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        showEmail: _showEmail,
        showPhone: _showPhone,
        allowMessages: _allowMessages,
        allowCalls: _allowCalls,
        emailNotifications: _emailNotifications,
        pushNotifications: _pushNotifications,
      );
      
      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userData!.uid)
          .update(updatedUserData.toMap());
      
      // Update in app state
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setUserData(updatedUserData);
      
      setState(() {
        _userData = updatedUserData;
        _imageFile = null;
        _webImage = null;
        _currentImageUrl = newImageUrl;
      });
      
      _showSuccessSnackBar('Profile updated successfully');
      
    } catch (e) {
      print('Error updating profile: $e');
      _showErrorSnackBar('Failed to update profile');
    } finally {
      setState(() {
        _isUpdatingProfile = false;
      });
    }
  }
  
  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                _showErrorSnackBar('Passwords do not match');
                return;
              }
              
              if (newPasswordController.text.length < 6) {
                _showErrorSnackBar('Password must be at least 6 characters');
                return;
              }
              
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                
                // Re-authenticate user
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPasswordController.text,
                );
                
                await user.reauthenticateWithCredential(credential);
                
                // Update password
                await user.updatePassword(newPasswordController.text);
                
                Navigator.pop(context);
                _showSuccessSnackBar('Password changed successfully');
                
              } catch (e) {
                print('Error changing password: $e');
                _showErrorSnackBar('Failed to change password. Check your current password.');
              }
            },
            child: Text('Change Password'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _deleteAccount() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone and will permanently delete all your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final passwordController = TextEditingController();
              
              // Ask for password confirmation
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Confirm Account Deletion'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Enter your password to confirm account deletion:'),
                      SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Delete Account'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  
                  // Re-authenticate user
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passwordController.text,
                  );
                  
                  await user.reauthenticateWithCredential(credential);
                  
                  // Delete user data from Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .delete();
                  
                  // Delete profile photo from Storage
                  if (_userData?.photoUrl != null) {
                    try {
                      await FirebaseStorage.instance.refFromURL(_userData!.photoUrl!).delete();
                    } catch (e) {
                      print('Error deleting profile photo: $e');
                    }
                  }
                  
                  // Delete user account
                  await user.delete();
                  
                  // Navigate to login screen
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                  
                } catch (e) {
                  print('Error deleting account: $e');
                  _showErrorSnackBar('Failed to delete account. Please try again.');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete Account'),
          ),
        ],
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Profile Photo
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _getProfileImage(),
                      child: _getProfileImage() == null
                        ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                        : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Location (Optional)',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  if (_userData?.role == 'doctor') ...[
                    TextFormField(
                      controller: _specialtyController,
                      decoration: InputDecoration(
                        labelText: 'Medical Specialty',
                        prefixIcon: Icon(Icons.medical_services),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  TextFormField(
                    controller: _bioController,
                    decoration: InputDecoration(
                      labelText: 'Bio (Optional)',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    maxLength: 500,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  ImageProvider? _getProfileImage() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (_webImage != null) {
      return MemoryImage(_webImage!);
    } else if (_currentImageUrl != null) {
      return NetworkImage(_currentImageUrl!);
    }
    return null;
  }
  
  Widget _buildPrivacySection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            SwitchListTile(
              title: Text('Show Email to Others'),
              subtitle: Text('Allow other users to see your email address'),
              value: _showEmail,
              onChanged: (value) {
                setState(() {
                  _showEmail = value;
                });
              },
            ),
            
            SwitchListTile(
              title: Text('Show Phone to Others'),
              subtitle: Text('Allow other users to see your phone number'),
              value: _showPhone,
              onChanged: (value) {
                setState(() {
                  _showPhone = value;
                });
              },
            ),
            
            SwitchListTile(
              title: Text('Allow Messages'),
              subtitle: Text('Receive messages from other users'),
              value: _allowMessages,
              onChanged: (value) {
                setState(() {
                  _allowMessages = value;
                });
              },
            ),
            
            SwitchListTile(
              title: Text('Allow Calls'),
              subtitle: Text('Receive calls from other users'),
              value: _allowCalls,
              onChanged: (value) {
                setState(() {
                  _allowCalls = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNotificationSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            SwitchListTile(
              title: Text('Email Notifications'),
              subtitle: Text('Receive notifications via email'),
              value: _emailNotifications,
              onChanged: (value) {
                setState(() {
                  _emailNotifications = value;
                });
              },
            ),
            
            SwitchListTile(
              title: Text('Push Notifications'),
              subtitle: Text('Receive push notifications on your device'),
              value: _pushNotifications,
              onChanged: (value) {
                setState(() {
                  _pushNotifications = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            ListTile(
              leading: Icon(Icons.lock),
              title: Text('Change Password'),
              subtitle: Text('Update your account password'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: _changePassword,
            ),
            
            Divider(),
            
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Delete Account', style: TextStyle(color: Colors.red)),
              subtitle: Text('Permanently delete your account and all data'),
              trailing: Icon(Icons.arrow_forward_ios, color: Colors.red),
              onTap: _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Account Settings'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Account Settings'),
        actions: [
          if (_isUpdatingProfile)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _updateProfile,
              child: Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileSection(),
            SizedBox(height: 16),
            _buildPrivacySection(),
            SizedBox(height: 16),
            _buildNotificationSection(),
            SizedBox(height: 16),
            _buildSecuritySection(),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}