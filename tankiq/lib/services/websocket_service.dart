import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  WebSocketService._internal();

  WebSocketChannel? _channel;
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final String _url = 'ws://localhost:8000/ws/updates/';

  void connect() {
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      _isConnected = true;
      debugPrint('Connected to WebSocket: $_url');

      _channel!.stream.listen(
        (data) {
          final decoded = jsonDecode(data);
          if (decoded['message'] != null) {
            _streamController.add(decoded['message']);
          }
        },
        onDone: () {
          _isConnected = false;
          debugPrint('WebSocket closed. Reconnecting in 5s...');
          Future.delayed(const Duration(seconds: 5), () => connect());
        },
        onError: (error) {
          _isConnected = false;
          debugPrint('WebSocket error: $error. Reconnecting in 5s...');
          Future.delayed(const Duration(seconds: 5), () => connect());
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isConnected = false;
      debugPrint('WebSocket connection failed: $e. Retrying in 5s...');
      Future.delayed(const Duration(seconds: 5), () => connect());
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }
}
