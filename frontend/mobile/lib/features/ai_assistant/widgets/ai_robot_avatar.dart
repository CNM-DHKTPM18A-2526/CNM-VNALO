import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';

class AiRobotAvatar extends StatefulWidget {
  final AiState state;
  final String emotion;
  final double size;
  final VoidCallback? onTap;

  const AiRobotAvatar({
    super.key,
    required this.state,
    required this.emotion,
    this.size = 120,
    this.onTap,
  });

  @override
  State<AiRobotAvatar> createState() => _AiRobotAvatarState();
}

class _AiRobotAvatarState extends State<AiRobotAvatar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  Timer? _blinkTimer;
  Timer? _blinkCloseTimer;
  bool _blinkClosed = false;
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncAnimationState();
    _scheduleBlink();
  }

  @override
  void didUpdateWidget(covariant AiRobotAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncAnimationState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    _syncAnimationState();
    if (_isAppActive) {
      _scheduleBlink();
    } else {
      _blinkTimer?.cancel();
      _blinkCloseTimer?.cancel();
      if (_blinkClosed && mounted) {
        setState(() {
          _blinkClosed = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blinkTimer?.cancel();
    _blinkCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimationState() {
    final shouldAnimate = _isAppActive && widget.state != AiState.idle;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkCloseTimer?.cancel();
    if (!_isAppActive) {
      return;
    }
    _blinkTimer = Timer(
      Duration(milliseconds: 2400 + (math.Random().nextInt(1500))),
      () {
        if (!mounted) {
          return;
        }
        setState(() {
          _blinkClosed = true;
        });
        _blinkCloseTimer = Timer(const Duration(milliseconds: 130), () {
          if (!mounted) {
            return;
          }
          setState(() {
            _blinkClosed = false;
          });
          _scheduleBlink();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auraColor = _auraColorForState(widget.state);
    final faceColor = _faceColorForState(widget.state);

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final wave = math.sin(_controller.value * math.pi * 2);
            final lift =
                widget.state == AiState.listening ? wave * 1.0 : wave * 2.0;
            final auraScale =
                widget.state == AiState.listening
                    ? 0.9 + ((_controller.value + 0.08) * 0.08)
                    : 0.92 + ((_controller.value + 0.12) * 0.12);

            return Transform.translate(
              offset: Offset(0, lift),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: auraScale,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            auraColor.withValues(alpha: 0.35),
                            auraColor.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                          stops: const [0.42, 0.72, 1],
                        ),
                      ),
                    ),
                  ),
                  _RobotHead(
                    size: widget.size,
                    faceColor: faceColor,
                    eyeColor: auraColor,
                    blinkClosed: _blinkClosed,
                    state: widget.state,
                    emotion: widget.emotion,
                    pulse: _controller.value,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _auraColorForState(AiState state) {
    switch (state) {
      case AiState.listening:
        return const Color(0xFF22D3EE);
      case AiState.thinking:
        return const Color(0xFF60A5FA);
      case AiState.speaking:
        return const Color(0xFF34D399);
      case AiState.idle:
        return const Color(0xFF93C5FD);
    }
  }

  Color _faceColorForState(AiState state) {
    switch (state) {
      case AiState.listening:
        return const Color(0xFF0F172A);
      case AiState.thinking:
        return const Color(0xFF111827);
      case AiState.speaking:
        return const Color(0xFF0B1324);
      case AiState.idle:
        return const Color(0xFF101B34);
    }
  }
}

class _RobotHead extends StatelessWidget {
  final double size;
  final Color faceColor;
  final Color eyeColor;
  final bool blinkClosed;
  final AiState state;
  final String emotion;
  final double pulse;

  const _RobotHead({
    required this.size,
    required this.faceColor,
    required this.eyeColor,
    required this.blinkClosed,
    required this.state,
    required this.emotion,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final shellWidth = size * 0.78;
    final shellHeight = size * 0.62;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 0.1,
          height: size * 0.1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [eyeColor.withValues(alpha: 0.4), eyeColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(size * 0.04),
          ),
        ),
        Container(
          width: shellWidth,
          height: shellHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.22),
            gradient: LinearGradient(
              colors: [faceColor, faceColor.withValues(alpha: 0.84)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: eyeColor.withValues(alpha: 0.45),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: eyeColor.withValues(alpha: 0.28),
                blurRadius: 16,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size * 0.12,
              vertical: size * 0.12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RobotEye(
                      color: eyeColor,
                      blinkClosed: blinkClosed,
                      pulse: pulse,
                    ),
                    _RobotEye(
                      color: eyeColor,
                      blinkClosed: blinkClosed,
                      pulse: pulse,
                    ),
                  ],
                ),
                SizedBox(height: size * 0.09),
                _RobotMouth(
                  state: state,
                  emotion: emotion,
                  color: eyeColor,
                  pulse: pulse,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RobotEye extends StatelessWidget {
  final Color color;
  final bool blinkClosed;
  final double pulse;

  const _RobotEye({
    required this.color,
    required this.blinkClosed,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final eyeHeight =
        blinkClosed ? 3.0 : 11.0 + (math.sin(pulse * math.pi) * 1.2);

    return Container(
      width: 16,
      height: eyeHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _RobotMouth extends StatelessWidget {
  final AiState state;
  final String emotion;
  final Color color;
  final double pulse;

  const _RobotMouth({
    required this.state,
    required this.emotion,
    required this.color,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final anim = 0.35 + (math.sin(pulse * math.pi * 2) + 1) * 0.32;

    switch (state) {
      case AiState.listening:
        return Container(
          width: 32,
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      case AiState.thinking:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final phase = (pulse + index * 0.18) % 1;
            final scale = 0.6 + (math.sin(phase * math.pi * 2) + 1) * 0.3;
            return Transform.scale(
              scale: scale,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      case AiState.speaking:
        return Container(
          width: 34,
          height: 7 + (anim * 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.95),
                color.withValues(alpha: 0.65),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      case AiState.idle:
        final isJoy = emotion.toLowerCase().contains('joy');
        return Container(
          width: isJoy ? 28 : 20,
          height: 6,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
          ),
        );
    }
  }
}
