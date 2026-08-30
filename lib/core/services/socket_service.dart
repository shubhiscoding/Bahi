import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/backend_config.dart';
import 'supabase_client.dart';

/// Wraps the Socket.IO connection to the backend for live updates
/// (replaces the old Supabase Realtime .stream() calls).
class SocketService {
  static io.Socket? _socket;
  static String? _joinedBusinessId;

  /// Connects (if not already connected) using the current session's token.
  static io.Socket connect() {
    if (_socket != null && _socket!.connected) return _socket!;

    final token = SupabaseClientService.auth.currentSession?.accessToken;

    _socket = io.io(
      backendBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();
    return _socket!;
  }

  /// Joins the room for a business — call after connect() whenever the
  /// current business changes.
  static void joinBusiness(String businessId) {
    final socket = connect();
    if (_joinedBusinessId != null && _joinedBusinessId != businessId) {
      socket.emit('leave:business', _joinedBusinessId);
    }
    socket.emit('join:business', businessId);
    _joinedBusinessId = businessId;
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _joinedBusinessId = null;
  }
}
