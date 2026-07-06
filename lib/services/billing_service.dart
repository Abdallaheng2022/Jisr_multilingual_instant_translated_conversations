import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

/// خدمة الدفع عبر Google Play (in_app_purchase).
///
/// معرّفات المنتجات يجب إنشاؤها في Google Play Console كاشتراكات:
///   - jisr_monthly_10  (اشتراك شهري)
///   - jisr_yearly_100  (اشتراك سنوي)
class BillingService {
  BillingService();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  static const productIds = {'jisr_monthly_10', 'jisr_yearly_100'};

  List<ProductDetails> products = [];
  bool available = false;

  /// نداء يُستدعى عند نجاح شراء/استرجاع اشتراك
  void Function(String productId)? onPurchaseSuccess;
  void Function(String message)? onError;

  Future<void> init() async {
    available = await _iap.isAvailable();
    if (!available) return;

    // الاستماع لتحديثات الشراء
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => onError?.call('خطأ في متجر Play: $e'),
    );

    // تحميل تفاصيل المنتجات
    final resp = await _iap.queryProductDetails(productIds);
    products = resp.productDetails;

    // استرجاع المشتريات السابقة (مهم للاشتراكات على أجهزة جديدة)
    await _iap.restorePurchases();
  }

  ProductDetails? productFor(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// بدء شراء اشتراك
  Future<void> buy(String productId) async {
    final product = productFor(productId);
    if (product == null) {
      onError?.call('المنتج غير متوفر حالياً');
      return;
    }
    final param = PurchaseParam(productDetails: product);
    // للاشتراكات نستخدم buyNonConsumable (Google يديرها كاشتراك متجدد)
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() => _iap.restorePurchases();

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          onPurchaseSuccess?.call(p.productID);
          if (p.pendingCompletePurchase) {
            _iap.completePurchase(p);
          }
          break;
        case PurchaseStatus.error:
          onError?.call(p.error?.message ?? 'فشل الشراء');
          break;
        case PurchaseStatus.canceled:
          // ألغى المستخدم — لا حاجة لرسالة
          break;
        case PurchaseStatus.pending:
          // قيد المعالجة
          break;
      }
    }
  }

  void dispose() => _sub?.cancel();
}
