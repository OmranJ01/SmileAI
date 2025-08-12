import 'package:flutter/material.dart';
import 'package:flutter_application_2/Providers/theme_provider.dart';
import 'package:provider/provider.dart';

class ThemeToggle extends StatelessWidget {
  final bool showLabel;
  final MainAxisAlignment? alignment;
  
  const ThemeToggle({
    Key? key,
    this.showLabel = true,
    this.alignment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Row(
          mainAxisAlignment: alignment ?? MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabel) ...[
              Icon(
                Icons.light_mode,
                color: !themeProvider.isDarkMode 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey,
                size: 20,
              ),
              SizedBox(width: 8),
            ],
            Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
              activeColor: Theme.of(context).primaryColor,
            ),
            if (showLabel) ...[
              SizedBox(width: 8),
              Icon(
                Icons.dark_mode,
                color: themeProvider.isDarkMode 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey,
                size: 20,
              ),
            ],
          ],
        );
      },
    );
  }
}