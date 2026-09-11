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

### [ ] Phase 2: Database Multi-Tenancy Scoping (HOLD)
- [ ] Re-scope Firestore business ID to `'coffee_katta'` in 8 service & provider files
- [ ] Set default branch to `'latur_main'`
- [ ] Verify zero touch / zero harm to `/businesses/rajmandir_main/...`

---

### [ ] Phase 3: Menu & Categories Seed Data (HOLD)
- [ ] Replace `assets/data/menu_items.json` with 45-item Coffee Katta catalog
- [ ] Update `SeedDataService` to persist variants

---

### [ ] Phase 4: Waiter Screen Beverage Customizer (HOLD)
- [ ] Unlock Rule #42 in `lib/presentation/screens/waiter/order_screen.dart`
- [ ] Implement Beverage Customizer bottom sheet (cup sizes, sugar levels, add-on chips)
- [ ] Map customizer selections into `KOTItem` and `CartItem`

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
