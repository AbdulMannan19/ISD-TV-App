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

  void init() {
    _fetchAlerts();

    _subscription = Supabase.instance.client
        .from('alerts')
        .stream(primaryKey: ['id'])
        .listen((_) => _fetchAlerts());
  }

  Future<void> _fetchAlerts() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await Supabase.instance.client
          .from('alerts')
          .select('text')
          .lte('start_time', now)
          .gt('end_time', now)
          .order('created_at', ascending: false);

      final active = (response as List).map((r) => r['text'] as String).toList();
      _currentAlerts = active;
      _controller.add(active);
    } catch (e) {
      print('Error fetching alerts: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
