import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets.dart';
import '../../result/presentation/results_screen.dart';

/// Live speaking-exam screen — the "while speaking" state.
class SpeakingScreen extends StatefulWidget {
  const SpeakingScreen({super.key});

  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen>
    with TickerProviderStateMixin {
  static const _total = 5;
  int _question = 3; // 1-based, matches "Question 3 of 5"
  int _remaining = 42; // seconds left to answer

  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _wave.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _submit() {
    // TODO: wire to the real session once this screen drives an actual exam attempt.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ResultsScreen(sessionId: '', examName: ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              // ── Top bar: exit · progress · timer ──
              Row(
                children: [
                  GhostIconButton(
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  Text(
                    'Question $_question of $_total',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  SessionTimer(seconds: _remaining),
                ],
              ),
              const SizedBox(height: 14),

              // Progress dots
              Row(
                children: [
                  for (int i = 1; i <= _total; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i == _total ? 0 : 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: i <= _question
                              ? AppColors.secondary
                              : Colors.white.withOpacity(0.12),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),

              // ── AI prompt card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.indigo, AppColors.secondary],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome,
                              size: 15, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'AI EXAMINER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const Spacer(),
                        AudioBarsBadge(controller: _wave),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Describe a time you used social media to learn '
                      'something new. What was it, and how did it help you?',
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.replay,
                            size: 16, color: Colors.white.withOpacity(0.55)),
                        const SizedBox(width: 6),
                        Text(
                          'Replay prompt (1 left)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Recording visualization ──
              Text(
                'Recording your answer…',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 64,
                child: AnimatedBuilder(
                  animation: _wave,
                  builder: (_, _) => CustomPaint(
                    size: const Size(double.infinity, 64),
                    painter: WaveformPainter(_wave.value),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Pulsing mic
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) {
                  final t = _pulse.value;
                  return Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.danger,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withOpacity(0.35 * (1 - t)),
                          blurRadius: 8,
                          spreadRadius: 14 * t,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: const Icon(Icons.mic, size: 36, color: Colors.white),
              ),

              const Spacer(),

              // ── Actions ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Re-record'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.25)),
                        minimumSize: const Size(0, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GradientButton(
                      label: _question < _total ? 'Next question' : 'Submit exam',
                      icon: Icons.arrow_forward,
                      onTap: () {
                        if (_question < _total) {
                          setState(() {
                            _question++;
                            _remaining = 60;
                          });
                        } else {
                          _submit();
                        }
                      },
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
}

