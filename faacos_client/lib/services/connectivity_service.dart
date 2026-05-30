import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  Stream<bool> get isOnline => _connectionController.stream;
  
  bool _lastStatus = true;
  bool get currentStatus => _lastStatus;

  void initialize() {
    _connectivity.checkConnectivity().then((results) {
      _updateStatus(results);
    });

    _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // If there is any connection type other than none, we are online
    final hasConnection = results.any((result) => result != ConnectivityResult.none);
    
    if (_lastStatus != hasConnection) {
      _lastStatus = hasConnection;
      _connectionController.add(hasConnection);
    }
  }
}
