import 'dart:convert';
import 'package:flutter/material.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';
import '../core/network/api_client.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isSyncing = false;
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  void initialize(BuildContext context) {
    // Listen to network changes
    ConnectivityService().isOnline.listen((online) {
      if (online) {
        _runSync(context);
      }
    });

    // Check count on startup
    updatePendingCount();
  }

  Future<void> updatePendingCount() async {
    final pending = await OfflineQueueService().getPendingItems();
    pendingCount.value = pending.length;
  }

  Future<void> _runSync(BuildContext context) async {
    if (_isSyncing) return;

    final pending = await OfflineQueueService().getPendingItems();
    if (pending.isEmpty) {
      updatePendingCount();
      return;
    }

    _isSyncing = true;
    updatePendingCount();

    // Show starting SnackBar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Menyinkronkan ${pending.length} data..."),
          backgroundColor: Colors.blue[800],
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final List<Map<String, dynamic>> itemsToSend = pending.map((item) {
        return {
          'id': item['id'],
          'action_type': item['action_type'],
          'payload': json.decode(item['payload']),
          'timestamp': item['timestamp'],
        };
      }).toList();

      final apiClient = ApiClient();
      final response = await apiClient.dio.post('/sync/batch', data: {
        'items': itemsToSend,
      });

      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        bool hasConflictOrFailed = false;

        for (var result in results) {
          final int id = result['id'];
          final String status = result['status'];

          if (status == 'synced' || status == 'conflict') {
            await OfflineQueueService().markAsSynced(id);
          } else {
            hasConflictOrFailed = true;
            await OfflineQueueService().incrementRetry(id);
          }
        }

        if (context.mounted) {
          if (hasConflictOrFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Beberapa data gagal, akan dicoba lagi"),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Semua data berhasil disinkronkan ✓"),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        await _handleSyncFailure(pending);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Beberapa data gagal, akan dicoba lagi"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      await _handleSyncFailure(pending);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Beberapa data gagal, akan dicoba lagi"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      _isSyncing = false;
      updatePendingCount();
    }
  }

  Future<void> _handleSyncFailure(List<Map<String, dynamic>> pending) async {
    for (var item in pending) {
      final int id = item['id'];
      final int retryCount = item['retry_count'] ?? 0;

      if (retryCount < 2) {
        await OfflineQueueService().incrementRetry(id);
      } else {
        await OfflineQueueService().markAsFailed(id);
      }
    }
  }
}
