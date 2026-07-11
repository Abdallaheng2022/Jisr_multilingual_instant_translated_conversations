import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A translated voice message inside a room (turn-based between two people).
class RoomMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String originalText;
  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final String? audioUrl;
  final int timestamp;

  RoomMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.originalText,
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    required this.timestamp,
    this.audioUrl,
  });

  Map<String, dynamic> toRow(String code) => {
        'room_code': code,
        'sender_id': senderId,
        'sender_name': senderName,
        'original_text': originalText,
        'translated_text': translatedText,
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'audio_url': audioUrl,
        'ts': timestamp,
      };

  factory RoomMessage.fromRow(Map<String, dynamic> r) => RoomMessage(
        id: r['id'].toString(),
        senderId: r['sender_id'] ?? '',
        senderName: r['sender_name'] ?? '',
        originalText: r['original_text'] ?? '',
        translatedText: r['translated_text'] ?? '',
        sourceLang: r['source_lang'] ?? '',
        targetLang: r['target_lang'] ?? '',
        audioUrl: r['audio_url'],
        timestamp: r['ts'] ?? 0,
      );
}

/// Room service backed by Supabase (Postgres tables + Realtime + Storage).
/// Two phones connect via a room code; messages sync in realtime.
class RoomService {
  SupabaseClient get _db => Supabase.instance.client;

  /// Upload cloned audio, return a public URL the other phone can play
  Future<String> uploadAudio(String localPath, String code) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final path = 'room_audio/$code/$id.wav';
    await _db.storage.from('rooms').upload(path, File(localPath));
    return _db.storage.from('rooms').getPublicUrl(path);
  }

  /// Generate a unique 6-char room code (no ambiguous chars)
  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Create a new room (host)
  Future<void> createRoom({
    required String code,
    required String hostId,
    required String hostName,
    required String hostLang,
  }) async {
    await _db.from('rooms').insert({
      'code': code,
      'host_id': hostId,
      'host_name': hostName,
      'host_lang': hostLang,
      'active': true,
    });
  }

  /// Join an existing room; returns host data (or null if not found)
  Future<Map<String, dynamic>?> joinRoom({
    required String code,
    required String guestId,
    required String guestName,
    required String guestLang,
  }) async {
    final room =
        await _db.from('rooms').select().eq('code', code).maybeSingle();
    if (room == null) return null;
    await _db.from('rooms').update({
      'guest_id': guestId,
      'guest_name': guestName,
      'guest_lang': guestLang,
    }).eq('code', code);
    // Return in the shape the state expects: {host: {lang: ...}}
    return {
      'host': {
        'id': room['host_id'],
        'name': room['host_name'],
        'lang': room['host_lang'],
      }
    };
  }

  /// Send a translated voice message to the room
  Future<void> sendMessage(String code, RoomMessage msg) async {
    await _db.from('room_messages').insert(msg.toRow(code));
  }

  /// Realtime stream of room messages
  Stream<List<RoomMessage>> messages(String code) {
    return _db
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_code', code)
        .order('ts')
        .map((rows) =>
            rows.map((r) => RoomMessage.fromRow(r)).toList());
  }

  /// Realtime stream of room state (to detect the other party joining)
  Stream<Map<dynamic, dynamic>?> roomState(String code) {
    return _db
        .from('rooms')
        .stream(primaryKey: ['code'])
        .eq('code', code)
        .map((rows) {
      if (rows.isEmpty) return null;
      final r = rows.first;
      return {
        'host': {'id': r['host_id'], 'name': r['host_name'], 'lang': r['host_lang']},
        'guest': r['guest_id'] == null
            ? null
            : {
                'id': r['guest_id'],
                'name': r['guest_name'],
                'lang': r['guest_lang']
              },
      };
    });
  }

  /// Leave/close the room
  Future<void> leaveRoom(String code, {bool isHost = false}) async {
    if (isHost) {
      await _db.from('rooms').delete().eq('code', code);
    } else {
      await _db.from('rooms').update({
        'guest_id': null,
        'guest_name': null,
        'guest_lang': null,
      }).eq('code', code);
    }
  }
}
