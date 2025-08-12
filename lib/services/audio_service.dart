import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static AudioPlayer? _player;
  static bool _isEnabled = true;
  
  // Audio file mappings based on the brushing steps
  static const Map<String, String> _audioFiles = {
    'Upper Right Side': 'audio/upper right side.mp3',
    'Upper Front Side': 'audio/upper fron side.mp3',
    'Upper Left Side': 'audio/upper left - side.mp3',
    'Lower Left Side': 'audio/lower left - side.mp3',
    'Lower Front Side': 'audio/lower front side.mp3',
    'Lower Right Side': 'audio/lower right side.mp3',
    'Upper Teeth - Inside': 'audio/upper teeth inside.mp3',
    'Lower Teeth - Inside': 'audio/lower teeth inside.mp3',
    'All Chewing Surfaces': 'audio/all the chewing surface.mp3',
    'Tongue': 'audio/tongue.mp3',
  };
  
  static AudioPlayer get player {
    _player ??= AudioPlayer();
    return _player!;
  }
  
  // Play audio for a specific brushing step
  static Future<void> playStepAudio(String stepName) async {
    if (!_isEnabled) return;
    
    final audioFile = _audioFiles[stepName];
    if (audioFile == null) {
      print('No audio file found for step: $stepName');
      return;
    }
    
    print('Attempting to play audio file: $audioFile');
    
    try {
      await player.stop(); // Stop any currently playing audio
      await player.play(AssetSource(audioFile));
      print('Successfully started playing audio for: $stepName');
    } catch (e) {
      print('Error playing audio for step "$stepName" with file "$audioFile": $e');
    }
  }
  
  // Stop current audio
  static Future<void> stopAudio() async {
    try {
      await player.stop();
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }
  
  // Pause current audio
  static Future<void> pauseAudio() async {
    try {
      await player.pause();
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }
  
  // Resume current audio
  static Future<void> resumeAudio() async {
    try {
      await player.resume();
    } catch (e) {
      print('Error resuming audio: $e');
    }
  }
  
  // Set volume (0.0 to 1.0)
  static Future<void> setVolume(double volume) async {
    try {
      await player.setVolume(volume);
    } catch (e) {
      print('Error setting volume: $e');
    }
  }
  
  // Enable/disable audio
  static void setAudioEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stopAudio();
    }
  }
  
  static bool get isAudioEnabled => _isEnabled;
  
  // Get available audio steps
  static List<String> get availableSteps => _audioFiles.keys.toList();
  
  // Check if audio file exists for step
  static bool hasAudioForStep(String stepName) {
    return _audioFiles.containsKey(stepName);
  }
  
  // Dispose the audio player
  static Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
} 