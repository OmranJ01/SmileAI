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
import '../../services/cloudinary_service.dart';
// ...existing code...

Widget _buildProfileField({
  required String label,
  required TextEditingController controller,
  IconData? icon,
  bool isEditMode = false,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  int? maxLines,
  int? maxLength,
}) {
  if (isEditMode) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(),
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      maxLength: maxLength,
    );
  } else {
    return ListTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(controller.text.isEmpty ? '-' : controller.text),
      contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      dense: true,
    );
  }
}

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
  bool _isEditMode = false;
  bool _isDeletingAccount = false;
  
  File? _imageFile;
  Uint8List? _webImage;
  String? _currentImageUrl;
  int _imageUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
  
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
    if (!_isEditMode) return; // Only allow image picking in edit mode
    
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
        print('New image selected from ${source.name}');
        
        // Clear any existing image cache before setting new image
        if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
          try {
            await NetworkImage(_currentImageUrl!).evict();
            if (_currentImageUrl!.contains('cloudinary.com')) {
              final optimizedUrl = CloudinaryService.getMediumUrl(_currentImageUrl!);
              await NetworkImage(optimizedUrl).evict();
            }
            print('Cleared existing image cache when selecting new image');
          } catch (e) {
            print('Error clearing image cache during selection: $e');
          }
        }
        
        if (Platform.isAndroid || Platform.isIOS) {
          setState(() {
            _imageFile = File(image.path);
            _webImage = null;
          });
          print('File image set: ${_imageFile!.path}');
        } else {
          // Web platform
          final bytes = await image.readAsBytes();
          setState(() {
            _webImage = bytes;
            _imageFile = null;
          });
          print('Web image set: ${bytes.length} bytes');
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
    
    // Also remove from Cloudinary if exists
    if (_userData?.photoUrl != null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await CloudinaryService.deleteProfilePicture(user.uid);
        }
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
      
      // Use UserService method which handles Cloudinary upload and cleanup
      final downloadUrl = await UserService.updateUserProfilePicture(
        userId: user.uid,
        imageData: _imageFile ?? _webImage!,
      );
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }
  
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        // If exiting edit mode without saving, revert changes
        _loadUserData();
        _imageFile = null;
        _webImage = null;
      }
    });
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
        print('Uploading new image...');
        
        // Step 1: Clear current image URL and show placeholder temporarily
        setState(() {
          _currentImageUrl = null;
        });
        
        // Step 2: Clear any existing image cache
        if (_userData?.photoUrl != null && _userData!.photoUrl!.isNotEmpty) {
          try {
            await NetworkImage(_userData!.photoUrl!).evict();
            if (_userData!.photoUrl!.contains('cloudinary.com')) {
              final optimizedUrl = CloudinaryService.getMediumUrl(_userData!.photoUrl!);
              await NetworkImage(optimizedUrl).evict();
            }
            print('Cleared old image cache');
          } catch (e) {
            print('Error clearing old image cache: $e');
          }
        }
        
        // Step 3: Wait a moment for UI to update
        await Future.delayed(Duration(milliseconds: 100));
        
        // Step 4: Upload new image
        newImageUrl = await _uploadImage();
        print('New image uploaded: $newImageUrl');
        
        // Step 5: Clear cache for new URL and wait again
        if (newImageUrl != null && newImageUrl.isNotEmpty) {
          try {
            await NetworkImage(newImageUrl).evict();
            if (newImageUrl.contains('cloudinary.com')) {
              final optimizedUrl = CloudinaryService.getMediumUrl(newImageUrl);
              await NetworkImage(optimizedUrl).evict();
            }
            print('Cleared new image cache');
          } catch (e) {
            print('Error clearing new image cache: $e');
          }
          
          // Wait before setting new URL
          await Future.delayed(Duration(milliseconds: 200));
        }
        
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
      );
      
      final updateData = <String, dynamic>{
  'email': _emailController.text.trim(),
  'name': _nameController.text.trim(),
  'photoUrl': newImageUrl,
  'lastActivity': DateTime.now(),
};

if (_phoneController.text.trim().isNotEmpty) {
  updateData['phone'] = _phoneController.text.trim();
} else {
  updateData['phone'] = FieldValue.delete(); // if you want to remove it
}

if (_bioController.text.trim().isNotEmpty) {
  updateData['bio'] = _bioController.text.trim();
} else {
  updateData['bio'] = FieldValue.delete();
}

if (_specialtyController.text.trim().isNotEmpty) {
  updateData['specialty'] = _specialtyController.text.trim();
} else {
  updateData['specialty'] = FieldValue.delete();
}

if (_locationController.text.trim().isNotEmpty) {
  updateData['location'] = _locationController.text.trim();
} else {
  updateData['location'] = FieldValue.delete();
}

await FirebaseFirestore.instance
    .collection('users')
    .doc(_userData!.uid)
    .update(updateData);

      // Update in app state
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setUserData(updatedUserData);
      
      // Step 6: Update local state
      setState(() {
        _userData = updatedUserData;
        _imageFile = null;
        _webImage = null;
        _currentImageUrl = newImageUrl;
        // Update timestamp to force widget rebuild
        _imageUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
      });
      
      // Step 7: Force multiple rebuilds to ensure fresh image loads
      for (int i = 0; i < 3; i++) {
        await Future.delayed(Duration(milliseconds: 100));
        if (mounted) {
          setState(() {});
        }
      }
      
      _showSuccessSnackBar('Profile updated successfully');
      
      // Exit edit mode after successful save
      setState(() {
        _isEditMode = false;
      });
      
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
    // First confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('This action will:'),
            SizedBox(height: 8),
            Text('• Permanently delete all your data'),
            Text('• Remove you from all conversations'),
            Text('• Delete your profile and photos'),
            Text('• Cannot be undone'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.red[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is permanent and cannot be reversed.',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
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
            child: Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Second confirmation dialog - Type to confirm
    final typeConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final confirmController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Final Confirmation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To confirm account deletion, please type:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DELETE MY ACCOUNT',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: confirmController,
                  decoration: InputDecoration(
                    labelText: 'Type the phrase above',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: confirmController.text == 'DELETE MY ACCOUNT'
                    ? () => Navigator.pop(context, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Delete Account'),
              ),
            ],
          ),
        );
      },
    );

    if (typeConfirmed != true) return;

    // Proceed with account deletion
    setState(() {
      _isDeletingAccount = true;
    });

    // Store reference to navigator for later use
    final navigator = Navigator.of(context);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('No user found');
        return;
      }

      final userId = user.uid;
      print('🔥 Starting account deletion for user: $userId');

      // Show progress dialog with proper context handling
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Deleting your account...'),
                Text(
                  'Please wait, this may take a moment.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );

      // Step 1: Delete profile picture from Cloudinary if exists
      try {
        if (_userData?.photoUrl != null && _userData!.photoUrl!.contains('cloudinary.com')) {
          await CloudinaryService.deleteProfilePicture(userId);
          print('✅ Profile picture deleted from Cloudinary');
        }
      } catch (e) {
        print('⚠️ Error deleting profile picture: $e');
        // Continue with deletion even if image cleanup fails
      }

      // Step 2: Delete related data from Firestore
      try {
        print('🔄 Deleting related data...');
        
        // Create a batch for multiple operations
        final batch = FirebaseFirestore.instance.batch();
        
        // Delete user's notifications
        final notificationsQuery = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .get();
        
        for (final doc in notificationsQuery.docs) {
          batch.delete(doc.reference);
        }
        print('📝 Prepared ${notificationsQuery.docs.length} notifications for deletion');

        // Update any mentee relationships (remove this user as mentor)
        final menteesQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('mentorId', isEqualTo: userId)
            .get();
        
        for (final doc in menteesQuery.docs) {
          batch.update(doc.reference, {'mentorId': null});
        }
        print('👥 Prepared ${menteesQuery.docs.length} mentee relationships for update');

        // Update any patient relationships (remove this user as doctor)
        final patientsQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('doctorId', isEqualTo: userId)
            .get();
        
        for (final doc in patientsQuery.docs) {
          batch.update(doc.reference, {'doctorId': null});
        }
        print('🏥 Prepared ${patientsQuery.docs.length} patient relationships for update');

        // Commit all related data changes
        await batch.commit();
        print('✅ All related data operations completed');

      } catch (e) {
        print('⚠️ Error updating related data: $e');
        // Continue with deletion even if some cleanup fails
      }

      // Step 3: Delete user document from Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();
        print('✅ User document deleted from Firestore');
      } catch (e) {
        print('❌ Error deleting user document from Firestore: $e');
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'document-deletion-failed',
          message: 'Failed to delete user document: ${e.toString()}',
        );
      }

      // Step 4: Delete user from Firebase Authentication (CRITICAL)
      try {
        await user.delete();
        print('✅ User deleted from Firebase Authentication');
      } catch (e) {
        print('❌ Critical error deleting user from Firebase Authentication: $e');
        
        if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
          throw FirebaseAuthException(
            code: 'requires-recent-login',
            message: 'For security, please sign out and sign back in, then try deleting your account again.',
          );
        }
        // Re-throw any authentication error as it's critical
        throw e;
      }

      // Close progress dialog first
      if (mounted) {
        navigator.pop(); // Close progress dialog
      }

      print('🎉 Account deletion completed successfully');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Account deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Wait a moment for user to see the success message
      await Future.delayed(Duration(seconds: 1));

      // Step 5: Clear app state and sign out (this will handle navigation)
     // Step 5: Clear app state and sign out
try {
  final appState = Provider.of<AppState>(context, listen: false);
  await appState.signOut();
  print('✅ App state cleared and user signed out');
  
  // Ensure navigation to sign-in screen
  if (mounted) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '../../auth/signing_screen.dart', // Replace with your actual sign-in route
      (route) => false,
    );
  }
} catch (e) {
  print('⚠️ Error clearing app state: $e');
  // Manual navigation as fallback
  if (mounted) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '../../auth/signing_screen.dart/login', // Replace with your actual sign-in route
      (route) => false,
    );
  }
}

    } catch (e) {
      print('❌ Account deletion failed: $e');
      
      // Ensure progress dialog is closed
      if (mounted) {
        try {
          navigator.pop(); // Close progress dialog
        } catch (navError) {
          print('Error closing progress dialog: $navError');
        }
      }
      
      String errorMessage = 'Failed to delete account';
      
      if (e is FirebaseAuthException) {
        print('Firebase Auth Error Code: ${e.code}');
        print('Firebase Auth Error Message: ${e.message}');
        
        switch (e.code) {
          case 'requires-recent-login':
            errorMessage = 'For security, please sign out and sign back in, then try deleting your account again.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your internet connection and try again.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many attempts. Please wait a moment and try again.';
            break;
          case 'user-disabled':
            errorMessage = 'Your account has been disabled. Please contact support.';
            break;
          case 'user-not-found':
            errorMessage = 'Account not found. It may have already been deleted.';
            break;
          default:
            errorMessage = 'Authentication error: ${e.message ?? e.code}';
        }
      } else if (e is FirebaseException) {
        print('Firebase Error Code: ${e.code}');
        print('Firebase Error Message: ${e.message}');
        errorMessage = 'Database error: ${e.message ?? 'Unknown database error'}';
      } else {
        print('General Error: $e');
        errorMessage = '$e andddd Account deletion completed, but there was an issue with cleanup.';
      }
      
      if (mounted) {
      //  _showErrorSnackBar(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }
  
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Profile Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isEditMode) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Editing',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 16),
            
            // Profile Photo
            Center(
              child: GestureDetector(
                onTap: _isEditMode ? _pickImage : null,
                child: Stack(
                  children: [
                    CircleAvatar(
                      key: ValueKey('${_currentImageUrl}_${_imageFile?.path}_${_webImage?.length}_$_imageUpdateTimestamp'),
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _getProfileImage(),
                      child: _getProfileImage() == null
                        ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                        : null,
                    ),
                    if (_isEditMode)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
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
            
            // ...existing code...
Form(
  key: _formKey,
  child: Column(
    children: [
      _buildProfileField(
        label: 'Full Name',
        controller: _nameController,
        icon: Icons.person,
        isEditMode: _isEditMode,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your name';
          }
          return null;
        },
      ),
      SizedBox(height: 16),
      _buildProfileField(
        label: 'Email',
        controller: _emailController,
        icon: Icons.email,
        isEditMode: _isEditMode,
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
      _buildProfileField(
        label: 'Phone Number (Optional)',
        controller: _phoneController,
        icon: Icons.phone,
        isEditMode: _isEditMode,
        keyboardType: TextInputType.phone,
      ),
      SizedBox(height: 16),
      _buildProfileField(
        label: 'Location (Optional)',
        controller: _locationController,
        icon: Icons.location_on,
        isEditMode: _isEditMode,
      ),
      SizedBox(height: 16),
      if (_userData?.role == 'doctor') ...[
        _buildProfileField(
          label: 'Medical Specialty',
          controller: _specialtyController,
          icon: Icons.medical_services,
          isEditMode: _isEditMode,
        ),
        SizedBox(height: 16),
      ],
      _buildProfileField(
        label: 'Bio (Optional)',
        controller: _bioController,
        icon: Icons.description,
        isEditMode: _isEditMode,
        maxLines: 3,
        maxLength: 500,
      ),
    ],
  ),
),
// ...existing code...
          ],
        ),
      ),
    );
  }
  
  ImageProvider? _getProfileImage() {
    print('=== _getProfileImage Debug ===');
    print('_imageFile: ${_imageFile?.path}');
    print('_webImage: ${_webImage?.length} bytes');
    print('_currentImageUrl: $_currentImageUrl');
    print('_imageUpdateTimestamp: $_imageUpdateTimestamp');
    
    if (_imageFile != null) {
      print('Returning: FileImage (selected file)');
      return FileImage(_imageFile!);
    } else if (_webImage != null) {
      print('Returning: MemoryImage (selected web image)');
      return MemoryImage(_webImage!);
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      print('Processing network image...');
      // Use Cloudinary optimized URL for profile display only if it's a Cloudinary URL
      if (_currentImageUrl!.contains('cloudinary.com')) {
        try {
          final optimizedUrl = CloudinaryService.getMediumUrl(_currentImageUrl!);
          print('Returning: NetworkImage (Cloudinary optimized) - $optimizedUrl');
          return NetworkImage(optimizedUrl);
        } catch (e) {
          print('Error optimizing Cloudinary URL: $e');
          // Fallback to original URL if optimization fails
          print('Returning: NetworkImage (Cloudinary fallback) - $_currentImageUrl');
          return NetworkImage(_currentImageUrl!);
        }
      } else {
        // For non-Cloudinary URLs, use as-is
        print('Returning: NetworkImage (non-Cloudinary) - $_currentImageUrl');
        return NetworkImage(_currentImageUrl!);
      }
    }
    print('Returning: null (no image)');
    return null;
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
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZoneSection() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700]),
                SizedBox(width: 8),
                Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Account',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Permanently delete your account and all associated data',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isDeletingAccount ? null : () {
                        print('🔴 Delete Account button pressed!');
                        _deleteAccount();
                      },
                      icon: _isDeletingAccount 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.delete_forever),
                      label: Text(_isDeletingAccount ? 'Deleting...' : 'Delete Account'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
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
          else if (_isEditMode)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: _toggleEditMode,
                  tooltip: 'Cancel',
                ),
                TextButton(
                  onPressed: _updateProfile,
                  child: Text('Save'),
                ),
              ],
            )
          else
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: _toggleEditMode,
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileSection(),
            SizedBox(height: 16),
            _buildSecuritySection(),
            SizedBox(height: 16),
            _buildDangerZoneSection(),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}