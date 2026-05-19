import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class RealtimeNotificationOverlay extends StatefulWidget {
  final String userName;
  final String userRole;
  final String action;
  final String description;
  final VoidCallback onDismiss;

  const RealtimeNotificationOverlay({
    super.key,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.description,
    required this.onDismiss,
  });

  static void show(
    BuildContext context, {
    required String userName,
    required String userRole,
    required String action,
    required String description,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 16, right: 16),
            child: Material(
              color: Colors.transparent,
              child: RealtimeNotificationOverlay(
                userName: userName,
                userRole: userRole,
                action: action,
                description: description,
                onDismiss: () {
                  try {
                    overlayEntry.remove();
                  } catch (_) {}
                },
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);
  }

  @override
  State<RealtimeNotificationOverlay> createState() => _RealtimeNotificationOverlayState();
}

class _RealtimeNotificationOverlayState extends State<RealtimeNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto dismiss after 5 seconds
    _autoDismissTimer = Timer(const Duration(seconds: 5), () {
      dismiss();
    });
  }

  void dismiss() {
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _getAccentColor() {
    switch (widget.action) {
      case 'approve_formula':
      case 'mr_approved':
        return AppColors.secondary; // Emerald
      case 'restock_alert':
        return AppColors.error; // Red
      case 'schedule_production':
        return AppColors.primary; // Indigo
      case 'adjust_stock':
        return AppColors.warning; // Amber
      default:
        return AppColors.primaryLight;
    }
  }

  IconData _getIcon() {
    switch (widget.action) {
      case 'approve_formula':
        return Icons.science_outlined;
      case 'mr_approved':
        return Icons.check_circle_outline_rounded;
      case 'mr_rejected':
        return Icons.cancel_outlined;
      case 'restock_alert':
        return Icons.warning_amber_rounded;
      case 'schedule_production':
        return Icons.calendar_month_outlined;
      case 'adjust_stock':
        return Icons.inventory_2_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  String _getBadgeText() {
    switch (widget.action) {
      case 'approve_formula':
        return 'FORMULA APPROVED';
      case 'mr_approved':
        return 'MR RELEASED';
      case 'mr_rejected':
        return 'MR REJECTED';
      case 'restock_alert':
        return 'RESTOCK WARNING';
      case 'schedule_production':
        return 'BATCH SCHEDULED';
      case 'adjust_stock':
        return 'STOCK MUTATION';
      default:
        return 'ACTIVITY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getAccentColor();
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width > 420 ? 400.0 : mediaQuery.size.width - 32;

    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: dismiss,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: width,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accentColor.withOpacity(0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.12),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Glowing Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _getIcon(),
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Content text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header badge & close button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _getBadgeText(),
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textMuted.withOpacity(0.7),
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // User Info
                            Text(
                              '${widget.userName} [${widget.userRole.toUpperCase()}]',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Description detail
                            Text(
                              widget.description,
                              style: TextStyle(
                                color: AppColors.textSecondary.withOpacity(0.9),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
