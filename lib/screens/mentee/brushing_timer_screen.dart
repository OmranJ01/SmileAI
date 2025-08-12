import 'package:flutter/material.dart';
import 'dart:async';
import '../../widgets/brushing_visual_guide.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Providers/app_state.dart';
import '../../services/audio_service.dart';

class BrushingTimerScreen extends StatefulWidget {
  const BrushingTimerScreen({super.key});

  @override
  _BrushingTimerScreenState createState() => _BrushingTimerScreenState();
}

class _BrushingTimerScreenState extends State<BrushingTimerScreen> {
  int _minutes = 2;
  int _seconds = 0;
  bool _isRunning = false;
  int _currentStep = 0;
  late Timer _timer;
  bool _pointsAwarded = false; // Track if points were already awarded for this session
  bool _audioEnabled = true; // Track if audio is enabled
  double _volume = 0.7; // Audio volume
  
  final List<Map<String, dynamic>> _brushingSteps = [
    // Upper teeth - Side surfaces (30 seconds total)
    {
      'area': 'Upper Right Side',
      'instruction': 'Start at the gum line with 45° angle. Use gentle circular motions from back to front.',
      'duration': 10,
      'icon': Icons.north_east,
      'color': Colors.blue,
    },
    {
      'area': 'Upper Front Side', 
      'instruction': 'Continue circular motions on front teeth. Don\'t forget the canines!',
      'duration': 10,
      'icon': Icons.north,
      'color': Colors.blue,
    },
    {
      'area': 'Upper Left Side',
      'instruction': 'Finish side of upper teeth with same gentle circular motions.',
      'duration': 10,
      'icon': Icons.north_west,
      'color': Colors.blue,
    },
    
    // Lower teeth - Side surfaces (30 seconds total)
    {
      'area': 'Lower Left Side',
      'instruction': 'Move to lower teeth. Keep bristles at 45° angle to gum line.',
      'duration': 10,
      'icon': Icons.south_west,
      'color': Colors.green,
    },
    {
      'area': 'Lower Front Side',
      'instruction': 'Gentle circles on lower front teeth. Pay attention to gum line.',
      'duration': 10,
      'icon': Icons.south,
      'color': Colors.green,
    },
    {
      'area': 'Lower Right Side',
      'instruction': 'Complete side surfaces with careful circular motions.',
      'duration': 10,
      'icon': Icons.south_east,
      'color': Colors.green,
    },
    
    // Inside surfaces - Upper (20 seconds)
    {
      'area': 'Upper Teeth - Inside',
      'instruction': 'Tilt brush vertically for front teeth, angle for back teeth. Sweep from gum to tooth.',
      'duration': 20,
      'icon': Icons.flip_to_back,
      'color': Colors.purple,
    },
    
    // Inside surfaces - Lower (20 seconds)
    {
      'area': 'Lower Teeth - Inside',
      'instruction': 'Same technique - vertical for front, angled for back. Don\'t rush!',
      'duration': 20,
      'icon': Icons.flip_to_front,
      'color': Colors.orange,
    },
    
    // Chewing surfaces (15 seconds)
    {
      'area': 'All Chewing Surfaces',
      'instruction': 'Use back-and-forth motions on flat surfaces where you chew.',
      'duration': 15,
      'icon': Icons.grid_on,
      'color': Colors.red,
    },
    
    // Tongue (5 seconds)
    {
      'area': 'Tongue',
      'instruction': 'Gently brush your tongue from back to front to remove bacteria.',
      'duration': 5,
      'icon': Icons.cleaning_services,
      'color': Colors.teal,
    },
  ];
  
  int _currentStepTimeRemaining = 0;
  
  @override
  void initState() {
    super.initState();
    _currentStepTimeRemaining = _brushingSteps[0]['duration'];
    // Set initial audio settings
    AudioService.setAudioEnabled(_audioEnabled);
    AudioService.setVolume(_volume);
  }
  
  @override
  void dispose() {
    if (_isRunning) {
      _timer.cancel();
    }
    // Stop any playing audio
    AudioService.stopAudio();
    super.dispose();
  }
  
  void _startTimer() {
    setState(() {
      _isRunning = true;
      _pointsAwarded = false; // Reset points awarded flag when starting new session
    });
    
    // Play audio for the first step
    if (_audioEnabled && _brushingSteps.isNotEmpty) {
      AudioService.playStepAudio(_brushingSteps[_currentStep]['area']);
    }
    
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        // Decrement step time
        if (_currentStepTimeRemaining > 0) {
          _currentStepTimeRemaining--;
        }
        
        // Move to next step if current step time is done
        if (_currentStepTimeRemaining == 0 && _currentStep < _brushingSteps.length - 1) {
          _currentStep++;
          _currentStepTimeRemaining = _brushingSteps[_currentStep]['duration'];
          
          // Play audio for the new step
          if (_audioEnabled) {
            AudioService.playStepAudio(_brushingSteps[_currentStep]['area']);
          }
          
          // Vibration feedback (if available)
          // HapticFeedback.mediumImpact();
        }
        
        // Update overall timer
        if (_seconds > 0) {
          _seconds--;
        } else {
          if (_minutes > 0) {
            _minutes--;
            _seconds = 59;
          } else {
            _timer.cancel();
            _isRunning = false;
            // Timer completed, award points and show completion dialog
            _onTimerComplete();
          }
        }
      });
    });
  }
  
  Future<void> _onTimerComplete() async {
    // Award points if not already awarded for this session

    // Show completion dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Brushing Complete! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 16),
            Text('Great job! You\'ve completed your 2-minute brushing session.'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
             
            ),
            SizedBox(height: 8),
            Text('Remember to floss daily and rinse with mouthwash!',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Done'),
          ),
        ],
      ),
    );
  }
  
  void _pauseTimer() {
    if (_isRunning) {
      _timer.cancel();
      setState(() {
        _isRunning = false;
      });
      // Pause audio when timer is paused
      AudioService.pauseAudio();
    }
  }
  
  void _stopTimer() {
    if (_isRunning) {
      _timer.cancel();
    }
    setState(() {
      _isRunning = false;
      _minutes = 2;
      _seconds = 0;
      _currentStep = 0;
      _currentStepTimeRemaining = _brushingSteps[0]['duration'];
      _pointsAwarded = false;
    });
    // Stop audio when timer is stopped
    AudioService.stopAudio();
  }
  
  void _toggleAudio() {
    setState(() {
      _audioEnabled = !_audioEnabled;
    });
    AudioService.setAudioEnabled(_audioEnabled);
    
    if (!_audioEnabled) {
      AudioService.stopAudio();
    } else if (_isRunning) {
      // Play current step audio if timer is running
      AudioService.playStepAudio(_brushingSteps[_currentStep]['area']);
    }
  }
  
  void _adjustVolume(double volume) {
    setState(() {
      _volume = volume;
    });
    AudioService.setVolume(volume);
  }
  
  void _resetTimer() {
    if (_isRunning) {
      _timer.cancel();
    }
    setState(() {
      _minutes = 2;
      _seconds = 0;
      _isRunning = false;
      _currentStep = 0;
      _currentStepTimeRemaining = _brushingSteps[0]['duration'];
    });
    // Stop audio when resetting
    AudioService.stopAudio();
  }
  
  @override
  Widget build(BuildContext context) {
    final currentStepData = _brushingSteps[_currentStep];
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Brush Buddy'),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/brushing_guide.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // Gradient overlay for better text visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          
          // Content overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SizedBox(height: 20),
                  
                  // Timer display with glass morphism effect
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildGlassTimeBox('$_minutes', 'MIN'),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            _buildGlassTimeBox(_seconds.toString().padLeft(2, '0'), 'SEC'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Current area display with glass effect
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: currentStepData['color'].withOpacity(0.8),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: currentStepData['color'].withOpacity(0.4),
                          blurRadius: 20,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '${currentStepData['area']} - ${_currentStepTimeRemaining}s',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Instructions with glass background
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      currentStepData['instruction'],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  Spacer(),
                  
                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGlassButton(
                        'Reset',
                        Icons.refresh,
                        _resetTimer,
                        Colors.grey,
                      ),
                      SizedBox(width: 20),
                      _buildGlassButton(
                        _isRunning ? 'Pause' : 'Start',
                        _isRunning ? Icons.pause : Icons.play_arrow,
                        _isRunning ? _pauseTimer : _startTimer,
                        _isRunning ? Colors.orange : Colors.green,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Audio controls
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Audio Guide',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            GestureDetector(
                              onTap: _toggleAudio,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _audioEnabled 
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  _audioEnabled ? Icons.volume_up : Icons.volume_off,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_audioEnabled) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.volume_down, color: Colors.white70, size: 16),
                              Expanded(
                                child: Slider(
                                  value: _volume,
                                  min: 0.0,
                                  max: 1.0,
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white.withOpacity(0.3),
                                  onChanged: _adjustVolume,
                                ),
                              ),
                              Icon(Icons.volume_up, color: Colors.white70, size: 16),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Progress indicator with glass effect
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Progress', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text('${_currentStep + 1}/${_brushingSteps.length} Areas',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (_currentStep + 1) / _brushingSteps.length,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              currentStepData['color'],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGlassTimeBox(String value, String label) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildGlassButton(String label, IconData icon, VoidCallback onPressed, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
