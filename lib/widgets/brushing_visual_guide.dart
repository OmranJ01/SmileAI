import 'package:flutter/material.dart';
import 'dart:math' as math;

class BrushingVisualGuide extends StatelessWidget {
  final String area;
  final Color highlightColor;
  
  const BrushingVisualGuide({
    Key? key,
    required this.area,
    required this.highlightColor,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 200,
      child: CustomPaint(
        painter: TeethDiagramPainter(
          highlightArea: area,
          highlightColor: highlightColor,
        ),
      ),
    );
  }
}

class TeethDiagramPainter extends CustomPainter {
  final String highlightArea;
  final Color highlightColor;
  
  TeethDiagramPainter({
    required this.highlightArea,
    required this.highlightColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Define tooth positions for upper and lower jaws
    final upperTeethY = centerY - 40;
    final lowerTeethY = centerY + 40;
    final teethWidth = 25.0;
    final teethHeight = 35.0;
    final teethSpacing = 30.0;
    
    // Paint for teeth
    final toothPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final toothBorderPaint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final highlightPaint = Paint()
      ..color = highlightColor.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    final arrowPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    // Draw gum line
    final gumPaint = Paint()
      ..color = Colors.pink[200]!
      ..style = PaintingStyle.fill;
    
    // Upper gum
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, upperTeethY - 20, size.width - 40, 25),
        Radius.circular(10),
      ),
      gumPaint,
    );
    
    // Lower gum
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, lowerTeethY + teethHeight - 5, size.width - 40, 25),
        Radius.circular(10),
      ),
      gumPaint,
    );
    
    // Helper function to draw a tooth
    void drawTooth(double x, double y, bool isHighlighted, {bool isUpper = true}) {
      final toothRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - teethWidth/2, y, teethWidth, teethHeight),
        Radius.circular(5),
      );
      
      canvas.drawRRect(toothRect, toothPaint);
      canvas.drawRRect(toothRect, toothBorderPaint);
      
      if (isHighlighted) {
        canvas.drawRRect(toothRect, highlightPaint);
      }
    }
    
    // Draw teeth based on highlighted area
    if (highlightArea.contains('Upper')) {
      // Draw upper teeth
      for (int i = -3; i <= 3; i++) {
        final x = centerX + (i * teethSpacing);
        bool highlight = false;
        
        if (highlightArea.contains('Right') && i > 0) highlight = true;
        if (highlightArea.contains('Left') && i < 0) highlight = true;
        if (highlightArea.contains('Front') && i.abs() <= 1) highlight = true;
        if (highlightArea.contains('All')) highlight = true;
        
        drawTooth(x, upperTeethY, highlight, isUpper: true);
      }
      
      // Draw lower teeth (not highlighted)
      for (int i = -3; i <= 3; i++) {
        final x = centerX + (i * teethSpacing);
        drawTooth(x, lowerTeethY, false, isUpper: false);
      }
    } else if (highlightArea.contains('Lower')) {
      // Draw upper teeth (not highlighted)
      for (int i = -3; i <= 3; i++) {
        final x = centerX + (i * teethSpacing);
        drawTooth(x, upperTeethY, false, isUpper: true);
      }
      
      // Draw lower teeth
      for (int i = -3; i <= 3; i++) {
        final x = centerX + (i * teethSpacing);
        bool highlight = false;
        
        if (highlightArea.contains('Right') && i > 0) highlight = true;
        if (highlightArea.contains('Left') && i < 0) highlight = true;
        if (highlightArea.contains('Front') && i.abs() <= 1) highlight = true;
        if (highlightArea.contains('All')) highlight = true;
        
        drawTooth(x, lowerTeethY, highlight, isUpper: false);
      }
    } else if (highlightArea.contains('All Chewing')) {
      // Highlight chewing surfaces
      for (int i = -3; i <= 3; i++) {
        final x = centerX + (i * teethSpacing);
        
        // Draw teeth normally
        drawTooth(x, upperTeethY, false);
        drawTooth(x, lowerTeethY, false);
        
        // Highlight chewing surfaces
        final chewingSurface = Rect.fromLTWH(
          x - teethWidth/2 + 3, 
          upperTeethY + 5, 
          teethWidth - 6, 
          10
        );
        canvas.drawRect(chewingSurface, highlightPaint);
        
        final lowerChewingSurface = Rect.fromLTWH(
          x - teethWidth/2 + 3, 
          lowerTeethY + 5, 
          teethWidth - 6, 
          10
        );
        canvas.drawRect(lowerChewingSurface, highlightPaint);
      }
    } else if (highlightArea.contains('Tongue')) {
      // Draw all teeth normally
      for (int i = -3; i <= 3; i++) {
        final x = centerX + (i * teethSpacing);
        drawTooth(x, upperTeethY, false);
        drawTooth(x, lowerTeethY, false);
      }
      
      // Draw tongue
      final tonguePaint = Paint()
        ..color = Colors.pink[300]!
        ..style = PaintingStyle.fill;
      
      final tonguePath = Path()
        ..moveTo(centerX - 60, centerY + 10)
        ..quadraticBezierTo(centerX, centerY - 10, centerX + 60, centerY + 10)
        ..quadraticBezierTo(centerX, centerY + 40, centerX - 60, centerY + 10);
      
      canvas.drawPath(tonguePath, tonguePaint);
      canvas.drawPath(tonguePath, highlightPaint);
    }
    
    // Draw directional arrows for brushing motion
    if (highlightArea.contains('Outside')) {
      // Draw circular motion indicator
      final arrowX = highlightArea.contains('Right') ? centerX + 80 : 
                     highlightArea.contains('Left') ? centerX - 80 : centerX;
      final arrowY = highlightArea.contains('Upper') ? upperTeethY + 15 : lowerTeethY + 15;
      
      // Draw circular arrow
      final path = Path();
      final radius = 15.0;
      path.addArc(
        Rect.fromCircle(center: Offset(arrowX, arrowY), radius: radius),
        -math.pi / 2,
        math.pi * 1.5,
      );
      canvas.drawPath(path, arrowPaint);
      
      // Arrow head
      final endAngle = math.pi;
      final endX = arrowX + radius * math.cos(endAngle);
      final endY = arrowY + radius * math.sin(endAngle);
      
      final arrowPath = Path()
        ..moveTo(endX - 5, endY - 5)
        ..lineTo(endX, endY)
        ..lineTo(endX + 5, endY - 5);
      canvas.drawPath(arrowPath, arrowPaint);
      
    } else if (highlightArea.contains('Inside')) {
      // Draw vertical sweeping motion
      final startY = highlightArea.contains('Upper') ? upperTeethY + teethHeight : lowerTeethY;
      final endY = highlightArea.contains('Upper') ? upperTeethY : lowerTeethY + teethHeight;
      
      canvas.drawLine(
        Offset(centerX, startY),
        Offset(centerX, endY),
        arrowPaint,
      );
      
      // Arrow head
      final arrowPath = Path()
        ..moveTo(centerX - 5, endY + (highlightArea.contains('Upper') ? 5 : -5))
        ..lineTo(centerX, endY)
        ..lineTo(centerX + 5, endY + (highlightArea.contains('Upper') ? 5 : -5));
      canvas.drawPath(arrowPath, arrowPaint);
      
    } else if (highlightArea.contains('Chewing')) {
      // Draw back-and-forth motion
      canvas.drawLine(
        Offset(centerX - 30, centerY),
        Offset(centerX + 30, centerY),
        arrowPaint,
      );
      
      // Arrow heads on both ends
      final leftArrow = Path()
        ..moveTo(centerX - 30 + 5, centerY - 5)
        ..lineTo(centerX - 30, centerY)
        ..lineTo(centerX - 30 + 5, centerY + 5);
      canvas.drawPath(leftArrow, arrowPaint);
      
      final rightArrow = Path()
        ..moveTo(centerX + 30 - 5, centerY - 5)
        ..lineTo(centerX + 30, centerY)
        ..lineTo(centerX + 30 - 5, centerY + 5);
      canvas.drawPath(rightArrow, arrowPaint);
    }
    
    // Add text label
    final textPainter = TextPainter(
      text: TextSpan(
        text: _getInstructionText(highlightArea),
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, size.height - 20),
    );
  }
  
  String _getInstructionText(String area) {
    if (area.contains('Outside')) return 'Circular Motions';
    if (area.contains('Inside')) return 'Vertical Sweeping';
    if (area.contains('Chewing')) return 'Back & Forth';
    if (area.contains('Tongue')) return 'Front to Back';
    return '';
  }
  
  @override
  bool shouldRepaint(TeethDiagramPainter oldDelegate) {
    return oldDelegate.highlightArea != highlightArea ||
           oldDelegate.highlightColor != highlightColor;
  }
} 