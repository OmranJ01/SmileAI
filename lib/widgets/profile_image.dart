import 'package:flutter/material.dart';
import '../services/cloudinary_service.dart';

class ProfileImage extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final Widget? placeholder;
  final VoidCallback? onTap;
  final String? heroTag;
  final ImageSize size;

  const ProfileImage({
    Key? key,
    this.imageUrl,
    this.radius = 30,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2,
    this.placeholder,
    this.onTap,
    this.heroTag,
    this.size = ImageSize.medium,
  }) : super(key: key);

  /// Small profile image for lists and compact displays
  const ProfileImage.small({
    Key? key,
    this.imageUrl,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 1,
    this.placeholder,
    this.onTap,
    this.heroTag,
  }) : radius = 20,
       size = ImageSize.thumbnail,
       super(key: key);

  /// Medium profile image for cards and standard displays
  const ProfileImage.medium({
    Key? key,
    this.imageUrl,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2,
    this.placeholder,
    this.onTap,
    this.heroTag,
  }) : radius = 30,
       size = ImageSize.medium,
       super(key: key);

  /// Large profile image for profile pages and detailed views
  const ProfileImage.large({
    Key? key,
    this.imageUrl,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 3,
    this.placeholder,
    this.onTap,
    this.heroTag,
  }) : radius = 50,
       size = ImageSize.large,
       super(key: key);

  /// Extra large profile image for settings and edit profile
  const ProfileImage.extraLarge({
    Key? key,
    this.imageUrl,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 4,
    this.placeholder,
    this.onTap,
    this.heroTag,
  }) : radius = 60,
       size = ImageSize.large,
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget avatarWidget = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      backgroundImage: _getOptimizedImage(),
      child: _getOptimizedImage() == null ? _buildPlaceholder(theme) : null,
    );

    if (showBorder) {
      avatarWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? theme.primaryColor,
            width: borderWidth,
          ),
        ),
        child: avatarWidget,
      );
    }

    if (heroTag != null) {
      avatarWidget = Hero(
        tag: heroTag!,
        child: avatarWidget,
      );
    }

    if (onTap != null) {
      avatarWidget = GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  ImageProvider? _getOptimizedImage() {
    if (imageUrl == null || imageUrl!.isEmpty) return null;

    // If it's a Cloudinary URL, optimize it
    if (imageUrl!.contains('cloudinary.com')) {
      try {
        String optimizedUrl;
        switch (size) {
          case ImageSize.thumbnail:
            optimizedUrl = CloudinaryService.getThumbnailUrl(imageUrl!);
            break;
          case ImageSize.medium:
            optimizedUrl = CloudinaryService.getMediumUrl(imageUrl!);
            break;
          case ImageSize.large:
            optimizedUrl = CloudinaryService.getTransformedUrl(
              imageUrl!,
              width: (radius * 2 * 2).round(), // 2x for retina display
              height: (radius * 2 * 2).round(),
              crop: 'fill',
              gravity: 'face',
              quality: 'auto:good',
            );
            break;
        }
        return NetworkImage(optimizedUrl);
      } catch (e) {
        print('Error optimizing Cloudinary URL: $e');
        // Fallback to original URL if optimization fails
        return NetworkImage(imageUrl!);
      }
    }

    // For non-Cloudinary URLs, use as-is
    return NetworkImage(imageUrl!);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    if (placeholder != null) return placeholder!;

    return Icon(
      Icons.person,
      size: radius * 1.2,
      color: Colors.grey[400],
    );
  }
}

/// Profile image with loading states and error handling
class ProfileImageWithLoading extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final String? heroTag;
  final ImageSize size;

  const ProfileImageWithLoading({
    Key? key,
    this.imageUrl,
    this.radius = 30,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.heroTag,
    this.size = ImageSize.medium,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (imageUrl == null || imageUrl!.isEmpty) {
      return ProfileImage(
        imageUrl: null,
        radius: radius,
        showBorder: showBorder,
        borderColor: borderColor,
        borderWidth: borderWidth,
        placeholder: placeholder,
        onTap: onTap,
        heroTag: heroTag,
        size: size,
      );
    }

    Widget avatarWidget = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          _getOptimizedUrl(),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? Icon(
              Icons.person,
              size: radius * 1.2,
              color: Colors.grey[400],
            );
          },
        ),
      ),
    );

    if (showBorder) {
      avatarWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? theme.primaryColor,
            width: borderWidth,
          ),
        ),
        child: avatarWidget,
      );
    }

    if (heroTag != null) {
      avatarWidget = Hero(
        tag: heroTag!,
        child: avatarWidget,
      );
    }

    if (onTap != null) {
      avatarWidget = GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  String _getOptimizedUrl() {
    if (imageUrl!.contains('cloudinary.com')) {
      try {
        switch (size) {
          case ImageSize.thumbnail:
            return CloudinaryService.getThumbnailUrl(imageUrl!);
          case ImageSize.medium:
            return CloudinaryService.getMediumUrl(imageUrl!);
          case ImageSize.large:
            return CloudinaryService.getTransformedUrl(
              imageUrl!,
              width: (radius * 2 * 2).round(),
              height: (radius * 2 * 2).round(),
              crop: 'fill',
              gravity: 'face',
              quality: 'auto:good',
            );
        }
        return imageUrl!; // Fallback for any unhandled enum values
      } catch (e) {
        print('Error optimizing Cloudinary URL: $e');
        // Fallback to original URL if optimization fails
        return imageUrl!;
      }
    }
    return imageUrl!;
  }
}

enum ImageSize {
  thumbnail,
  medium,
  large,
} 