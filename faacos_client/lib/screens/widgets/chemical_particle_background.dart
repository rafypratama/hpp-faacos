import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
  });

  void update(double width, double height) {
    x += vx;
    y += vy;

    if (x < 0 || x > width) vx = -vx;
    if (y < 0 || y > height) vy = -vy;

    // Constraint boundary safety
    if (x < 0) x = 0;
    if (x > width) x = width;
    if (y < 0) y = 0;
    if (y > height) y = height;
  }
}

class ChemicalBackgroundPainter extends CustomPainter {
  final List<Particle> particles;
  final double maxDistance;

  ChemicalBackgroundPainter({required this.particles, required this.maxDistance});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()..strokeWidth = 1.0;

    // 1. Draw connections (Molecular bonds)
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final p1 = particles[i];
        final p2 = particles[j];
        final dist = math.sqrt(math.pow(p1.x - p2.x, 2) + math.pow(p1.y - p2.y, 2));

        if (dist < maxDistance) {
          final alpha = (1.0 - (dist / maxDistance)) * 0.22;
          linePaint.color = AppColors.primaryLight.withOpacity(alpha);
          canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), linePaint);
        }
      }
    }

    // 2. Draw nodes & chemical structure rings
    for (final p in particles) {
      // Draw core particle node
      paint.color = p.color;
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);

      // Draw subtle glow ring
      paint.color = p.color.withOpacity(0.15);
      canvas.drawCircle(Offset(p.x, p.y), p.radius * 2.5, paint);

      // Draw hexagonal chemical ring outlines for larger particles to make it distinctively chemical!
      if (p.radius > 3.8) {
        final hexPaint = Paint()
          ..color = p.color.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        final path = Path();
        final radius = p.radius * 4.5;
        for (int k = 0; k < 6; k++) {
          final angle = k * math.pi / 3;
          final x = p.x + radius * math.cos(angle);
          final y = p.y + radius * math.sin(angle);
          if (k == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, hexPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ChemicalParticleBackground extends StatefulWidget {
  const ChemicalParticleBackground({super.key});

  @override
  State<ChemicalParticleBackground> createState() => _ChemicalParticleBackgroundState();
}

class _ChemicalParticleBackgroundState extends State<ChemicalParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final int _particleCount = 38;
  final double _maxDistance = 115.0;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    // Continuous ticker controller driving 60 FPS repaint
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..addListener(() {
        _updateParticles();
      })..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initParticles(Size size) {
    if (_particles.isNotEmpty) return;

    final colors = [
      AppColors.primary.withOpacity(0.35),
      AppColors.primaryLight.withOpacity(0.45),
      AppColors.secondary.withOpacity(0.35),
      AppColors.accent.withOpacity(0.3),
      const Color(0xFFF59E0B).withOpacity(0.3), // Amber/gold particle accents
    ];

    for (int i = 0; i < _particleCount; i++) {
      _particles.add(
        Particle(
          x: _random.nextDouble() * size.width,
          y: _random.nextDouble() * size.height,
          vx: (_random.nextDouble() - 0.5) * 0.75, // Sleek, smooth velocity
          vy: (_random.nextDouble() - 0.5) * 0.75,
          radius: _random.nextDouble() * 3.5 + 1.5,
          color: colors[_random.nextInt(colors.length)],
        ),
      );
    }
  }

  void _updateParticles() {
    if (_particles.isEmpty) return;
    final size = MediaQuery.of(context).size;
    for (final p in _particles) {
      p.update(size.width, size.height);
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _initParticles(size);

    return CustomPaint(
      size: size,
      painter: ChemicalBackgroundPainter(
        particles: _particles,
        maxDistance: _maxDistance,
      ),
    );
  }
}
