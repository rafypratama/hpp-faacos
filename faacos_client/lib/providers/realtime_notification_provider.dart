import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../screens/widgets/realtime_notification_overlay.dart';

class RealtimeNotificationProvider with ChangeNotifier {
  PusherChannelsFlutter? _pusher;
  bool _isInitialized = false;
  String? _currentUserEmail;
  BuildContext? _context;

  bool get isInitialized => _isInitialized;

  /// Initialize Pusher and subscribe to the events channel.
  /// We pass the BuildContext so that we can trigger the global Overlay Toast.
  void initialize(BuildContext context, String userEmail) async {
    if (_isInitialized && _currentUserEmail == userEmail) {
      // Already connected with the same user session
      return;
    }

    // Clean up any existing connection first
    disconnect();

    _context = context;
    _currentUserEmail = userEmail;
    _pusher = PusherChannelsFlutter.getInstance();

    try {
      await _pusher!.init(
        apiKey: "3801a49bf682629f09aa",
        cluster: "ap1",
        onEvent: _onPusherEvent,
        onError: (message, code, exception) {
          debugPrint("PUSHER_DEBUG Error: $message (code: $code) - $exception");
        },
        onConnectionStateChange: (currentState, previousState) {
          debugPrint("PUSHER_DEBUG Connection State Changed: from $previousState to $currentState");
        },
      );

      await _pusher!.subscribe(channelName: "faacos-events");
      await _pusher!.connect();
      _isInitialized = true;
      debugPrint("PUSHER_DEBUG successfully subscribed & connected.");
    } catch (e) {
      debugPrint("PUSHER_DEBUG Exception on init: $e");
    }
  }

  /// Cleanly disconnect from Pusher
  void disconnect() async {
    if (_pusher != null && _isInitialized) {
      try {
        await _pusher!.unsubscribe(channelName: "faacos-events");
        await _pusher!.disconnect();
      } catch (e) {
        debugPrint("PUSHER_DEBUG Exception on disconnect: $e");
      }
    }
    _pusher = null;
    _isInitialized = false;
    _currentUserEmail = null;
    _context = null;
    debugPrint("PUSHER_DEBUG disconnected cleanly.");
  }

  /// Handle incoming events from Pusher
  void _onPusherEvent(PusherEvent event) {
    debugPrint("PUSHER_DEBUG Event received: ${event.eventName} on channel ${event.channelName}");
    if (event.channelName == "faacos-events" && event.eventName == "realtime-action") {
      try {
        final data = json.decode(event.data) as Map<String, dynamic>;
        final userName = data['userName'] as String? ?? 'Operator';
        final userRole = data['userRole'] as String? ?? 'system';
        final action = data['action'] as String? ?? 'activity';
        final description = data['description'] as String? ?? 'Aksi operasional terdeteksi.';

        if (_context != null && _context!.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            RealtimeNotificationOverlay.show(
              _context!,
              userName: userName,
              userRole: userRole,
              action: action,
              description: description,
            );
          });
        }
      } catch (e) {
        debugPrint("PUSHER_DEBUG Error parsing event data: $e");
      }
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
