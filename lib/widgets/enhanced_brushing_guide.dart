import 'package:flutter/material.dart';

class EnhancedBrushingGuide extends StatelessWidget {
  final String area;
  final Color highlightColor;
  final int timeRemaining;
  
  const EnhancedBrushingGuide({
    Key? key,
    required this.area,
    required this.highlightColor,
    required this.timeRemaining,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: highlightColor.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The brushing guide image
            Image.asset(
              'assets/images/brushing_guide.png',
              height: 200,
              fit: BoxFit.cover,
            ),
            
            // Overlay for current area highlight
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: highlightColor,
                    width: 3,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      area,
                      style: TextStyle(
                        color: highlightColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer,
                          color: highlightColor,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${timeRemaining}s',
                          style: TextStyle(
                            color: highlightColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Animated indicator for brushing motion
            Positioned(
              bottom: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getMotionIcon(),
                    SizedBox(width: 8),
                    Text(
                      _getMotionText(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Progress ring around the image
            Positioned.fill(
              child: CustomPaint(
                painter: ProgressRingPainter(
                  progress: _getProgressForArea(),
                  color: highlightColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _getMotionIcon() {
    if (area.contains('Outside')) {
      return Icon(Icons.refresh, color: Colors.white, size: 16);
    } else if (area.contains('Inside')) {
      return Icon(Icons.arrow_upward, color: Colors.white, size: 16);
    } else if (area.contains('Chewing')) {
      return Icon(Icons.swap_horiz, color: Colors.white, size: 16);
    } else if (area.contains('Tongue')) {
      return Icon(Icons.arrow_forward, color: Colors.white, size: 16);
    }
    return Icon(Icons.brush, color: Colors.white, size: 16);
  }
  
  String _getMotionText() {
    if (area.contains('Outside')) return 'Circular Motions';
    if (area.contains('Inside')) return 'Vertical Sweeping';
    if (area.contains('Chewing')) return 'Back & Forth';
    if (area.contains('Tongue')) return 'Front to Back';
    return 'Gentle Brushing';
  }
  
  double _getProgressForArea() {
    // This would be calculated based on the current step and total steps
    // For now, returning a sample value
    return 0.7;
  }
}

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  ProgressRingPainter({
    required this.progress,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Background ring
    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Progress ring
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    final progressAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      progressAngle,
      false,
      progressPaint,
    );
  }
  
  @override
  bool shouldRepaint(ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
} 