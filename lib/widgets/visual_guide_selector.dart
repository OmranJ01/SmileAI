import 'package:flutter/material.dart';
import 'brushing_visual_guide.dart';
import 'simple_tooth_diagram.dart';

enum VisualGuideStyle { detailed, simple, custom }

class VisualGuideSelector extends StatefulWidget {
  final String area;
  final Color highlightColor;
  final String? customImagePath;
  
  const VisualGuideSelector({
    Key? key,
    required this.area,
    required this.highlightColor,
    this.customImagePath,
  }) : super(key: key);
  
  @override
  _VisualGuideSelectorState createState() => _VisualGuideSelectorState();
}

class _VisualGuideSelectorState extends State<VisualGuideSelector> {
  VisualGuideStyle _currentStyle = VisualGuideStyle.detailed;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Visual guide display
        Container(
          height: 220,
          child: _buildVisualGuide(),
        ),
        
        // Style selector
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStyleButton(
              'Detailed',
              VisualGuideStyle.detailed,
              Icons.grid_on,
            ),
            SizedBox(width: 10),
            _buildStyleButton(
              'Simple',
              VisualGuideStyle.simple,
              Icons.crop_square,
            ),
            if (widget.customImagePath != null) ...[
              SizedBox(width: 10),
              _buildStyleButton(
                'Custom',
                VisualGuideStyle.custom,
                Icons.image,
              ),
            ],
          ],
        ),
      ],
    );
  }
  
  Widget _buildVisualGuide() {
    switch (_currentStyle) {
      case VisualGuideStyle.detailed:
        return BrushingVisualGuide(
          area: widget.area,
          highlightColor: widget.highlightColor,
        );
      
      case VisualGuideStyle.simple:
        return SimpleToothDiagram(
          area: widget.area,
          highlightColor: widget.highlightColor,
        );
      
      case VisualGuideStyle.custom:
        return Image.asset(
          widget.customImagePath!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to detailed view if image fails
            return BrushingVisualGuide(
              area: widget.area,
              highlightColor: widget.highlightColor,
            );
          },
        );
    }
  }
  
  Widget _buildStyleButton(String label, VisualGuideStyle style, IconData icon) {
    final isSelected = _currentStyle == style;
    
    return Material(
      color: isSelected ? widget.highlightColor.withOpacity(0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentStyle = style;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? widget.highlightColor : Colors.grey[400]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? widget.highlightColor : Colors.grey[600],
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? widget.highlightColor : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 