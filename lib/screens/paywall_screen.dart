import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: JisrLogo(size: 56)),
              const SizedBox(height: 20),
              const Text('اشترك في جسر Pro',
                  style: AppText.h1, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'ترجمة صوتية غير محدودة، استنساخ صوتك بكل اللغات،\nوالغرفة الصوتية اللايف',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ...kPlans.map((p) => _planCard(context, p, app)),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => app.restorePurchases(),
                  child: Text('استرجاع عملية شراء سابقة',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'يتجدد الاشتراك تلقائياً. يمكنك الإلغاء في أي وقت من متجر Google Play.',
                style: TextStyle(color: AppColors.faint, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planCard(BuildContext context, SubscriptionPlan plan, AppState app) {
    final highlighted = plan.highlighted;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: highlighted ? AppColors.amber : AppColors.border,
          width: highlighted ? 2 : 0.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                gradient: plan.accent,
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(
                plan.type == PlanType.yearly
                    ? Icons.workspace_premium_rounded
                    : Icons.bolt_rounded,
                color: AppColors.bg,
                size: 24),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(plan.title, style: AppText.h2),
              if (highlighted) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.amberSoft(0.16),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('الأفضل قيمة',
                      style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ]),
            Text(plan.period, style: AppText.caption),
          ]),
          const Spacer(),
          Text(plan.price,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 18),
        ...plan.features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(children: [
                Icon(Icons.check_circle_rounded,
                    color: highlighted ? AppColors.amber : AppColors.teal,
                    size: 18),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(f,
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 14))),
              ]),
            )),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _subscribe(context, plan, app),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
                gradient: plan.accent,
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Center(
              child: Text('اشترك الآن',
                  style: TextStyle(
                      color: AppColors.bg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _subscribe(
      BuildContext context, SubscriptionPlan plan, AppState app) async {
    await app.buyPlan(plan);
    // نتيجة الشراء تصل عبر billing.onPurchaseSuccess وتحدّث الحالة.
    if (context.mounted && app.subscribed) {
      Navigator.pop(context);
    }
  }
}
