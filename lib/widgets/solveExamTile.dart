import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/articles.dart';
import '../../Providers/app_state.dart';
import '../../models/exam.dart';
import 'package:provider/provider.dart';
import '../../services/notification_service.dart';

class SolveExamTile extends StatefulWidget {
  final String examId;
  final Article article;
  final int index;

  const SolveExamTile({
    super.key,
    required this.examId,
    required this.article,
    required this.index,
  });

  @override
  State<SolveExamTile> createState() => _SolveExamTileState();
}

class _SolveExamTileState extends State<SolveExamTile> {
  bool _submitted = false;
  bool _loading = true;
  bool _allCorrect = false;
  bool _requestingResubmit = false;

  // Flag to indicate we're resubmitting (skip checking previous submission)
  bool _isResubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkSubmission();
  }

  Future<void> _checkSubmission() async {
    // If resubmitting, skip checking and reset state
    if (_isResubmitting) {
      setState(() {
        _submitted = false;
        _allCorrect = false;
        _loading = false;
        _isResubmitting = false; // reset after skipping
      });
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    final userId = appState.user?.uid ?? '';

    final submissionDoc = await FirebaseFirestore.instance
        .collection('exams')
        .doc(widget.examId)
        .collection('submissions')
        .doc(userId)
        .get();

    bool allCorrect = false;

    if (submissionDoc.exists) {
      final data = submissionDoc.data();
      allCorrect = data?['allCorrect'] == true;
    }

    if (!mounted) return;
    setState(() {
      _submitted = submissionDoc.exists;
      _allCorrect = allCorrect;
      _loading = false;
    });
  }

  Future<bool> _canResubmit() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final userId = appState.user?.uid ?? '';

    final query = await FirebaseFirestore.instance
        .collection('resubmit_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .where('examId', isEqualTo: widget.examId)
        .get();
  
    return query.docs.isNotEmpty;
  }

  Future<void> _requestResubmit(AppState appState) async {
    setState(() => _requestingResubmit = true);

    final userId = appState.user?.uid ?? '';
    final userName = appState.userData?.name ?? '';
    final userEmail = appState.userData?.email ?? '';
    final doctorId = appState.userData?.doctorId ?? '';

    await FirebaseFirestore.instance.collection('resubmit_requests').add({
      'examId': widget.examId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'doctorId': doctorId,
      'articleId': widget.article.id,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    // Send notification to the doctor
    if (doctorId.isNotEmpty) {
      await NotificationService.sendNotification(
        userId: doctorId,
        title: 'New Resubmit Request',
        message: '$userName has requested to resubmit exam ${widget.index+1}.',
        type: 'resubmit_request',
        data: {
          'examId': widget.examId,
          'menteeId': userId,
          'menteeName': userName,
        },
      );
    }

    if (!mounted) return;
    setState(() => _requestingResubmit = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Resubmit request sent to your doctor.')),
    );
  }

  // New method: handle resubmitting by deleting old submission and navigating fresh
  Future<void> _handleResubmit(AppState appState) async {
    setState(() {
      _isResubmitting = true;
      _loading = true;
    });

    final userId = appState.user?.uid ?? '';

    // Delete previous submission if exists
    await FirebaseFirestore.instance
        .collection('exams')
        .doc(widget.examId)
        .collection('submissions')
        .doc(userId)
        .delete();

    final query = await FirebaseFirestore.instance
        .collection('resubmit_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .where('examId', isEqualTo: widget.examId)
        .get();

    for (var doc in query.docs) {
      // Delete the resubmit request document
      await doc.reference.delete();
    }

    setState(() {
      _submitted = false;
      _allCorrect = false;
      _loading = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SolveExamScreen(
          article: widget.article,
          examId: widget.examId,
          onSubmitted: _checkSubmission,
        ),
      ),
    );
  }

  Widget _buildTrailingButtons(AppState appState) {
    // If NOT submitted: show only Solve
    if (!_submitted) {
      return ElevatedButton(
        child: Text('Solve'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SolveExamScreen(
                article: widget.article,
                examId: widget.examId,
                onSubmitted: _checkSubmission,
              ),
            ),
          );
        },
      );
    }

    // If submitted: show View + Resubmit options
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          child: Text('View'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SolveExamScreen(
                  article: widget.article,
                  examId: widget.examId,
                  onSubmitted: _checkSubmission,
                ),
              ),
            );
          },
        ),
        SizedBox(width: 8),
        FutureBuilder<bool>(
          future: _canResubmit(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return SizedBox.shrink();
            if (_allCorrect) {
              return SizedBox.shrink();
            }
            if (snapshot.data == true) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: Text('Resubmit'),
                onPressed: () {
                  _handleResubmit(appState);
                },
              );
            } else {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: _requestingResubmit
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Request Resubmit'),
                onPressed: _requestingResubmit
                    ? null
                    : () => _requestResubmit(appState),
              );
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }

    return Card(
      // 🟢 GREEN COLOR FOR SOLVED EXAMS
      color: _submitted && _allCorrect ? Colors.green.shade50 : null,
      child: Container(
        decoration: _submitted && _allCorrect 
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green, width: 2),
              )
            : null,
        child: ListTile(
          title: Row(
            children: [
              Text('Exam ${widget.index + 1}'),
              // 🟢 GREEN CHECK MARK FOR SOLVED EXAMS
              if (_submitted && _allCorrect) ...[
                SizedBox(width: 8),
                Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ],
          ),
          subtitle: _submitted
              ? Text(
                  _allCorrect ? 'All answers correct ✅' : 'Has wrong answers ❌',
                  style: TextStyle(
                    color: _allCorrect ? Colors.green : Colors.red,
                  ),
                )
              : Text('Not submitted'),
          trailing: _buildTrailingButtons(appState),
        ),
      ),
    );
  }
}