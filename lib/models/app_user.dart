/// مستخدم مسجّل الدخول (عبر Google)
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  // حالة الاشتراك (تُحفظ في Firestore)
  final bool subscribed;
  final String plan; // 'free' | 'monthly' | 'yearly'
  final int usedMessages;

  // موافقة المساهمة في تحسين النموذج (خصوصية)
  final bool contributeToTraining;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.subscribed = false,
    this.plan = 'free',
    this.usedMessages = 0,
    this.contributeToTraining = false,
  });

  AppUser copyWith({
    bool? subscribed,
    String? plan,
    int? usedMessages,
    bool? contributeToTraining,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        subscribed: subscribed ?? this.subscribed,
        plan: plan ?? this.plan,
        usedMessages: usedMessages ?? this.usedMessages,
        contributeToTraining: contributeToTraining ?? this.contributeToTraining,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'subscribed': subscribed,
        'plan': plan,
        'usedMessages': usedMessages,
        'contributeToTraining': contributeToTraining,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        uid: j['uid'] as String,
        email: j['email'] as String?,
        displayName: j['displayName'] as String?,
        photoUrl: j['photoUrl'] as String?,
        subscribed: j['subscribed'] as bool? ?? false,
        plan: j['plan'] as String? ?? 'free',
        usedMessages: j['usedMessages'] as int? ?? 0,
        contributeToTraining: j['contributeToTraining'] as bool? ?? false,
      );
}
