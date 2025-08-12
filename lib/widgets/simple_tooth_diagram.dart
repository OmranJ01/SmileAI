import 'package:flutter/material.dart';

class SimpleToothDiagram extends StatelessWidget {
  final String area;
  final Color highlightColor;
  
  const SimpleToothDiagram({
    Key? key,
    required this.area,
    required this.highlightColor,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Visual representation
          Container(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Mouth outline
                CustomPaint(
                  size: Size(200, 120),
                  painter: MouthPainter(
                    highlightArea: area,
                    highlightColor: highlightColor,
                  ),
                ),
                
                // Brushing motion indicator
                if (area.contains('Outside'))
                  Positioned(
                    bottom: 10,
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: highlightColor, size: 20),
                        SizedBox(width: 5),
                        Text('Circular Motion', 
                          style: TextStyle(
                            color: highlightColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (area.contains('Inside'))
                  Positioned(
                    bottom: 10,
                    child: Row(
                      children: [
                        Icon(Icons.arrow_upward, color: highlightColor, size: 20),
                        SizedBox(width: 5),
                        Text('Sweep Up/Down', 
                          style: TextStyle(
                            color: highlightColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (area.contains('Chewing'))
                  Positioned(
                    bottom: 10,
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, color: highlightColor, size: 20),
                        SizedBox(width: 5),
                        Text('Back & Forth', 
                          style: TextStyle(
                            color: highlightColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (area.contains('Tongue'))
                  Positioned(
                    bottom: 10,
                    child: Row(
                      children: [
                        Icon(Icons.arrow_forward, color: highlightColor, size: 20),
                        SizedBox(width: 5),
                        Text('Front to Back', 
                          style: TextStyle(
                            color: highlightColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          SizedBox(height: 10),
          
          // Area indicator with emoji
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: highlightColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: highlightColor, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getEmoji(area),
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(width: 10),
                Text(
                  _getSimpleAreaName(area),
                  style: TextStyle(
                    color: highlightColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getEmoji(String area) {
    if (area.contains('Upper')) return '👆';
    if (area.contains('Lower')) return '👇';
    if (area.contains('Tongue')) return '👅';
    if (area.contains('Chewing')) return '🦷';
    return '😁';
  }
  
  String _getSimpleAreaName(String area) {
    if (area.contains('Right')) return 'Right Side';
    if (area.contains('Left')) return 'Left Side';
    if (area.contains('Front')) return 'Front Teeth';
    if (area.contains('Inside')) return 'Inside Surface';
    if (area.contains('Chewing')) return 'Chewing Surface';
    if (area.contains('Tongue')) return 'Tongue';
    return area;
  }
}

class MouthPainter extends CustomPainter {
  final String highlightArea;
  final Color highlightColor;
  
  MouthPainter({
    required this.highlightArea,
    required this.highlightColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.grey[300]!;
    
    final highlightPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = highlightColor.withOpacity(0.6);
    
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[600]!
      ..strokeWidth = 2;
    
    // Draw simple mouth shape
    final mouthPath = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.5, 0,
        size.width, size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.5, size.height,
        0, size.height * 0.5,
      )
      ..close();
    
    canvas.drawPath(mouthPath, paint);
    canvas.drawPath(mouthPath, borderPaint);
    
    // Draw teeth sections
    final teethPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    
    final teethBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[400]!
      ..strokeWidth = 1;
    
    // Upper teeth area
    final upperTeethRect = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.2,
      size.width * 0.7,
      size.height * 0.25,
    );
    
    // Lower teeth area
    final lowerTeethRect = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.55,
      size.width * 0.7,
      size.height * 0.25,
    );
    
    // Draw teeth areas
    canvas.drawRRect(
      RRect.fromRectAndRadius(upperTeethRect, Radius.circular(5)),
      teethPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lowerTeethRect, Radius.circular(5)),
      teethPaint,
    );
    
    // Highlight appropriate areas
    if (highlightArea.contains('Upper')) {
      Rect highlightRect = upperTeethRect;
      
      if (highlightArea.contains('Right')) {
        highlightRect = Rect.fromLTWH(
          upperTeethRect.left,
          upperTeethRect.top,
          upperTeethRect.width * 0.3,
          upperTeethRect.height,
        );
      } else if (highlightArea.contains('Left')) {
        highlightRect = Rect.fromLTWH(
          upperTeethRect.right - upperTeethRect.width * 0.3,
          upperTeethRect.top,
          upperTeethRect.width * 0.3,
          upperTeethRect.height,
        );
      } else if (highlightArea.contains('Front')) {
        highlightRect = Rect.fromLTWH(
          upperTeethRect.left + upperTeethRect.width * 0.3,
          upperTeethRect.top,
          upperTeethRect.width * 0.4,
          upperTeethRect.height,
        );
      }
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(highlightRect, Radius.circular(5)),
        highlightPaint,
      );
    }
    
    if (highlightArea.contains('Lower')) {
      Rect highlightRect = lowerTeethRect;
      
      if (highlightArea.contains('Right')) {
        highlightRect = Rect.fromLTWH(
          lowerTeethRect.left,
          lowerTeethRect.top,
          lowerTeethRect.width * 0.3,
          lowerTeethRect.height,
        );
      } else if (highlightArea.contains('Left')) {
        highlightRect = Rect.fromLTWH(
          lowerTeethRect.right - lowerTeethRect.width * 0.3,
          lowerTeethRect.top,
          lowerTeethRect.width * 0.3,
          lowerTeethRect.height,
        );
      } else if (highlightArea.contains('Front')) {
        highlightRect = Rect.fromLTWH(
          lowerTeethRect.left + lowerTeethRect.width * 0.3,
          lowerTeethRect.top,
          lowerTeethRect.width * 0.4,
          lowerTeethRect.height,
        );
      }
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(highlightRect, Radius.circular(5)),
        highlightPaint,
      );
    }
    
    if (highlightArea.contains('Chewing')) {
      // Highlight top surface of all teeth
      canvas.drawRect(
        Rect.fromLTWH(
          upperTeethRect.left + 5,
          upperTeethRect.top + 5,
          upperTeethRect.width - 10,
          10,
        ),
        highlightPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          lowerTeethRect.left + 5,
          lowerTeethRect.top + 5,
          lowerTeethRect.width - 10,
          10,
        ),
        highlightPaint,
      );
    }
    
    if (highlightArea.contains('Tongue')) {
      // Draw tongue shape
      final tonguePath = Path()
        ..moveTo(size.width * 0.3, size.height * 0.6)
        ..quadraticBezierTo(
          size.width * 0.5, size.height * 0.5,
          size.width * 0.7, size.height * 0.6,
        )
        ..quadraticBezierTo(
          size.width * 0.5, size.height * 0.8,
          size.width * 0.3, size.height * 0.6,
        );
      
      canvas.drawPath(tonguePath, highlightPaint);
    }
    
    // Draw borders
    canvas.drawRRect(
      RRect.fromRectAndRadius(upperTeethRect, Radius.circular(5)),
      teethBorderPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lowerTeethRect, Radius.circular(5)),
      teethBorderPaint,
    );
  }
  
  @override
  bool shouldRepaint(MouthPainter oldDelegate) {
    return oldDelegate.highlightArea != highlightArea ||
           oldDelegate.highlightColor != highlightColor;
  }
} 