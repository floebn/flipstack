import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Was die Oberfläche nach einem Kauf- oder Wiederherstellungsversuch meldet.
enum PurchaseNotice {
  none,
  bought,
  restored,
  nothingToRestore,
  pending,
  failed,
}

/// Einmaliger Kauf "Werbefrei" hinter einer Schnittstelle. Der Kauf entfernt
/// die Vollbildwerbung zwischen den Runden; freiwillige, belohnte Werbung
/// bleibt. Er bringt keinen Spielvorteil.
abstract class PurchaseService extends ChangeNotifier {
  /// Der Kauf liegt vor (aus dem Store oder aus dem lokalen Zwischenspeicher).
  bool get adsRemoved;

  /// Preis mit Währung, wie der Store ihn liefert, oder `null`, solange der
  /// Kauf nicht angeboten werden kann (kein Netz, Produkt nicht gefunden).
  String? get price;

  /// Ein Kauf oder eine Wiederherstellung läuft gerade.
  bool get busy;

  /// Ergebnis des letzten Versuchs, für eine kurze Rückmeldung.
  PurchaseNotice get notice;

  Future<void> load();
  Future<void> buyRemoveAds();
  Future<void> restore();
  void clearNotice();
}

/// Kein Kauf möglich (Tests, Autoplay, Plattformen ohne Store).
class NoPurchases extends PurchaseService {
  @override
  bool get adsRemoved => false;
  @override
  String? get price => null;
  @override
  bool get busy => false;
  @override
  PurchaseNotice get notice => PurchaseNotice.none;
  @override
  Future<void> load() async {}
  @override
  Future<void> buyRemoveAds() async {}
  @override
  Future<void> restore() async {}
  @override
  void clearNotice() {}
}

/// Platzhalter zum Prüfen der Oberfläche ohne Store
/// (`--dart-define=FS_IAP=fake`). Nichts wird gespeichert.
class FakePurchases extends PurchaseService {
  bool _owned = false, _busy = false;
  PurchaseNotice _notice = PurchaseNotice.none;

  @override
  bool get adsRemoved => _owned;
  @override
  String? get price => '2,99 €';
  @override
  bool get busy => _busy;
  @override
  PurchaseNotice get notice => _notice;
  @override
  Future<void> load() async {}

  Future<void> _finish(bool owned, PurchaseNotice notice) async {
    _busy = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _busy = false;
    _owned = owned;
    _notice = notice;
    notifyListeners();
  }

  @override
  Future<void> buyRemoveAds() => _finish(true, PurchaseNotice.bought);

  @override
  Future<void> restore() => _finish(
    _owned,
    _owned ? PurchaseNotice.restored : PurchaseNotice.nothingToRestore,
  );

  @override
  void clearNotice() => _notice = PurchaseNotice.none;
}

/// Kauf über den App Store bzw. Google Play.
///
/// Der Freischaltstatus wird lokal gemerkt, damit "Werbefrei" auch ohne Netz
/// sofort gilt. Nach einer Neuinstallation holt "Käufe wiederherstellen" ihn
/// aus dem Store zurück. Zahlungsdaten sieht die App nie.
class StorePurchases extends PurchaseService {
  StorePurchases({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  /// Kennung des Produkts in den Stores. Sie lässt sich dort nie ändern.
  static String get productId =>
      Platform.isIOS ? 'com.floebn.flipstack.remove_ads' : 'remove_ads';

  static const _prefKey = 'ads_removed';

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  bool _owned = false, _busy = false, _restoring = false;
  PurchaseNotice _notice = PurchaseNotice.none;

  @override
  bool get adsRemoved => _owned;
  @override
  String? get price => _product?.price;
  @override
  bool get busy => _busy;
  @override
  PurchaseNotice get notice => _notice;

  @override
  Future<void> load() async {
    try {
      _owned =
          (await SharedPreferences.getInstance()).getBool(_prefKey) ?? false;
      notifyListeners();
    } catch (_) {}
    try {
      _sub = _store.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('FLIPSTACK kauf: $e'),
      );
      if (!await _store.isAvailable()) {
        debugPrint('FLIPSTACK kauf: Store nicht erreichbar');
        return;
      }
      final response = await _store.queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        debugPrint(
          'FLIPSTACK kauf: Produkt $productId nicht gefunden '
          '(${response.error?.message ?? 'im Store nicht angelegt?'})',
        );
        return;
      }
      _product = response.productDetails.first;
      debugPrint('FLIPSTACK kauf: bereit, Preis ${_product!.price}');
      notifyListeners();
    } catch (e) {
      debugPrint('FLIPSTACK kauf: Laden fehlgeschlagen: $e');
    }
  }

  Future<void> _setOwned() async {
    _owned = true;
    try {
      await (await SharedPreferences.getInstance()).setBool(_prefKey, true);
    } catch (_) {}
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          _notice = PurchaseNotice.pending;
        case PurchaseStatus.purchased:
          await _setOwned();
          _busy = false;
          _notice = PurchaseNotice.bought;
        case PurchaseStatus.restored:
          await _setOwned();
          _busy = false;
          _notice = PurchaseNotice.restored;
        case PurchaseStatus.error:
          debugPrint('FLIPSTACK kauf: Fehler ${p.error?.message}');
          _busy = false;
          _notice = PurchaseNotice.failed;
        case PurchaseStatus.canceled:
          _busy = false;
          _notice = PurchaseNotice.none;
      }
      // Dem Store bestätigen, dass der Kauf angekommen ist; sonst wird er
      // erstattet (Android) bzw. immer wieder gemeldet (iOS).
      if (p.pendingCompletePurchase) {
        try {
          await _store.completePurchase(p);
        } catch (e) {
          debugPrint('FLIPSTACK kauf: Bestätigung fehlgeschlagen: $e');
        }
      }
    }
    notifyListeners();
  }

  @override
  Future<void> buyRemoveAds() async {
    final product = _product;
    if (product == null || _busy || _owned) return;
    _busy = true;
    _notice = PurchaseNotice.none;
    notifyListeners();
    try {
      await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      debugPrint('FLIPSTACK kauf: $e');
      _busy = false;
      _notice = PurchaseNotice.failed;
      notifyListeners();
    }
  }

  @override
  Future<void> restore() async {
    if (_busy || _restoring) return;
    _restoring = true;
    _busy = true;
    _notice = PurchaseNotice.none;
    notifyListeners();
    try {
      await _store.restorePurchases();
      // Gefundene Käufe kommen über den Strom. Kommt nichts, gab es nichts.
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!_owned && _notice == PurchaseNotice.none) {
        _notice = PurchaseNotice.nothingToRestore;
      }
    } catch (e) {
      debugPrint('FLIPSTACK kauf: Wiederherstellen fehlgeschlagen: $e');
      _notice = PurchaseNotice.failed;
    }
    _busy = false;
    _restoring = false;
    notifyListeners();
  }

  @override
  void clearNotice() => _notice = PurchaseNotice.none;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
