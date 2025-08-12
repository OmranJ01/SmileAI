import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/articles.dart';
import '../../Providers/app_state.dart';
import '../../services/notification_service.dart';

class AddExamScreen extends StatefulWidget {
  final Article article;
  const AddExamScreen({super.key, required this.article});

  @override
  State<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends State<AddExamScreen> {
  final List<Map<String, dynamic>> _questions = [];
  bool _isSaving = false;

  void _addQuestion() {
    setState(() {
      _questions.add({
        'type': 'multiple',
        'question': '',
        'options': ['', '', '', ''],
        'answer': 0,
        'points': 1,
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _saveExam() async {
    // Validate that all questions are filled
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q['question'].toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter question ${i + 1}')),
        );
        return;
      }
      
      // Check if all options are filled
      for (int j = 0; j < 4; j++) {
        if (q['options'][j].toString().trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please fill all options for question ${i + 1}')),
          );
          return;
        }
      }
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add at least one question!')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final userId = appState.user?.uid ?? '';
      final doctorName = appState.userData?.name ?? 'Your Doctor';
      
      // Create exam with proper timestamp
      final examRef = await FirebaseFirestore.instance.collection('exams').add({
        'articleId': widget.article.id,
        'articleTitle': widget.article.title,
        'createdBy': userId,
        'createdByName': doctorName,
        'createdAt': FieldValue.serverTimestamp(),
        'questionCount': _questions.length,
      });

      // Add questions
      final batch = FirebaseFirestore.instance.batch();
      for (final q in _questions) {
        final questionRef = examRef.collection('questions').doc();
        batch.set(questionRef, {
          'type': q['type'],
          'question': q['question'],
          'points': q['points'],
          'options': q['options'],
          'answer': q['answer'],
        });
      }
      await batch.commit();

      

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exam saved!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
      
    } catch (e) {
      print('Error saving exam: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save exam: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Exam'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.article, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Article: ${widget.article.title}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                ..._questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final q = entry.value;
                  
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Question ${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeQuestion(index),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Question',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) => q['question'] = val,
                            maxLines: 2,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Options:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 8),
                          ...List.generate(4, (i) => Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Option ${i + 1}',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.radio_button_unchecked,
                                  color: q['answer'] == i ? Colors.green : Colors.grey,
                                ),
                              ),
                              onChanged: (val) => q['options'][i] = val,
                            ),
                          )),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: q['answer'],
                                  decoration: InputDecoration(
                                    labelText: 'Correct Answer',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: List.generate(4, (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text('Option ${i + 1}'),
                                  )),
                                  onChanged: (val) => setState(() => q['answer'] = val ?? 0),
                                ),
                              ),
                              SizedBox(width: 16),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Points',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: q['points'].toString()),
                                  onChanged: (val) {
                                    final parsed = int.tryParse(val);
                                    if (parsed != null && parsed > 0) {
                                      q['points'] = parsed;
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Add Question'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _addQuestion,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              child: _isSaving 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Saving...', style: TextStyle(fontSize: 16)),
                      ],
                    )
                  : Text(
                      'Save Exam (${_questions.length} Questions)',
                      style: TextStyle(fontSize: 16),
                    ),
              onPressed: _isSaving ? null : _saveExam,
            ),
          ),
        ],
      ),
    );
  }
}

class SolveExamScreen extends StatefulWidget {
  final Article article;
  final String examId;
  final VoidCallback? onSubmitted;
  
  const SolveExamScreen({
    super.key,
    required this.article,
    required this.examId,
    this.onSubmitted,
  });

  @override
  State<SolveExamScreen> createState() => _SolveExamScreenState();
}

class _SolveExamScreenState extends State<SolveExamScreen> {
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  bool _submitted = false;
  Map<int, dynamic> _answers = {};
  Map<String, dynamic>? _examData;

  @override
  void initState() {
    super.initState();
    _fetchQuestionsAndSubmission();
  }

  Future<void> _fetchQuestionsAndSubmission() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final userId = appState.user?.uid ?? '';

      // Fetch exam data
      final examDoc = await FirebaseFirestore.instance
          .collection('exams')
          .doc(widget.examId)
          .get();
      
      if (examDoc.exists) {
        _examData = examDoc.data();
      }

      // Fetch questions
      final questionsSnap = await FirebaseFirestore.instance
          .collection('exams')
          .doc(widget.examId)
          .collection('questions')
          .get();
      
      final questions = questionsSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Fetch submission
      final submissionDoc = await FirebaseFirestore.instance
          .collection('exams')
          .doc(widget.examId)
          .collection('submissions')
          .doc(userId)
          .get();

      Map<int, dynamic> submittedAnswers = {};
      bool submitted = false;
      
      if (submissionDoc.exists) {
        submitted = true;
        final data = submissionDoc.data()!;
        final answersMap = data['answers'] as Map<String, dynamic>;
        submittedAnswers = answersMap.map((k, v) => MapEntry(int.parse(k), v));
      }

      if (mounted) {
        setState(() {
          _questions = questions;
          _submitted = submitted;
          _answers = submittedAnswers;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error fetching exam data: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading exam: $e')),
        );
      }
    }
  }

  Future<void> _submitAnswers() async {
    // Check if all questions are answered
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please answer all questions before submitting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    final userId = appState.user?.uid ?? '';
    final userName = appState.userData?.name ?? '';

    // Check answers
    bool allCorrect = true;
    int totalPoints = 0;

    for (var entry in _questions.asMap().entries) {
      final idx = entry.key;
      final q = entry.value;
      final correctAnswer = q['answer'];
      final userAnswer = _answers[idx];
      
      if (userAnswer == correctAnswer) {
        totalPoints += (q['points'] as int? ?? 1);
      } else {
        allCorrect = false;
      }
    }

    try {
      // Save submission
      await FirebaseFirestore.instance
          .collection('exams')
          .doc(widget.examId)
          .collection('submissions')
          .doc(userId)
          .set({
        'answers': _answers.map((key, value) => MapEntry(key.toString(), value)),
        'submittedAt': FieldValue.serverTimestamp(),
        'allCorrect': allCorrect,
        'points': totalPoints,
        'userId': userId,
        'userName': userName,
      });
       final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final currentPoints = (snapshot.data()?['points'] ?? 0) as int;
      transaction.update(userRef, {'points': currentPoints + totalPoints});
    });

      setState(() {
        _submitted = true;
      });
      
      if (widget.onSubmitted != null) {
        widget.onSubmitted!();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allCorrect 
                ? 'Perfect! You got all answers correct! Points: $totalPoints' 
                : 'Submitted! Points: $totalPoints'
          ),
          backgroundColor: allCorrect ? Colors.green : Colors.blue,
        ),
      );
    } catch (e) {
      print('Error submitting answers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting answers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading Exam...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Exam')),
        body: Center(
          child: Text('No questions found for this exam'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam - ${widget.article.title}'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          if (_examData != null)
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Created by: ${_examData!['createdByName'] ?? 'Unknown'}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Questions: ${_questions.length}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (_submitted)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'SUBMITTED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                ..._questions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final q = entry.value;
                  final userAnswer = _answers[idx];
                  final correctAnswer = q['answer'];
                  final isCorrect = userAnswer == correctAnswer;
                  
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    child: Container(
                      decoration: _submitted && userAnswer != null
                          ? BoxDecoration(
                              border: Border.all(
                                color: isCorrect ? Colors.green : Colors.red,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            )
                          : null,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Question ${idx + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Points: ${q['points'] ?? 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (_submitted && userAnswer != null) ...[
                                      SizedBox(width: 8),
                                      Icon(
                                        isCorrect ? Icons.check_circle : Icons.cancel,
                                        color: isCorrect ? Colors.green : Colors.red,
                                        size: 20,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              q['question'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 12),
                            ...List.generate((q['options'] as List).length, (i) {
                              final isSelected = userAnswer == i;
                              final isCorrectOption = i == correctAnswer;
                              
                              Color? tileColor;
                              if (_submitted && isSelected) {
                                tileColor = isCorrect 
                                    ? Colors.green.shade50 
                                    : Colors.red.shade50;
                              }
                              if (_submitted && isCorrectOption && !isCorrect) {
                                tileColor = Colors.green.shade50;
                              }
                              
                              return Container(
                                margin: EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: tileColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _submitted && (isSelected || isCorrectOption)
                                      ? Border.all(
                                          color: isCorrectOption 
                                              ? Colors.green 
                                              : Colors.red,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: RadioListTile<int>(
                                  value: i,
                                  groupValue: userAnswer,
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(q['options'][i])),
                                      if (_submitted && isCorrectOption)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'CORRECT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  onChanged: _submitted 
                                      ? null 
                                      : (val) => setState(() => _answers[idx] = val),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (!_submitted)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Answered: ${_answers.length} / ${_questions.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _answers.length < _questions.length 
                          ? Colors.orange 
                          : Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      minimumSize: Size(double.infinity, 0),
                    ),
                    child: Text(
                      'Submit Answers',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    onPressed: _submitAnswers,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}