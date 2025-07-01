import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Recorder Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VoiceRecorderPage(),
    );
  }
}

class VoiceRecorderPage extends StatefulWidget {
  const VoiceRecorderPage({super.key});

  @override
  State<VoiceRecorderPage> createState() => _VoiceRecorderPageState();
}

class _VoiceRecorderPageState extends State<VoiceRecorderPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  
  List<Recording> _recordings = [];
  Recording? _currentRecording;
  
  @override
  void initState() {
    super.initState();
    _initRecorder();
    _initPlayer();
    _loadRecordings();
  }
  
  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }
  
  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    
    await _recorder.openRecorder();
    _isRecorderInitialized = true;
  }
  
  Future<void> _initPlayer() async {
    await _player.openPlayer();
    _isPlayerInitialized = true;
  }
  
  Future<void> _loadRecordings() async {
    final appDir = Directory('/storage/emulated/0/Download/recordings');
    if (await appDir.exists()) {
      final files = appDir.listSync();
      setState(() {
        _recordings = files
            .where((file) => file.path.endsWith('.aac'))
            .map((file) => Recording(
                  path: file.path,
                  name: file.path.split('/').last,
                  duration: Duration.zero, // We'll get this when playing
                ))
            .toList();
      });
    }
  }
  
  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;
    
    final appDir = Directory('/storage/emulated/0/Download/recordings');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    
    final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.aac';
    final filePath = '${appDir.path}/$fileName';
    
    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.aacADTS,
    );
    
    setState(() {
      _isRecording = true;
    });
  }
  
  Future<void> _stopRecording() async {
    if (!_isRecorderInitialized) return;
    
    final path = await _recorder.stopRecorder();
    if (path != null) {
      final recording = Recording(
        path: path,
        name: path.split('/').last,
        duration: Duration.zero,
      );
      
      setState(() {
        _recordings.add(recording);
        _isRecording = false;
      });
    }
  }
  
  Future<void> _playRecording(Recording recording) async {
    if (!_isPlayerInitialized) return;
    
    if (_isPlaying) {
      await _player.stopPlayer();
      setState(() {
        _isPlaying = false;
        _currentRecording = null;
      });
      return;
    }
    
    await _player.startPlayer(
      fromURI: recording.path,
      codec: Codec.aacADTS,
      whenFinished: () {
        setState(() {
          _isPlaying = false;
          _currentRecording = null;
        });
      },
    );
    
    setState(() {
      _isPlaying = true;
      _currentRecording = recording;
    });
  }
  
  Future<void> _deleteRecording(Recording recording) async {
    final file = File(recording.path);
    if (await file.exists()) {
      await file.delete();
    }
    
    setState(() {
      _recordings.remove(recording);
      if (_currentRecording == recording) {
        _currentRecording = null;
        _isPlaying = false;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Recorder'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Recording Controls
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Recording Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: _isRecording ? Colors.red : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isRecording ? Icons.fiber_manual_record : Icons.mic,
                        color: _isRecording ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRecording ? 'Recording...' : 'Ready to Record',
                        style: TextStyle(
                          color: _isRecording ? Colors.red : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Record Button
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red : Colors.blue,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.red : Colors.blue).withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Recordings List
          Expanded(
            child: _recordings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.audiotrack,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No recordings yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the microphone to start recording',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _recordings.length,
                    itemBuilder: (context, index) {
                      final recording = _recordings[index];
                      final isCurrentPlaying = _currentRecording == recording && _isPlaying;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 2,
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isCurrentPlaying ? Colors.blue : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Icon(
                              isCurrentPlaying ? Icons.pause : Icons.play_arrow,
                              color: isCurrentPlaying ? Colors.white : Colors.blue,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            recording.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Tap to ${isCurrentPlaying ? 'stop' : 'play'}',
                            style: TextStyle(
                              color: isCurrentPlaying ? Colors.blue : Colors.grey[600],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteRecording(recording),
                          ),
                          onTap: () => _playRecording(recording),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class Recording {
  final String path;
  final String name;
  final Duration duration;
  
  Recording({
    required this.path,
    required this.name,
    required this.duration,
  });
}
