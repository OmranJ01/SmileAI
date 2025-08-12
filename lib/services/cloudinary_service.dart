import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../utils/cloudinary_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CloudinaryService {
  static final CloudinaryPublic _cloudinary = CloudinaryPublic(
    CloudinaryConfig.cloudName,
    CloudinaryConfig.uploadPreset,
    cache: false,
  );

  /// Upload profile picture to Cloudinary
  /// Returns the secure URL of the uploaded image
  static Future<String?> uploadProfilePicture({
    required String userId,
    required dynamic imageData, // File for mobile, Uint8List for web
  }) async {
    try {
      if (!CloudinaryConfig.isConfigured) {
        print('Cloudinary is not configured. Please update cloudinary_config.dart');
        return null;
      }

      CloudinaryResponse response;
      
      if (imageData is File) {
        // For mobile platforms - let Cloudinary generate unique filename
        response = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            imageData.path,
            resourceType: CloudinaryResourceType.Image,
            // Remove fixed publicId to let Cloudinary use unique filenames
            // folder: CloudinaryConfig.profilePictureFolder, // Let preset handle folder
          ),
        );
      } else if (imageData is Uint8List) {
        // For web platform - let Cloudinary generate unique filename
        response = await _cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            imageData,
            identifier: 'profile_image', // Generic identifier for web
            resourceType: CloudinaryResourceType.Image,
            // Remove fixed publicId to let Cloudinary use unique filenames
            // folder: CloudinaryConfig.profilePictureFolder, // Let preset handle folder
          ),
        );
      } else {
        throw Exception('Invalid image data type');
      }

      print('Cloudinary upload successful: ${response.secureUrl}');
      return response.secureUrl;
      
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  /// Delete profile picture from Cloudinary
  static Future<bool> deleteProfilePicture(String userId) async {
    try {
      if (!CloudinaryConfig.isConfigured) {
        print('Cloudinary is not configured. Please update cloudinary_config.dart');
        return false;
      }

      // Get current user data to find the photo URL
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!doc.exists) {
        print('User document not found');
        return false;
      }
      
      final photoUrl = doc.data()?['photoUrl'] as String?;
      if (photoUrl == null || !photoUrl.contains('cloudinary.com')) {
        print('No Cloudinary photo to delete');
        return true; // Nothing to delete is considered success
      }
      
      // Extract publicId from URL
      final publicId = extractPublicIdFromUrl(photoUrl);
      if (publicId == null) {
        print('Could not extract publicId from URL: $photoUrl');
        return false;
      }
      
      print('Deleting image with publicId: $publicId');
      
      // Generate timestamp and signature for authenticated delete request
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final stringToSign = 'public_id=$publicId&timestamp=$timestamp${CloudinaryConfig.apiSecret}';
      final signature = sha1.convert(utf8.encode(stringToSign)).toString();
      
      // Make delete request
      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/destroy'),
        body: {
          'public_id': publicId,
          'api_key': CloudinaryConfig.apiKey,
          'timestamp': timestamp,
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Delete response: $responseData');
        return responseData['result'] == 'ok';
      }
      
      print('Delete request failed with status: ${response.statusCode}');
      return false;
      
    } catch (e) {
      print('Error deleting from Cloudinary: $e');
      return false;
    }
  }
  
  /// Extract publicId from Cloudinary URL
  static String? extractPublicIdFromUrl(String url) {
    try {
      // Example URL: https://res.cloudinary.com/dapohzkeo/image/upload/v1234567890/cloudinary-upload-preset-demo/smile/filename.jpg
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // Find the upload segment
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 2 >= pathSegments.length) {
        return null;
      }
      
      // Skip version (v1234567890) and get the rest
      final publicIdParts = pathSegments.sublist(uploadIndex + 2);
      
      // Join parts and remove file extension
      String publicId = publicIdParts.join('/');
      
      // Remove file extension
      final lastDotIndex = publicId.lastIndexOf('.');
      if (lastDotIndex != -1) {
        publicId = publicId.substring(0, lastDotIndex);
      }
      
      return publicId;
      
    } catch (e) {
      print('Error extracting publicId: $e');
      return null;
    }
  }

  /// Generate a transformed URL for existing image
  static String getTransformedUrl(String originalUrl, {
    int? width,
    int? height,
    String? crop,
    String? gravity,
    String? quality,
  }) {
    try {
      // Extract public ID from Cloudinary URL
      final uri = Uri.parse(originalUrl);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length < 3) return originalUrl;
      
      // Find the public ID by looking for the upload segment
      final uploadIndex = pathSegments.indexWhere((segment) => 
          segment == 'upload');
      
      if (uploadIndex == -1 || uploadIndex + 1 >= pathSegments.length) {
        return originalUrl;
      }
      
      // Get everything after 'upload/' as the public ID path
      final publicIdParts = pathSegments.sublist(uploadIndex + 1);
      
      // Handle versioned URLs (remove version if present)
      final publicIdPath = publicIdParts.where((part) => !part.startsWith('v')).join('/');
      final publicIdWithoutExtension = publicIdPath.split('.').first;
      
      // Build transformation string
      final transformations = <String>[];
      
      if (width != null) transformations.add('w_$width');
      if (height != null) transformations.add('h_$height');
      if (crop != null) transformations.add('c_$crop');
      if (gravity != null) transformations.add('g_$gravity');
      if (quality != null) transformations.add('q_$quality');
      
      final transformationString = transformations.isNotEmpty 
          ? '/${transformations.join(',')}'
          : '';
      
      // Use the configured cloud name instead of extracting from URL
      return 'https://res.cloudinary.com/${CloudinaryConfig.cloudName}/image/upload$transformationString/$publicIdWithoutExtension';
      
    } catch (e) {
      print('Error generating transformed URL: $e');
      return originalUrl;
    }
  }

  /// Get optimized thumbnail URL
  static String getThumbnailUrl(String originalUrl, {int? size}) {
    return getTransformedUrl(
      originalUrl,
      width: size ?? CloudinaryConfig.thumbnailSize,
      height: size ?? CloudinaryConfig.thumbnailSize,
      crop: 'fill',
      gravity: 'face',
      quality: CloudinaryConfig.defaultQuality,
    );
  }

  /// Get medium size profile picture URL
  static String getMediumUrl(String originalUrl, {int? size}) {
    return getTransformedUrl(
      originalUrl,
      width: size ?? CloudinaryConfig.mediumSize,
      height: size ?? CloudinaryConfig.mediumSize,
      crop: 'fill',
      gravity: 'face',
      quality: CloudinaryConfig.defaultQuality,
    );
  }

  /// Validate Cloudinary configuration
  static bool isConfigured() {
    return CloudinaryConfig.isConfigured;
  }
}