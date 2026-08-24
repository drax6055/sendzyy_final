import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A persistent local cache that maps a sent message's wamid to the
/// contextMessageId (parent message) it was replying to.
///
/// This exists as a fallback for when the production backend does not
/// yet persist/return contextMessageId — we store it client-side and
/// inject it back when messages arrive from Socket.io or REST.
class ReplyContextStore {
  static const _kStoreKey = 'reply_context_map';

  // In-memory map: sentMessageText+timestamp key → parentId
  // (used as a short-lived bridge before wamid arrives)
  static final Map<String, String> _pendingByText = {};

  // Persistent map: sentWamid → parentContextMessageId
  static Map<String, String> _persistedByWamid = {};
  static bool _loaded = false;

  /// Call once at startup (or lazily) to load persisted data.
  static Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStoreKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _persistedByWamid = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    _loaded = true;
  }

  /// Register a pending reply: we know the text of the message we're
  /// about to send, and the contextMessageId it replies to.
  /// When the wamid comes back (via Socket or REST), call [confirmWamid].
  static void registerPending({
    required String messageText,
    required String contextMessageId,
  }) {
    _pendingByText[messageText.trim()] = contextMessageId;
  }

  /// Once we learn the wamid of a sent message, persist text→wamid mapping.
  static Future<void> confirmWamid({
    required String wamid,
    required String contextMessageId,
  }) async {
    _persistedByWamid[wamid] = contextMessageId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStoreKey, jsonEncode(_persistedByWamid));
    } catch (_) {}
  }

  /// Look up the contextMessageId for an incoming message.
  /// First checks the persisted wamid map, then falls back to in-memory text match.
  static String? lookup({
    required Map<String, dynamic> msg,
  }) {
    // Already has contextMessageId from backend – trust it
    final existing = msg['contextMessageId']?.toString();
    if (existing != null && existing.isNotEmpty) return existing;

    final bool isMe = msg['isMe'] == true;
    if (!isMe) return null;

    // Try persisted wamid map
    final wamid = msg['wamid']?.toString();
    if (wamid != null && _persistedByWamid.containsKey(wamid)) {
      return _persistedByWamid[wamid];
    }

    // Fallback: text match (for the very first Socket.io update before wamid confirms)
    final text = msg['text']?.toString().trim() ?? '';
    if (text.isNotEmpty && _pendingByText.containsKey(text)) {
      final ctxId = _pendingByText[text]!;
      // Promote to wamid-based if wamid is now available
      if (wamid != null && wamid.isNotEmpty) {
        _persistedByWamid[wamid] = ctxId;
        _pendingByText.remove(text);
        // Fire-and-forget persist
        _saveAsync();
      }
      return ctxId;
    }

    return null;
  }

  static void _saveAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStoreKey, jsonEncode(_persistedByWamid));
    } catch (_) {}
  }

  /// Enrich a list of messages with contextMessageId from the local store.
  static List<Map<String, dynamic>> enrich(List<Map<String, dynamic>> messages) {
    return messages.map((raw) {
      final ctxId = lookup(msg: raw);
      if (ctxId != null && (raw['contextMessageId'] == null || raw['contextMessageId'].toString().isEmpty)) {
        final m = Map<String, dynamic>.from(raw);
        m['contextMessageId'] = ctxId;
        return m;
      }
      return raw;
    }).toList();
  }
}
