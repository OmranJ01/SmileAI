/// Cloudinary Configuration
/// 
/// This file contains the Cloudinary configuration for the SmileAI app.
/// Replace the placeholder values with your actual Cloudinary credentials.
/// 
/// Steps to configure:
/// 1. Create a free account at https://cloudinary.com
/// 2. Go to your dashboard and copy the credentials
/// 3. Replace the values below
/// 4. Create an upload preset in your Cloudinary console (Settings > Upload)

class CloudinaryConfig {
  // Cloudinary credentials for SmileAI app
  static const String cloudName = 'dapohzkeo';
  static const String apiKey = '335759812661196';
  static const String apiSecret = 'x5m3GBGhaSqZ7Vv7HkPtgNsw5jo';
  static const String uploadPreset = 'smileAI';
  
  // Profile picture settings
  static const String profilePictureFolder = 'profile_pictures';
  static const int profilePictureSize = 400;
  static const int thumbnailSize = 150;
  static const int mediumSize = 300;
  
  // Image quality settings
  static const String defaultQuality = 'auto:good';
  static const String defaultFormat = 'auto';
  
  // Validate configuration
  static bool get isConfigured => 
      cloudName != 'YOUR_CLOUD_NAME' &&
      apiKey != 'YOUR_API_KEY' &&
      apiSecret != 'YOUR_API_SECRET' &&
      uploadPreset != 'YOUR_UPLOAD_PRESET';
  
  // Environment-specific configurations
  static bool get isDevelopment => const bool.fromEnvironment('dart.vm.product') == false;
  
  // Upload preset based on environment
  static String get activeUploadPreset => isDevelopment ? uploadPreset : uploadPreset;
  
  // Get configuration status message
  static String get configurationStatus {
    if (isConfigured) {
      return 'Cloudinary is properly configured';
    } else {
      return 'Cloudinary configuration is missing. Please update lib/utils/cloudinary_config.dart';
    }
  }
} 