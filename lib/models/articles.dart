import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../Providers/app_state.dart';
import '../../models/exam.dart';
import '../widgets/solveExamTile.dart';
class Article {
  final String id;
  final String title;
  final String content;
  final String category;
  final Timestamp createdAt;
  final String createdBy;

  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.createdBy,
  });

  factory Article.fromMap(Map<String, dynamic> map, {String? id}) {
    return Article(
      id: id ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }
}



class ArticleListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ArticleListItem({super.key, 
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black,
              ),
              child: Text('more'),
            ),
          ],
        ),
        SizedBox(height: 16),
      ],
    );
  }
}

// Common Screens



class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  
  const ArticleDetailScreen({super.key, required this.article});
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
final isDoctor = appState.userData?.role == 'doctor';
final isMenteeOrMentor = appState.userData?.role == 'mentee' || appState.userData?.role == 'mentor';

    return Scaffold(
      appBar: AppBar(
        title: Text('Article'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Category: ${article.category}',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 16),
            Text(article.content),
            SizedBox(height: 32),
        if (isDoctor)
          Center(
            child: ElevatedButton.icon(
              icon: Icon(Icons.quiz),
              label: Text('Add Exam'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExamScreen(article: article),
                  ),
                );
              },
            ),
          )else if (isMenteeOrMentor)
  FutureBuilder<QuerySnapshot>(
    future: FirebaseFirestore.instance
        .collection('exams')
        .where('articleId', isEqualTo: article.id)
        .get(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator();
      final exams = snapshot.data!.docs;
      if (exams.isEmpty) return Text('No exams available for this article.');
      return Column(
children: exams.asMap().entries.map((entry) {
  final index = entry.key;
  final examDoc = entry.value;
  final examId = examDoc.id;
          return SolveExamTile(
            examId: examId,
            article: article,
            index: index ,
          );
        }).toList(),
      );
    },
  ),
          ],
        ),
      ),
    );
  }
}

