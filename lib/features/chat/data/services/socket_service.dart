import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? _socket;

  void connect(String tenantId, String token, String serverUrl) {
    _socket = IO.io(serverUrl, {
      'transports': ['websocket'],
      'auth': {'token': token},
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      _socket!.emit('join', tenantId);
    });
  }

  Stream<List<Map<String, dynamic>>> getConversations() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    _socket?.on('conversations_update', (data) {
      if (data is List) {
        controller.add(List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e))));
      }
    });
    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getMessages(String contactId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    _socket?.on('messages_$contactId', (data) {
      if (data is List) {
        controller.add(List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e))));
      }
    });
    return controller.stream;
  }

  void requestMessages(String contactId) {
    _socket?.emit('get_messages', contactId);
  }

  Stream<List<Map<String, dynamic>>> getCampaignsStream() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    _socket?.on('campaigns_update', (data) {
      if (data is List) {
        controller.add(List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e))));
      }
    });
    return controller.stream;
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  bool get isConnected => _socket?.connected ?? false;
}
