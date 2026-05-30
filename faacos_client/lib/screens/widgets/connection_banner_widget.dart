import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../services/connectivity_service.dart';

class ConnectionBannerWidget extends StatefulWidget {
  const ConnectionBannerWidget({super.key});

  @override
  State<ConnectionBannerWidget> createState() => _ConnectionBannerWidgetState();
}

class _ConnectionBannerWidgetState extends State<ConnectionBannerWidget>
    with SingleTickerProviderStateMixin {
  bool _isOffline = false;
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Check initial status
    _isOffline = !ConnectivityService().currentStatus;
    if (_isOffline) _controller.forward();

    // Listen for changes
    ConnectivityService().isOnline.listen((online) {
      if (!mounted) return;
      setState(() {
        _isOffline = !online;
      });
      if (_isOffline) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _slideAnimation,
      axisAlignment: -1.0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.error.withOpacity(0.95),
                const Color(0xFFB91C1C),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tidak ada koneksi — data disimpan lokal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
