import 'dart:io';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// رسالة صوتية مترجمة داخل غرفة (بالتناوب بين طرفين).
class RoomMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String originalText;
  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final String? audioUrl; // الصوت المُستنسخ (رابط)
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

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'originalText': originalText,
        'translatedText': translatedText,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'audioUrl': audioUrl,
        'timestamp': timestamp,
      };

  factory RoomMessage.fromMap(String id, Map<dynamic, dynamic> m) => RoomMessage(
        id: id,
        senderId: m['senderId'] ?? '',
        senderName: m['senderName'] ?? '',
        originalText: m['originalText'] ?? '',
        translatedText: m['translatedText'] ?? '',
        sourceLang: m['sourceLang'] ?? '',
        targetLang: m['targetLang'] ?? '',
        audioUrl: m['audioUrl'],
        timestamp: m['timestamp'] ?? 0,
      );
}

/// خدمة الغرف: تنشئ/تنضم لغرفة عبر رمز، وتتبادل الرسائل عبر Firebase.
/// Firebase Realtime Database يعمل كخادم إشارات يربط الهاتفين.
class RoomService {
  late final FirebaseDatabase _db = FirebaseDatabase.instance;
  late final FirebaseStorage _storage = FirebaseStorage.instance;

  DatabaseReference _room(String code) => _db.ref('rooms/$code');

  /// رفع صوت مُستنسخ للغرفة، يعيد رابطاً يصل للطرف الآخر
  Future<String> uploadAudio(String localPath, String code) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref('room_audio/$code/$id.wav');
    await ref.putFile(File(localPath));
    return await ref.getDownloadURL();
  }

  /// إنشاء رمز غرفة فريد (6 أحرف)
  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // بلا أحرف ملتبسة
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// إنشاء غرفة جديدة
  Future<void> createRoom({
    required String code,
    required String hostId,
    required String hostName,
    required String hostLang,
  }) async {
    await _room(code).set({
      'host': {'id': hostId, 'name': hostName, 'lang': hostLang},
      'createdAt': ServerValue.timestamp,
      'active': true,
    });
  }

  /// الانضمام لغرفة موجودة (يعيد بيانات المضيف، أو null إن لم توجد)
  Future<Map<dynamic, dynamic>?> joinRoom({
    required String code,
    required String guestId,
    required String guestName,
    required String guestLang,
  }) async {
    final snap = await _room(code).get();
    if (!snap.exists) return null;
    await _room(code).child('guest').set({
      'id': guestId,
      'name': guestName,
      'lang': guestLang,
    });
    return snap.value as Map<dynamic, dynamic>?;
  }

  /// إرسال رسالة صوتية مترجمة للغرفة
  Future<void> sendMessage(String code, RoomMessage msg) async {
    await _room(code).child('messages').push().set(msg.toMap());
  }

  /// تدفّق رسائل الغرفة (لحظي — يظهر للطرفين)
  Stream<List<RoomMessage>> messages(String code) {
    return _room(code).child('messages').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <RoomMessage>[];
      final list = data.entries
          .map((e) => RoomMessage.fromMap(e.key, e.value))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  /// تدفّق حالة الغرفة (لمعرفة انضمام الطرف الآخر)
  Stream<Map<dynamic, dynamic>?> roomState(String code) {
    return _room(code).onValue.map(
        (event) => event.snapshot.value as Map<dynamic, dynamic>?);
  }

  /// مغادرة/إغلاق الغرفة
  Future<void> leaveRoom(String code, {bool isHost = false}) async {
    if (isHost) {
      await _room(code).remove(); // المضيف يغلق الغرفة
    } else {
      await _room(code).child('guest').remove();
    }
  }
}
