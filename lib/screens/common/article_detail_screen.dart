import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/articles.dart';
import '../../Providers/app_state.dart';
import '../../widgets/exam_list_widget.dart'; // Import for SolveExamTile
import '../../models/exam.dart'; // Import for AddExamScreen

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  String _searchCategory = '';  

  Stream<List<Article>> getArticlesStream() {
    return FirebaseFirestore.instance
        .collection('articles')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Article.fromMap(doc.data(), id: doc.id);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Articles')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search by category',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchCategory = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Article>>(
              stream: getArticlesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Something went wrong.'));
                }

                final articles = snapshot.data ?? [];

                // Filter by category
                final filtered = _searchCategory.isEmpty
                    ? articles
                    : articles.where((a) =>
                        a.category.toLowerCase().contains(_searchCategory)).toList();

                if (filtered.isEmpty) {
                  return Center(child: Text('No articles found for this category.'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final article = filtered[index];

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(article.title),
                        subtitle: Text(article.category),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArticleDetailScreen(article: article),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  
  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDoctor = appState.userData?.role == 'doctor';
    final userId = appState.user?.uid ?? '';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(article.title),
        actions: [
          if (isDoctor)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExamScreen(article: article),
                  ),
                );
              },
              tooltip: 'Add Exam',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Article content
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category: ${article.category}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    article.content,
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            // Exams Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exams',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isDoctor)
                  ElevatedButton.icon(
                    icon: Icon(Icons.add, size: 20),
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
              ],
            ),
            
            SizedBox(height: 16),
            
            // Exams List with proper query
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('exams')
                  .where('articleId', isEqualTo: article.id)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print('Error loading exams: ${snapshot.error}');
                  return Center(
                    child: Text('Error loading exams'),
                  );
                }

                final examDocs = snapshot.data?.docs ?? [];
                
                if (examDocs.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No exams available yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // For mentees, filter exams by their doctor
                List<QueryDocumentSnapshot> filteredExams = examDocs;
                if (!isDoctor) {
                  final menteesDoctorId = appState.userData?.doctorId ?? '';
                  filteredExams = examDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['createdBy'] == menteesDoctorId;
                  }).toList();
                }

                if (filteredExams.isEmpty && !isDoctor) {
                  return Container(
                    padding: EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No exams from your doctor yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: filteredExams.length,
                  itemBuilder: (context, index) {
                    final examDoc = filteredExams[index];
                    final examData = examDoc.data() as Map<String, dynamic>;
                    final examId = examDoc.id;
                    
                    // For doctors: show exam info
                    if (isDoctor) {
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('Exam ${index + 1}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Questions: ${examData['questionCount'] ?? 0}'),
                              Text('Created by: ${examData['createdByName'] ?? 'Unknown'}'),
                            ],
                          ),
                          trailing: Icon(Icons.visibility),
                          onTap: () {
                            // Navigate to view exam details for doctor
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ViewExamDetailsScreen(
                                  examId: examId,
                                  article: article,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                    
                    // For mentees: show solve exam tile
                    return SolveExamTile(
                      examId: examId,
                      article: article,
                      index: index,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Add this screen for doctors to view exam details
class ViewExamDetailsScreen extends StatelessWidget {
  final String examId;
  final Article article;
  
  const ViewExamDetailsScreen({
    super.key,
    required this.examId,
    required this.article,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('exams')
            .doc(examId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          final examData = snapshot.data!.data() as Map<String, dynamic>;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exam Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text('Article: ${article.title}'),
                        Text('Questions: ${examData['questionCount'] ?? 0}'),
                        Text('Created by: ${examData['createdByName'] ?? 'Unknown'}'),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Submissions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('exams')
                      .doc(examId)
                      .collection('submissions')
                      .snapshots(),
                  builder: (context, subSnapshot) {
                    if (!subSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    
                    final submissions = subSnapshot.data!.docs;
                    
                    if (submissions.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No submissions yet'),
                          ),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: submissions.length,
                      itemBuilder: (context, index) {
                        final submission = submissions[index].data() as Map<String, dynamic>;
                        final allCorrect = submission['allCorrect'] ?? false;
                        
                        return Card(
                          child: ListTile(
                            title: Text(submission['userName'] ?? 'Unknown Student'),
                            subtitle: Text(
                              allCorrect
                                  ? 'All answers correct ✅'
                                  : 'Has wrong answers ❌',
                              style: TextStyle(
                                color: allCorrect ? Colors.green : Colors.red,
                              ),
                            ),
                            trailing: Text(
                              'Points: ${submission['points'] ?? 0}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}