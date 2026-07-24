import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

enum ConnectionSpeed {
  fast,
  slow,
  none,
}

class NetworkStatus {
  final bool isOnline;
  final ConnectionSpeed speed;

  const NetworkStatus({
    required this.isOnline,
    required this.speed,
  });

  NetworkStatus copyWith({
    bool? isOnline,
    ConnectionSpeed? speed,
  }) {
    return NetworkStatus(
      isOnline: isOnline ?? this.isOnline,
      speed: speed ?? this.speed,
    );
  }
}

class NetworkService extends StateNotifier<NetworkStatus> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;
  Timer? _speedCheckTimer;

  NetworkService() : super(const NetworkStatus(isOnline: true, speed: ConnectionSpeed.fast)) {
    _init();
  }

  void _init() {
    _checkStatus();
    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = _interpretResults(results);
      if (!hasConnection) {
        state = const NetworkStatus(isOnline: false, speed: ConnectionSpeed.none);
      } else {
        _measureSpeed();
      }
    });

    // Periodically re-check network speed every 30 seconds
    _speedCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.isOnline) {
        _measureSpeed();
      }
    });
  }

  bool _interpretResults(dynamic results) {
    if (results is List) {
      if (results.isEmpty) return false;
      return results.any((r) => r != ConnectivityResult.none);
    } else if (results is ConnectivityResult) {
      return results != ConnectivityResult.none;
    }
    return false;
  }

  Future<void> _checkStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = _interpretResults(results);
      if (!hasConnection) {
        state = const NetworkStatus(isOnline: false, speed: ConnectionSpeed.none);
      } else {
        await _measureSpeed();
      }
    } catch (_) {
      state = const NetworkStatus(isOnline: false, speed: ConnectionSpeed.none);
    }
  }

  Future<void> _measureSpeed() async {
    try {
      final stopwatch = Stopwatch()..start();
      // Try to ping a reliable server with a short timeout
      final client = http.Client();
      final response = await client.get(
        Uri.parse('https://clients3.google.com/generate_204'),
      ).timeout(const Duration(seconds: 3));
      stopwatch.stop();

      if (response.statusCode == 204) {
        final latency = stopwatch.elapsedMilliseconds;
        // If latency < 600ms, classify as FAST, otherwise SLOW
        final speed = latency < 600 ? ConnectionSpeed.fast : ConnectionSpeed.slow;
        state = NetworkStatus(isOnline: true, speed: speed);
      } else {
        state = NetworkStatus(isOnline: true, speed: ConnectionSpeed.slow);
      }
      client.close();
    } catch (_) {
      // Offline or extremely poor connection
      state = const NetworkStatus(isOnline: false, speed: ConnectionSpeed.none);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _speedCheckTimer?.cancel();
    super.dispose();
  }
}

final networkServiceProvider = StateNotifierProvider<NetworkService, NetworkStatus>((ref) {
  return NetworkService();
});
