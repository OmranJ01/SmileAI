import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../Providers/app_state.dart';
import '../../services/notification_service.dart';

class MedicationManagementScreen extends StatefulWidget {
  const MedicationManagementScreen({super.key});

  @override
  _MedicationManagementScreenState createState() => _MedicationManagementScreenState();
}

class _MedicationManagementScreenState extends State<MedicationManagementScreen> {
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('medication_reminders')
          .where('userId', isEqualTo: appState.user!.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final medications = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _medications = medications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading medications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddMedicationDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMedicationDialog(
        onMedicationAdded: _loadMedications,
      ),
    );
  }

  void _showEditMedicationDialog(Map<String, dynamic> medication) {
    showDialog(
      context: context,
      builder: (context) => EditMedicationDialog(
        medication: medication,
        onMedicationUpdated: _loadMedications,
      ),
    );
  }

  Future<void> _deleteMedication(String medicationId) async {
    try {
      // Cancel the notification
      await NotificationService.cancelMedicationReminder(medicationId);

      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('medication_reminders')
          .doc(medicationId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medication reminder deleted')),
      );

      _loadMedications();
    } catch (e) {
      print('Error deleting medication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting medication')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medication Management'),
        backgroundColor: Colors.purple[50],
        foregroundColor: Colors.purple[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddMedicationDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple[50]!, Colors.white],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _medications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _medications.length,
                    itemBuilder: (context, index) {
                      return _buildMedicationCard(_medications[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 80,
            color: Colors.purple[300],
          ),
          SizedBox(height: 16),
          Text(
            'No medication reminders yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first medication reminder to get started',
            style: TextStyle(
              fontSize: 16,
              color: Colors.purple[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddMedicationDialog,
            icon: Icon(Icons.add),
            label: Text('Add Medication'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[700],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> medication) {
    final medicationName = medication['medication'] ?? 'Unknown';
    final hour = medication['hour'] ?? 0;
    final minute = medication['minute'] ?? 0;
    final daysOfWeek = List<bool>.from(medication['daysOfWeek'] ?? []);
    final isActive = medication['active'] ?? false;
    final medicationId = medication['id'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive 
                ? [Colors.purple[100]!, Colors.purple[50]!]
                : [Colors.grey[200]!, Colors.grey[100]!],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple[700],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.medication,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicationName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[800],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.purple[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditMedicationDialog(medication);
                          } else if (value == 'delete') {
                            _showDeleteConfirmationDialog(medicationId, medicationName);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Schedule:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (int i = 0; i < 7; i++)
                    _buildDayChip(
                      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                      i < daysOfWeek.length ? daysOfWeek[i] : false,
                    ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditMedicationDialog(medication),
                      icon: Icon(Icons.edit, size: 16),
                      label: Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => NotificationService.testAlarmInOneMinute(medicationName),
                      icon: Icon(Icons.notifications_active, size: 16),
                      label: Text('Test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(String day, bool isSelected) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isSelected ? Colors.purple[700] : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          day[0],
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(String medicationId, String medicationName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Medication'),
        content: Text('Are you sure you want to delete the reminder for "$medicationName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMedication(medicationId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class AddMedicationDialog extends StatefulWidget {
  final VoidCallback onMedicationAdded;

  const AddMedicationDialog({super.key, required this.onMedicationAdded});

  @override
  _AddMedicationDialogState createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<AddMedicationDialog> {
  final _medicationController = TextEditingController();
  int _selectedHour = 8;
  int _selectedMinute = 0;
  List<bool> _daysOfWeek = List.generate(7, (index) => false);
  bool _isLoading = false;

  @override
  void dispose() {
    _medicationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.medication, color: Colors.purple[700]),
          SizedBox(width: 8),
          Text('Add Medication Reminder'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _medicationController,
              decoration: InputDecoration(
                labelText: 'Medication Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedHour,
                    decoration: InputDecoration(
                      labelText: 'Hour',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(24, (hour) => DropdownMenuItem(
                      value: hour,
                      child: Text(hour.toString().padLeft(2, '0')),
                    )),
                    onChanged: (value) {
                      setState(() {
                        _selectedHour = value!;
                      });
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMinute,
                    decoration: InputDecoration(
                      labelText: 'Minute',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(60, (minute) => DropdownMenuItem(
                      value: minute,
                      child: Text(minute.toString().padLeft(2, '0')),
                    )),
                    onChanged: (value) {
                      setState(() {
                        _selectedMinute = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Days of the week:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i]),
                    selected: _daysOfWeek[i],
                    onSelected: (bool selected) {
                      setState(() {
                        _daysOfWeek[i] = selected;
                      });
                    },
                    selectedColor: Colors.purple[200],
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addMedicationReminder,
          child: _isLoading 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Add Reminder'),
        ),
      ],
    );
  }

  Future<void> _addMedicationReminder() async {
    if (_medicationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a medication name')),
      );
      return;
    }

    if (!_daysOfWeek.any((day) => day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.user == null) return;

      final medicationId = FirebaseFirestore.instance
          .collection('medication_reminders')
          .doc()
          .id;

      // Schedule the notification first - this will trigger calendar updates
      await NotificationService.scheduleMedicationReminder(
        medicationId: medicationId,
        medicationName: _medicationController.text,
        hour: _selectedHour,
        minute: _selectedMinute,
        daysOfWeek: _daysOfWeek,
        userId: appState.user!.uid,
      );

      Navigator.pop(context);
      widget.onMedicationAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medication reminder added successfully!')),
      );
    } catch (e) {
      print('Error adding medication reminder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding medication reminder')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class EditMedicationDialog extends StatefulWidget {
  final Map<String, dynamic> medication;
  final VoidCallback onMedicationUpdated;

  const EditMedicationDialog({
    super.key,
    required this.medication,
    required this.onMedicationUpdated,
  });

  @override
  _EditMedicationDialogState createState() => _EditMedicationDialogState();
}

class _EditMedicationDialogState extends State<EditMedicationDialog> {
  late TextEditingController _medicationController;
  late int _selectedHour;
  late int _selectedMinute;
  late List<bool> _daysOfWeek;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _medicationController = TextEditingController(text: widget.medication['medication'] ?? '');
    _selectedHour = widget.medication['hour'] ?? 8;
    _selectedMinute = widget.medication['minute'] ?? 0;
    _daysOfWeek = List<bool>.from(widget.medication['daysOfWeek'] ?? List.generate(7, (index) => false));
  }

  @override
  void dispose() {
    _medicationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.blue[700]),
          SizedBox(width: 8),
          Text('Edit Medication Reminder'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _medicationController,
              decoration: InputDecoration(
                labelText: 'Medication Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedHour,
                    decoration: InputDecoration(
                      labelText: 'Hour',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(24, (hour) => DropdownMenuItem(
                      value: hour,
                      child: Text(hour.toString().padLeft(2, '0')),
                    )),
                    onChanged: (value) {
                      setState(() {
                        _selectedHour = value!;
                      });
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMinute,
                    decoration: InputDecoration(
                      labelText: 'Minute',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(60, (minute) => DropdownMenuItem(
                      value: minute,
                      child: Text(minute.toString().padLeft(2, '0')),
                    )),
                    onChanged: (value) {
                      setState(() {
                        _selectedMinute = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Days of the week:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i]),
                    selected: _daysOfWeek[i],
                    onSelected: (bool selected) {
                      setState(() {
                        _daysOfWeek[i] = selected;
                      });
                    },
                    selectedColor: Colors.blue[200],
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateMedicationReminder,
          child: _isLoading 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Update'),
        ),
      ],
    );
  }

  Future<void> _updateMedicationReminder() async {
    if (_medicationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a medication name')),
      );
      return;
    }

    if (!_daysOfWeek.any((day) => day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final medicationId = widget.medication['id'];

      // Cancel old notifications
      await NotificationService.cancelMedicationReminder(medicationId);

      // Schedule new notifications - this will trigger calendar updates
      await NotificationService.scheduleMedicationReminder(
        medicationId: medicationId,
        medicationName: _medicationController.text,
        hour: _selectedHour,
        minute: _selectedMinute,
        daysOfWeek: _daysOfWeek,
        userId: appState.user!.uid,
      );

      Navigator.pop(context);
      widget.onMedicationUpdated();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medication reminder updated successfully!')),
      );
    } catch (e) {
      print('Error updating medication reminder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating medication reminder')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}