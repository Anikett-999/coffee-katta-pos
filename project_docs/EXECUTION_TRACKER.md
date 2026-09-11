# 📋 COFFEE KATTA POS — MASTER EXECUTION TRACKER

**Target System**: Coffee Katta Flagship Cafe, Near Rajiv Gandhi Chowk, Latur, Maharashtra 413512  
**Branch**: `feature/coffee-katta-pos`  
**Protocol**: Strict Phased-Gate Protocol (1 Phase per gate)  
**Git Remote**: Disconnected from Shree Rajmandir; targeted to `https://github.com/Anikett-999/coffee-katta-pos.git`  
**Firebase Backend**: `coffee-katta-pos` (Location: `asia-south1` Mumbai, Firestore & Auth Active)

---

## 🛡️ Cloud & Repo Isolation Status
- [x] Disconnect from `https://github.com/Anikett-999/shreerajmandir-v2.git`
- [x] Target remote origin set to `https://github.com/Anikett-999/coffee-katta-pos.git`
- [x] Create dedicated GCP/Firebase project: `coffee-katta-pos`
- [x] Enable Firestore & Identity Toolkit APIs
- [x] Create Firestore Native DB in `asia-south1` (Mumbai, India)
- [x] Register Android app (`com.coffeekatta.pos`) & generate new `google-services.json`
- [x] Register Web app & generate new `firebase_options.dart`
- [x] Deploy initial `firestore.rules` to `coffee-katta-pos`

## 🚦 Phase Tracking

### [X] Phase 1: Brand Identity & Visual Re-theming
- [x] Create feature branch `feature/coffee-katta-pos`
- [x] Update `pubspec.yaml` (name: `coffee_katta_pos`, cafe description)
- [x] Update `android/app/src/main/AndroidManifest.xml` (label: `Coffee Katta POS`)
- [x] Update `windows/runner/main.cpp` (window title: `Coffee Katta POS — Latur`)
- [x] Update `web/index.html` & `web/manifest.json` (title: `Coffee Katta POS`)
- [x] Update `lib/main.dart` (title: `Coffee Katta POS`, `CoffeeKattaPOSApp`)
- [x] Update `lib/core/app_theme.dart` (Warm Cafe Palette: Espresso Brown `#4A2C11`, Caramel `#8C5835`, Latte Cream `#F9F6F0`, Amber `#D4A373`)
- [x] Update internal package imports to `package:coffee_katta_pos/`
- [x] Verification: `dart analyze` passes with 0 errors
- [x] Gate 1 Review: Pending User Approval

---

### [X] Phase 2: Database Multi-Tenancy Scoping
- [x] Re-scope Firestore business ID to `'coffee_katta'` in 8 service & provider files:
  - `billing_service.dart`, `kot_service.dart`, `menu_service.dart`, `table_service.dart`
  - `seed_data_service.dart`, `branch_service.dart`, `analytics_service.dart`, `branch_provider.dart`
- [x] Set default branch to `'latur_main'`
- [x] Verified zero touch / zero harm to `/businesses/rajmandir_main/...` (0 occurrences in lib/)
- [x] Root & Branch Firestore document initialization (`/businesses/coffee_katta/branches/latur_main`)
- [x] 20 Tables (T1–T20) across Indoor AC (T1-T8), Outdoor Patio (T9-T14), and Katta High Tops (T15-T20)
- [x] Global sequence counters initialized (`kotCounter: 1000`, `billCounter: 1000`)
- [x] Automated test suite `test/phase2_database_scope_test.dart` (PASSED)
- [x] Gate 2 Review: Completed & Verified

---

### [X] Phase 3: Menu & Categories Seed Data
- [x] Replace `assets/data/menu_items.json` with 45-item Coffee Katta cafe catalog
- [x] 6 official Menu Categories:
  - Cold Coffee & Shakes (10 items)
  - Hot Beverages (10 items)
  - Sandwiches & Toasts (8 items)
  - Burgers & Wraps (6 items)
  - Snacks & Fries (6 items)
  - Pizzas & Combos (5 items)
- [x] Update `SeedDataService` to persist beverage/food variants
- [x] Write & execute automated Firestore seeder `scripts/seed_coffee_katta_data.py`:
  - Cleaned up old placeholder items
  - Seeded 45 items with Indian Rupee (₹) prices and size variant options
- [x] Automated test suite verifying 45 items and 6 categories (PASSED)
- [x] Gate 3 Review: Completed & Verified

---

### [X] Phase 4: Waiter Screen Beverage Customizer
- [x] Unlocked Rule #42 in `lib/presentation/screens/waiter/order_screen.dart`
- [x] Implemented Beverage Customizer bottom sheet modal:
  - Cup size selection with dynamic price parsing (`Regular (250ml):0`, `Large (350ml):30`, etc.)
  - Sugar level quick buttons (`No Sugar`, `Less Sugar`, `Normal Sugar`)
  - Optional Add-on chips (`Extra Ice Cream ₹30`, `Extra Espresso Shot ₹30`, `Chocolate Syrup ₹20`, `Extra Milk ₹15`)
  - Special instructions text field
  - Live unit price calculator and action button (`Add to Order • ₹...`)
- [x] Implemented Food Variant bottom sheet modal for non-beverage categories (Pizzas, Fries, etc.)
- [x] Upgraded `CartItem` and `CartNotifier` to store and calculate based on custom unit prices (`final double price`)
- [x] Updated KOT dispatch in `_sendToKitchen` to map customized prices, variants, and notes into `KOTItem`
- [x] Preserved distinct line items when same item is ordered with different customization notes (e.g. No Sugar vs Normal Sugar)
- [x] Automated test suite `test/phase4_beverage_customizer_test.dart` & `test/cart_notifier_test.dart` (27/27 tests passed)
- [x] Gate 4 Review: Ready for User Verification

---

### [ ] Phase 5: Thermal Receipt & RawBT Print Engine (HOLD)
- [ ] Update 80mm ESC/POS header with Coffee Katta branding & Latur address
- [ ] Include variant info on KOT kitchen slips
- [ ] Implement Counter terminal auto-spooler for unprinted KOTs (`isPrinted: false`)

---

### [ ] Phase 6: Billing Math, 5% GST & Split Payment (HOLD)
- [ ] Implement 5% restaurant GST (SAC 996331) with 1-paisa balancing
- [ ] Add Cashier toggle: `[ GST Bill (5%) ]` vs `[ Non-GST / Retail Bill ]`
- [ ] Implement multi-tender Split-Payment (Cash + UPI) with reconciliation

---

### [ ] Phase 7: Build, Run & Verification Protocol (HOLD)
- [ ] Final compilation and smoke testing
- [ ] Windows desktop & Android build verification
