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

### [X] Phase 3: Menu & Categories Seed Data (OFFICIAL VERIFIED CATALOG)
- [x] Replace `assets/data/menu_items.json` with **43 official Coffee Katta items** from verified physical booklet
- [x] **9 Official Menu Categories** seeded into Firestore:
  - 1. `Katta Coffee` (9 items)
  - 2. `Hot Beverages` (8 items)
  - 3. `Freak Shakes` (5 items)
  - 4. `Katta Frappé` (4 items)
  - 5. `Polare Ice Tea` (2 items)
  - 6. `Katta Starter` (6 items, Veg)
  - 7. `On the Sides` (3 items, Veg)
  - 8. `Katta Starter (Non Veg)` (4 items, Non-Veg)
  - 9. `On the Sides (Non Veg)` (2 items, Non-Veg)
- [x] Automated Firestore seeder `scripts/seed_coffee_katta_data.py`:
  - Cleaned up old placeholder categories & items across all active branches (`branch_001` & `latur_main`)
  - Seeded 43 items with Indian Rupee (₹) prices, official category mappings, and `isVeg` tags
  - Verified multi-branch database synchronization: 9 categories, 43 items, 20 tables in both branches
- [x] Automated test suite verifying 43 items and 9 categories (PASSED)
- [x] Gate 3 Review: Completed & Verified

---

### [X] Phase 4: Waiter Screen Customizer & Category Profiles
- [x] Unlocked Rule #42 in `lib/presentation/screens/waiter/order_screen.dart`
- [x] Implemented **Category Customization Profiles** tailored to item type:
  - **☕ Coffee Profile** (`Katta Coffee`, `Hot Beverages`): Sugar Level (`No Sugar`, `Less Sugar`, `Normal Sugar`), Coffee Add-ons (`+ Extra Espresso Shot ₹30`, `+ Extra Milk / Cream ₹15`, `+ Extra Ice Cream ₹30`, `+ Whipped Cream ₹25`)
  - **🥤 Shakes & Frappé Profile** (`Freak Shakes`, `Katta Frappé`, `Polare Ice Tea`): Ice / Chill Level (`Normal Ice`, `Less Ice`, `Extra Chilled`), Dessert Add-ons (`+ Extra Ice Cream Scoop ₹30`, `+ Whipped Cream ₹25`, `+ Chocolate Drizzle ₹20`)
  - **🍟 Food & Starters Profile** (`Katta Starter`, `On the Sides`, `Katta Starter (Non Veg)`, `On the Sides (Non Veg)`): Prep Style (`Normal`, `Extra Crispy`, `Less Spicy`), Food Add-ons (`+ Extra Cheese Dip ₹25`, `+ Peri Peri Seasoning ₹15`, `+ Mayo Dip ₹15`)
- [x] Added Veg / Non-Veg dietary badges (🟢 Veg, 🔴 Non-Veg) on item cards and customizer header
- [x] All currency representations strictly locked to Indian Rupee (`₹`), strictly no `$`
- [x] Upgraded `CartItem` and `CartNotifier` to store and calculate based on custom unit prices
- [x] Cart UI compact cafe redesign:
  - Compacted card sizes (`maxCrossAxisExtent: 155`, padding 6px, removed redundant category subtitle)
  - Deducted Cart footer total text size (20pt, label 15pt)
  - Renamed buttons to `SEND` and `SEND & PRINT` with unified cafe espresso brown styling (`AppTheme.maroon`)
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
