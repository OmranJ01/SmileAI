// not used .... moved to admin_dashboard_screen.dart
//TODO::
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
class AddArticleScreen extends StatefulWidget {
  const AddArticleScreen({super.key});

  @override
  _AddArticleScreenState createState() => _AddArticleScreenState();
}

class _AddArticleScreenState extends State<AddArticleScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'Gingival Disease';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Article'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              value: _selectedCategory,
              items: [
                DropdownMenuItem(value: 'Gingival Disease', child: Text('Gingival Disease')),
                DropdownMenuItem(value: 'Oral Hygiene', child: Text('Oral Hygiene')),
                DropdownMenuItem(value: 'Dental Care', child: Text('Dental Care')),
                DropdownMenuItem(value: 'Preventive Care', child: Text('Preventive Care')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }
                
                await appState.addArticle(
                  _titleController.text,
                  _contentController.text,
                  _selectedCategory,
                );
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Article added successfully')),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Add Article'),
            ),
          ],
        ),
      ),
    );
  }
}
