import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import 'api_service.dart';

class GradeEvent {
  final String action; // GRADE_CREATED | GRADE_MODIFIED
  final String studentName;
  final String teacherName;
  final String subjectName;
  final String classRoomName;
  final double? oldValue;
  final double newValue;
  final String? reason;
  final DateTime timestamp;

  GradeEvent({
    required this.action,
    required this.studentName,
    required this.teacherName,
    required this.subjectName,
    required this.classRoomName,
    this.oldValue,
    required this.newValue,
    this.reason,
    required this.timestamp,
  });

  factory GradeEvent.fromJson(Map<String, dynamic> json) {
    return GradeEvent(
      action: json['action'] as String,
      studentName: json['studentName'] as String,
      teacherName: json['teacherName'] as String,
      subjectName: json['subjectName'] as String,
      classRoomName: json['classRoomName'] as String,
      oldValue: json['oldValue'] != null ? (json['oldValue'] as num).toDouble() : null,
      newValue: (json['newValue'] as num).toDouble(),
      reason: json['reason'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

// Connexion WebSocket pour recevoir les alertes en direct — réservé aux superviseurs
// côté serveur (voir RealtimeGateway.notifySupervisorsGradeEvent), mais la connexion
// elle-même est ouverte à tout rôle authentifié ; c'est le canal ("room") auquel
// on s'abonne qui filtre ce qu'on reçoit réellement.
class RealtimeService extends ChangeNotifier {
  final ApiService _api;
  io.Socket? _socket;
  final List<GradeEvent> _events = [];
  bool _connected = false;

  RealtimeService(this._api);

  List<GradeEvent> get events => List.unmodifiable(_events);
  bool get isConnected => _connected;

  Future<void> connect() async {
    final token = await _api.getToken();
    if (token == null) return;

    _socket?.dispose();
    _socket = io.io(
      ApiConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      notifyListeners();
    });

    _socket!.on('grade_event', (data) {
      final event = GradeEvent.fromJson(Map<String, dynamic>.from(data as Map));
      _events.insert(0, event); // le plus récent en premier
      notifyListeners();
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
