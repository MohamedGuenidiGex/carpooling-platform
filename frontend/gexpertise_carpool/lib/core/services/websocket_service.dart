import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../network/api_client.dart';

/// WebSocket Service for real-time updates
///
/// Manages Socket.IO connection and event handling for ride status updates
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentToken;
  final Map<String, List<Function(dynamic)>> _eventListeners = {};

  bool get isConnected => _isConnected;

  /// Connect to WebSocket server with JWT token
  void connect(String token) {
    if (_isConnected && _currentToken == token) {
      debugPrint('WebSocket: Already connected with same token');
      return;
    }

    disconnect();
    _currentToken = token;

    try {
      final baseUrl = ApiClient.baseUrl;

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setQuery({'token': token})
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('WebSocket: Connected to server');
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('WebSocket: Disconnected from server');
      });

      _socket!.onConnectError((error) {
        debugPrint('WebSocket: Connection error: $error');
      });

      _socket!.onError((error) {
        debugPrint('WebSocket: Error: $error');
      });

      _socket!.on('connection_response', (data) {
        debugPrint('WebSocket: Connection response: $data');
      });

      _socket!.on('error', (data) {
        debugPrint('WebSocket: Server error: $data');
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('WebSocket: Failed to initialize: $e');
    }
  }

  /// Disconnect from WebSocket server
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _currentToken = null;
      _eventListeners.clear();
      debugPrint('WebSocket: Disconnected and cleaned up');
    }
  }

  /// Join a ride-specific room to receive updates
  void joinRide(int rideId) {
    if (!_isConnected || _socket == null) {
      debugPrint('WebSocket: Cannot join ride - not connected');
      return;
    }

    _socket!.emit('join_ride', {'ride_id': rideId});
    debugPrint('WebSocket: Joining ride room: $rideId');

    _socket!.once('joined_ride', (data) {
      debugPrint('WebSocket: Joined ride room: $data');
    });
  }

  /// Leave a ride-specific room
  void leaveRide(int rideId) {
    if (!_isConnected || _socket == null) {
      debugPrint('WebSocket: Cannot leave ride - not connected');
      return;
    }

    _socket!.emit('leave_ride', {'ride_id': rideId});
    debugPrint('WebSocket: Leaving ride room: $rideId');

    _socket!.once('left_ride', (data) {
      debugPrint('WebSocket: Left ride room: $data');
    });
  }

  /// Listen for ride status updates
  void onRideStatusUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      debugPrint('WebSocket: Cannot listen - socket not initialized');
      return;
    }

    _socket!.on('ride_status_updated', (data) {
      debugPrint('WebSocket: Ride status updated: $data');
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  /// Remove all listeners for a specific event
  void removeAllListeners(String event) {
    _socket?.off(event);
  }

  /// Generic event listener
  void on(String event, Function(dynamic) callback) {
    if (_socket == null) {
      debugPrint('WebSocket: Cannot listen to $event - socket not initialized');
      return;
    }

    if (!_eventListeners.containsKey(event)) {
      _eventListeners[event] = [];
    }
    _eventListeners[event]!.add(callback);

    _socket!.on(event, callback);
  }

  /// Remove specific event listener
  void off(String event, [Function(dynamic)? callback]) {
    if (_socket == null) return;

    if (callback != null) {
      _socket!.off(event, callback);
      _eventListeners[event]?.remove(callback);
    } else {
      _socket!.off(event);
      _eventListeners.remove(event);
    }
  }
}
