import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlertService {
  AlertService._();
  static final instance = AlertService._();

  final _controller = StreamController<List<String>>.broadcast();
  Stream<List<String>> get alertStream => _controller.stream;
  List<String> _currentAlerts = [];
  List<String> get currentAlerts => _currentAlerts;

  StreamSubscription? _subscription;
  Timer? _cleanupTimer;

  void init() {
    // Initial fetch
    _fetchAlerts();

    // Listen to realtime changes on alerts table
    _subscription = Supabase.instance.client
        .from('alerts')
        .stream(primaryKey: ['id'])
        .listen((_) => _fetchAlerts());

    // Periodic cleanup check every hour (for 24h expiry)
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) => _fetchAlerts());
  }

  Future<void> _fetchAlerts() async {
    try {
      final response = await Supabase.instance.client
          .from('alerts')
          .select('text, created_at')
          .order('created_at', ascending: false);

      final now = DateTime.now();
      final active = <String>[];
      for (final row in response as List) {
        final createdAt = DateTime.parse(row['created_at'] as String);
        if (now.difference(createdAt).inHours < 24) {
          active.add(row['text'] as String);
        }
      }
      _currentAlerts = active;
      _controller.add(active);
    } catch (e) {
      print('Error fetching alerts: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _cleanupTimer?.cancel();
    _controller.close();
  }
}
