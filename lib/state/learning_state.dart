import 'package:flutter/foundation.dart';

import '../models/learning.dart';
import '../services/database_service.dart';

/// حالة قسم تعلّم اللغة: تحميل وإدارة العبارات المتعلّمة.
class LearningState extends ChangeNotifier {
  LearningState({required this.db});

  final DatabaseService db;

  List<LearnedPhrase> phrases = [];
  bool loading = false;
  String? _userId;

  int get total => phrases.length;
  int get masteredCount => phrases.where((p) => p.mastered).length;

  /// تحميل عبارات المستخدم
  Future<void> load(String userId) async {
    _userId = userId;
    loading = true;
    notifyListeners();
    try {
      phrases = await db.learnedPhrases(userId);
    } catch (e) {
      debugPrint('فشل تحميل العبارات: $e');
      phrases = [];
    }
    loading = false;
    notifyListeners();
  }

  /// وضع علامة إتقان
  Future<void> toggleMastered(LearnedPhrase phrase) async {
    if (_userId == null) return;
    phrase.mastered = !phrase.mastered;
    notifyListeners();
    await db.updatePhrase(_userId!, phrase.id, {'mastered': phrase.mastered});
  }

  /// زيادة عدّاد المراجعة
  Future<void> markReviewed(LearnedPhrase phrase) async {
    if (_userId == null) return;
    phrase.reviewCount++;
    notifyListeners();
    await db.updatePhrase(
        _userId!, phrase.id, {'reviewCount': phrase.reviewCount});
  }

  /// حذف عبارة
  Future<void> remove(LearnedPhrase phrase) async {
    if (_userId == null) return;
    phrases.remove(phrase);
    notifyListeners();
    await db.deletePhrase(_userId!, phrase.id);
  }
}
