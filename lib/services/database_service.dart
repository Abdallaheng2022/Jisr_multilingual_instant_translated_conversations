import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import '../models/app_user.dart';
import '../models/correction.dart';
import '../models/learning.dart';

/// خدمة قاعدة البيانات (Firestore) + تخزين الصوت (Storage).
/// تحفظ بيانات المستخدم وتصحيحاته، وتطبّق معايير الجودة.
class DatabaseService {
  late final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── المستخدمون ──
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// حفظ/تحديث مستخدم (يُنشأ عند أول دخول)
  Future<void> saveUser(AppUser user) async {
    await _users.doc(user.uid).set(user.toJson(), SetOptions(merge: true));
  }

  /// جلب بيانات مستخدم
  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromJson(doc.data()!);
  }

  /// تحديث حقول المستخدم (اشتراك، عدّاد، موافقة التدريب)
  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).update(fields);
  }

  /// تدفّق بيانات المستخدم (لحظي)
  Stream<AppUser?> userStream(String uid) =>
      _users.doc(uid).snapshots().map(
          (d) => d.exists ? AppUser.fromJson(d.data()!) : null);

  // ── التصحيحات ──
  CollectionReference<Map<String, dynamic>> get _corrections =>
      _db.collection('corrections');

  /// حفظ تصحيح: يرفع الصوت، يطبّق المعايير، ويخزّن العيّنة.
  /// يُحفظ الصوت للتدريب فقط إذا وافق المستخدم (contributeToTraining).
  Future<Correction> saveCorrection({
    required String userId,
    required String originalText,
    required String correctedText,
    required String language,
    required double audioDuration,
    String? audioLocalPath,
    bool contributeToTraining = false,
    double audioClarity = 0.7,
  }) async {
    final id = _corrections.doc().id;

    // ارفع الصوت فقط بموافقة المستخدم (للتدريب)
    String? audioUrl;
    if (contributeToTraining &&
        audioLocalPath != null &&
        File(audioLocalPath).existsSync()) {
      final ref = _storage.ref('training_audio/$language/$id.wav');
      await ref.putFile(File(audioLocalPath));
      audioUrl = await ref.getDownloadURL();
    }

    // طبّق المعايير التلقائية
    final correction = CorrectionCriteria.evaluate(
      id: id,
      userId: userId,
      originalText: originalText,
      correctedText: correctedText,
      language: language,
      audioDuration: audioDuration,
      audioPath: audioUrl,
      audioClarity: audioClarity,
    );

    // خزّن العيّنة (بيانات التدريب تُحفظ فقط مع الموافقة)
    await _corrections.doc(id).set(correction.toJson());
    return correction;
  }

  /// تصحيحات المستخدم (لعرض تاريخه/تعديلاته)
  Future<List<Correction>> userCorrections(String userId,
      {int limit = 50}) async {
    final snap = await _corrections
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => Correction.fromJson(d.data())).toList();
  }

  /// إحصاء العيّنات المقبولة للتدريب (لمعرفة متى نبدأ التدريب)
  Future<int> approvedCount(String language) async {
    final snap = await _corrections
        .where('language', isEqualTo: language)
        .where('status', isEqualTo: 'approved')
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ── عبارات التعلّم ──
  CollectionReference<Map<String, dynamic>> _phrases(String userId) =>
      _users.doc(userId).collection('learned_phrases');

  /// حفظ عبارة تعلّم (بعد دورة ترجمة تستحق)
  Future<void> saveLearnedPhrase(String userId, LearnedPhrase phrase) async {
    await _phrases(userId).doc(phrase.id).set(phrase.toJson());
  }

  /// جلب عبارات المستخدم المتعلّمة
  Future<List<LearnedPhrase>> learnedPhrases(String userId,
      {int limit = 100}) async {
    final snap = await _phrases(userId)
        .orderBy('learnedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => LearnedPhrase.fromJson(d.data())).toList();
  }

  /// تحديث عبارة (مراجعة/إتقان)
  Future<void> updatePhrase(
      String userId, String phraseId, Map<String, dynamic> fields) async {
    await _phrases(userId).doc(phraseId).update(fields);
  }

  /// حذف عبارة
  Future<void> deletePhrase(String userId, String phraseId) async {
    await _phrases(userId).doc(phraseId).delete();
  }

  // ── ملخصات تعلّم اللغة (للمرحلة القادمة) ──
  CollectionReference<Map<String, dynamic>> get _summaries =>
      _db.collection('learning_summaries');

  /// حفظ ملخص محادثة (كلمات/عبارات تعلّمها المستخدم)
  Future<void> saveLearningSummary({
    required String userId,
    required String sourceLang,
    required String targetLang,
    required List<String> phrases,
  }) async {
    await _summaries.add({
      'userId': userId,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
      'phrases': phrases,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
