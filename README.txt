NEXOR Orders - Compile fixes for Products & Purchases

Merge this package's lib/ directory into C:\nexor_orders and replace the matching files.

Fixed:
- Products page product card now reads the exchange rate from the product model (no out-of-scope _catalog reference).
- SwitchListTile uses activeThumbColor instead of deprecated activeColor.
- ProductCatalog includes applyPurchaseReceipt, so receiving a purchase updates stock and weighted-average purchase cost.
- Purchase receipt preserves USD as the product reference cost and recalculates its SYP equivalent using the current central exchange rate. Each purchase invoice still keeps its historical exchange-rate snapshot.
- Added braces to the two flow-control statements reported by analyzer.

Files:
- lib/features/products/products_page.dart
- lib/features/products/product_catalog.dart
- lib/features/purchases/purchases_page.dart

Run:
  dart format lib/features/products lib/features/purchases
  flutter analyze
  flutter run -d chrome

Note: This remains an in-memory demo implementation; data does not persist after app restart.
