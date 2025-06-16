import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(SleepBreathworkApp());
}

class SleepBreathworkApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep Breathwork',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Color(0xFF0D1B2A),
        fontFamily: 'Roboto',
      ),
      home: BreathworkScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum BreathingTechnique {
  fourSevenEight,
  boxBreathing,
  triangle,
}

enum BreathingPhase {
  inhale,
  hold,
  exhale,
  holdAfterExhale,
}

class BreathingPattern {
  final String name;
  final String description;
  final List<int> phases;
  final Color primaryColor;
  final Color secondaryColor;
  final bool hasSecondHold;

  BreathingPattern({
    required this.name,
    required this.description,
    required this.phases,
    required this.primaryColor,
    required this.secondaryColor,
    this.hasSecondHold = false,
  });
}

class BreathworkScreen extends StatefulWidget {
  @override
  _BreathworkScreenState createState() => _BreathworkScreenState();
}

class _BreathworkScreenState extends State<BreathworkScreen>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _particleController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _glowAnimation;

  // Audio player
  late AudioPlayer _audioPlayer;
  bool _isAudioEnabled = true;
  bool _isAudioPlaying = false;

  Timer? _breathingTimer;
  BreathingTechnique _selectedTechnique = BreathingTechnique.fourSevenEight;
  BreathingPhase _currentPhase = BreathingPhase.inhale;
  bool _isActive = false;
  bool _isPaused = false;
  int _cycleCount = 0;
  int _phaseProgress = 0;
  int _totalPhaseTime = 0;
  int _currentPhaseIndex = 0;

  final Map<BreathingTechnique, BreathingPattern> _patterns = {
    BreathingTechnique.fourSevenEight: BreathingPattern(
      name: "4-7-8 Technique",
      description: "Promotes deep relaxation and faster sleep onset. Calms the nervous system.",
      phases: [4, 7, 8],
      primaryColor: Color(0xFF6B73FF),
      secondaryColor: Color(0xFF9B59B6),
    ),
    BreathingTechnique.boxBreathing: BreathingPattern(
      name: "Box Breathing",
      description: "Reduces stress and improves focus. Creates mental clarity before sleep.",
      phases: [4, 4, 4, 4],
      primaryColor: Color(0xFF00D4AA),
      secondaryColor: Color(0xFF0099CC),
      hasSecondHold: true,
    ),
    BreathingTechnique.triangle: BreathingPattern(
      name: "Triangle Breathing",
      description: "Simple, rhythmic pattern that soothes anxiety and prepares for rest.",
      phases: [4, 4, 4],
      primaryColor: Color(0xFFFF6B6B),
      secondaryColor: Color(0xFFFF8E53),
    ),
  };

  @override
  void initState() {
    super.initState();
    
    // Initialize audio player
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
    
    _breathingController = AnimationController(
      duration: Duration(seconds: 4),
      vsync: this,
    );
    _particleController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _breathingAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupAudioPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    
    // Listen to audio player state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        _isAudioPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _breathingController.dispose();
    _particleController.dispose();
    _breathingTimer?.cancel();
    super.dispose();
  }

  // Audio control methods
  Future<void> _startAmbientSound() async {
    if (!_isAudioEnabled) return;
    
    try {
      await _audioPlayer.play(AssetSource('audio/music.mp3'));
    } catch (e) {
      print('Error playing audio: $e');
      // Handle error gracefully - continue without audio
    }
  }

  Future<void> _pauseAmbientSound() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }

  Future<void> _resumeAmbientSound() async {
    if (!_isAudioEnabled) return;
    
    try {
      await _audioPlayer.resume();
    } catch (e) {
      print('Error resuming audio: $e');
    }
  }

  Future<void> _stopAmbientSound() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  void _toggleAudio() {
    setState(() {
      _isAudioEnabled = !_isAudioEnabled;
    });
    
    if (!_isAudioEnabled && _isAudioPlaying) {
      _pauseAmbientSound();
    } else if (_isAudioEnabled && _isActive && !_isPaused) {
      _startAmbientSound();
    }
  }

  void _startBreathing() {
    setState(() {
      _isActive = true;
      _isPaused = false;
      _cycleCount = 0;
      _phaseProgress = 0;
      _currentPhase = BreathingPhase.inhale;
      _currentPhaseIndex = 0;
    });
    
    // Start ambient sound
    _startAmbientSound();
    _nextPhase();
  }

  void _pauseBreathing() {
    setState(() {
      _isPaused = true;
    });
    _breathingTimer?.cancel();
    _breathingController.stop();
    
    // Pause ambient sound
    _pauseAmbientSound();
  }

  void _resumeBreathing() {
    setState(() {
      _isPaused = false;
    });
    
    // Resume ambient sound
    _resumeAmbientSound();
    _nextPhase();
  }

  void _stopBreathing() {
    setState(() {
      _isActive = false;
      _isPaused = false;
      _cycleCount = 0;
      _phaseProgress = 0;
      _currentPhase = BreathingPhase.inhale;
      _currentPhaseIndex = 0;
    });
    _breathingTimer?.cancel();
    _breathingController.reset();
    
    // Stop ambient sound
    _stopAmbientSound();
  }

  void _nextPhase() {
    if (!_isActive || _isPaused) return;

    final pattern = _patterns[_selectedTechnique]!;
    final phases = pattern.phases;

    int phaseDuration;
    BreathingPhase nextPhase;
    int nextPhaseIndex;

    if (_selectedTechnique == BreathingTechnique.boxBreathing) {
      phaseDuration = phases[_currentPhaseIndex];
      
      switch (_currentPhaseIndex) {
        case 0:
          nextPhase = BreathingPhase.hold;
          nextPhaseIndex = 1;
          break;
        case 1:
          nextPhase = BreathingPhase.exhale;
          nextPhaseIndex = 2;
          break;
        case 2:
          nextPhase = BreathingPhase.holdAfterExhale;
          nextPhaseIndex = 3;
          break;
        case 3:
          nextPhase = BreathingPhase.inhale;
          nextPhaseIndex = 0;
          break;
        default:
          nextPhase = BreathingPhase.inhale;
          nextPhaseIndex = 0;
      }
    } else {
      switch (_currentPhaseIndex) {
        case 0:
          phaseDuration = phases[0];
          nextPhase = BreathingPhase.hold;
          nextPhaseIndex = 1;
          break;
        case 1:
          phaseDuration = phases[1];
          nextPhase = BreathingPhase.exhale;
          nextPhaseIndex = 2;
          break;
        case 2:
          phaseDuration = phases[2];
          nextPhase = BreathingPhase.inhale;
          nextPhaseIndex = 0;
          break;
        default:
          phaseDuration = phases[0];
          nextPhase = BreathingPhase.inhale;
          nextPhaseIndex = 0;
      }
    }

    setState(() {
      _totalPhaseTime = phaseDuration;
      _phaseProgress = 0;
    });

    _breathingController.duration = Duration(seconds: phaseDuration);
    
    if (_currentPhase == BreathingPhase.inhale) {
      _breathingController.forward();
    } else if (_currentPhase == BreathingPhase.exhale) {
      _breathingController.reverse();
    } else {
      _breathingController.stop();
    }

    _breathingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _phaseProgress++;
      });

      if (_phaseProgress >= phaseDuration) {
        timer.cancel();
        setState(() {
          _currentPhase = nextPhase;
          _currentPhaseIndex = nextPhaseIndex;
          
          if (_selectedTechnique == BreathingTechnique.boxBreathing) {
            if (nextPhaseIndex == 0) _cycleCount++;
          } else {
            if (nextPhaseIndex == 0) _cycleCount++;
          }
        });
        _nextPhase();
      }
    });
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        return "Breathe In";
      case BreathingPhase.hold:
        return "Hold";
      case BreathingPhase.exhale:
        return "Breathe Out";
      case BreathingPhase.holdAfterExhale:
        return "Hold";
    }
  }

  @override
  Widget build(BuildContext context) {
    final pattern = _patterns[_selectedTechnique]!;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Color(0xFF1B263B),
              Color(0xFF0D1B2A),
              Color(0xFF000000),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: StarFieldPainter(_particleController.value),
                  size: Size.infinite,
                );
              },
            ),
            
            SafeArea(
              child: SingleChildScrollView( // FIX 1: Add scrollable wrapper
                child: ConstrainedBox( // FIX 2: Ensure minimum height
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 
                               MediaQuery.of(context).padding.top - 
                               MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight( // FIX 3: Allow content to determine height
                    child: Column(
                      children: [
                        // Header with audio toggle
                        Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Sleep Breathwork",
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w300,
                                            color: Colors.white,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Find your calm",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Audio toggle button
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        _isAudioEnabled 
                                          ? (_isAudioPlaying ? Icons.volume_up : Icons.volume_down)
                                          : Icons.volume_off,
                                        color: _isAudioEnabled ? Colors.white : Colors.white54,
                                        size: 24,
                                      ),
                                      onPressed: _toggleAudio,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Technique Selector - FIX 4: Made responsive
                        if (!_isActive)
                          Container(
                            height: MediaQuery.of(context).size.height * 0.15, // Responsive height
                            margin: EdgeInsets.symmetric(horizontal: 20),
                            child: PageView.builder(
                              itemCount: BreathingTechnique.values.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _selectedTechnique = BreathingTechnique.values[index];
                                });
                              },
                              itemBuilder: (context, index) {
                                final technique = BreathingTechnique.values[index];
                                final techniquePattern = _patterns[technique]!;
                                final isSelected = technique == _selectedTechnique;
                                
                                return AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  margin: EdgeInsets.symmetric(horizontal: 8),
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: [
                                              techniquePattern.primaryColor.withOpacity(0.3),
                                              techniquePattern.secondaryColor.withOpacity(0.3),
                                            ],
                                          )
                                        : null,
                                    border: Border.all(
                                      color: isSelected 
                                          ? techniquePattern.primaryColor
                                          : Colors.white24,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        techniquePattern.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Expanded(
                                        child: Text(
                                          techniquePattern.description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        // FIX 5: Replace Spacer with flexible spacing
                        SizedBox(height: 20),

                        // Breathing Circle - FIX 6: Made responsive
                        Flexible(
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.35, // Responsive height
                            child: Center(
                              child: AnimatedBuilder(
                                animation: _breathingAnimation,
                                builder: (context, child) {
                                  return Container(
                                    width: 200 * _breathingAnimation.value,
                                    height: 200 * _breathingAnimation.value,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          pattern.primaryColor.withOpacity(0.8 * _glowAnimation.value),
                                          pattern.secondaryColor.withOpacity(0.4 * _glowAnimation.value),
                                          Colors.transparent,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: pattern.primaryColor.withOpacity(0.5 * _glowAnimation.value),
                                          blurRadius: 30,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      margin: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: pattern.primaryColor.withOpacity(0.3),
                                        border: Border.all(
                                          color: pattern.primaryColor.withOpacity(0.8),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // Phase Text
                        if (_isActive)
                          Column(
                            children: [
                              Text(
                                _getPhaseText(),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 16),
                              // Progress Bar
                              Container(
                                width: 200,
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: Colors.white24,
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _totalPhaseTime > 0 
                                      ? _phaseProgress / _totalPhaseTime 
                                      : 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: pattern.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Cycle $_cycleCount",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),

                        // FIX 7: Replace Spacer with flexible spacing
                        SizedBox(height: 20),

                        // Controls
                        Padding(
                          padding: EdgeInsets.all(30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (!_isActive)
                                _buildControlButton(
                                  icon: Icons.play_arrow,
                                  onPressed: _startBreathing,
                                  color: pattern.primaryColor,
                                  size: 80,
                                )
                              else ...[
                                _buildControlButton(
                                  icon: _isPaused ? Icons.play_arrow : Icons.pause,
                                  onPressed: _isPaused ? _resumeBreathing : _pauseBreathing,
                                  color: pattern.primaryColor,
                                  size: 60,
                                ),
                                SizedBox(width: 20),
                                _buildControlButton(
                                  icon: Icons.stop,
                                  onPressed: _stopBreathing,
                                  color: Colors.red,
                                  size: 60,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onPressed,
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.4,
          ),
        ),
      ),
    );
  }
}

class StarFieldPainter extends CustomPainter {
  final double animationValue;
  final Random random = Random(42);

  StarFieldPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = (sin(animationValue * 2 * pi + i) + 1) / 2;
      
      paint.color = Colors.white.withOpacity(opacity * 0.6);
      canvas.drawCircle(
        Offset(x, y),
        random.nextDouble() * 1.5 + 0.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}