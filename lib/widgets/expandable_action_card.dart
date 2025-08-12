import 'package:flutter/material.dart';

class ExpandableActionCard extends StatefulWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final List<ActionButton> actions;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool initiallyExpanded;

  const ExpandableActionCard({
    Key? key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.actions,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
    this.initiallyExpanded = false,
  }) : super(key: key);

  @override
  _ExpandableActionCardState createState() => _ExpandableActionCardState();
}

class _ExpandableActionCardState extends State<ExpandableActionCard> 
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.white,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleExpanded,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          child: Padding(
            padding: widget.padding ?? EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    if (widget.leading != null) ...[
                      widget.leading!,
                      SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          widget.title,
                          if (widget.subtitle != null) ...[
                            SizedBox(height: 4),
                            widget.subtitle!,
                          ],
                        ],
                      ),
                    ),
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.5).animate(_expandAnimation),
                      child: Icon(
                        Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: Column(
                    children: [
                      SizedBox(height: 16),
                      if (widget.actions.length <= 2)
                        Row(
                          children: widget.actions
                              .map((action) => Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: _buildActionButton(action),
                                    ),
                                  ))
                              .toList(),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.actions
                              .map((action) => _buildActionChip(action))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(ActionButton action) {
    if (action.isOutlined) {
      return OutlinedButton.icon(
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
        style: OutlinedButton.styleFrom(
          foregroundColor: action.color,
          side: BorderSide(color: action.color ?? Theme.of(context).primaryColor),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
        style: ElevatedButton.styleFrom(
          backgroundColor: action.color,
          foregroundColor: action.foregroundColor ?? Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }
  }

  Widget _buildActionChip(ActionButton action) {
    return ActionChip(
      onPressed: action.onPressed,
      avatar: Icon(action.icon, size: 18, color: action.color),
      label: Text(action.label),
      backgroundColor: action.color?.withOpacity(0.1),
      labelStyle: TextStyle(color: action.color),
      side: BorderSide(color: action.color ?? Theme.of(context).primaryColor),
    );
  }
}

class ActionButton {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final Color? foregroundColor;
  final bool isOutlined;

  const ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.foregroundColor,
    this.isOutlined = false,
  });
}

// Convenience widget for simple list items with actions
class ExpandableListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<ActionButton> actions;
  final Color? backgroundColor;

  const ExpandableListItem({
    Key? key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.actions,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExpandableActionCard(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            )
          : null,
      leading: leading,
      actions: actions,
      backgroundColor: backgroundColor,
    );
  }
} 