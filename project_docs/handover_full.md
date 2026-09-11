<USER_REQUEST>
# COFFEE KATTA POS — ENGINEERING HANDOVER & EXECUTION MANUAL
## कॉफी कट्टा POS — डेव्हलपर हँडओव्हर आणि अंमलबजावणी मार्गदर्शक
**Target System**: Coffee Katta Flagship Cafe, Near Rajiv Gandhi Chowk, Latur, Maharashtra 413512  
**Base Codebase**: `e:\projects\CoffeeKatta\ShreeRajmandirV2` (Flutter 3.16+ / Dart 3.2+)  
**Backend**: Google Cloud Firestore (`/businesses/coffee_katta/branches/latur_main`)  
**Currency**: 100% Indian Rupees (`₹`) and Paise (`पैसे`)  
**Execution Strategy**: **REUSE & SURGICAL ADAPTATION (85% Code Retention, 15% Targeted Upgrade)**

---

## 1. Executive Directive for the Incoming Engineer / Agent
You are receiving this project to quickly adapt the existing, battle-tested **Shree Rajmandir V2 POS** codebase into **Coffee Katta POS**.
- **DO NOT build from scratch**. The existing app already has full offline disk caching, Riverpod state management, table layout, PIN authentication, ESC/POS thermal printing, and day-end analytics.
- **DO NOT write long theoretical documents**. Your sole objective is to execute the **7 Concrete Phases** below directly on the codebase.
- **Rule #42 is OVERRIDDEN**: You are explicitly authorized to edit `lib/presentation/screens/waiter/order_screen.dart` to add the beverage customizer (cup sizes, sugar levels, add-ons).
- **Locked Printing Architecture**: **Method A (Central Counter Hub / Cloud Spooler)**. Waiters fire KOTs to Firestore (`isPrinted: false`); the Counter terminal automatically picks them up and prints them via **RawBT** (Android intent) or Direct USB cable. Waiter phones do NOT pair with printers!

---

## 2. Phase 1: Brand Identity & Visual Re-theming (⏱️ ~2 Hours)

### 1.1 App Name & Metadata
Update the app display name from "Shree Rajmandir" to "Coffee Katta POS" in these 4 files:

1. **`pubspec.yaml`**:
   ```yaml
   name: coffee_katta_pos
   description: "Coffee Katta Specialty Cafe POS & Kitchen Management System"
   ```
2. **`android/app/src/main/AndroidManifest.xml`**:
   ```xml
   <application
       android:label="Coffee Katta POS"
       android:name="${applicationName}"
       android:icon="@mipmap/ic_launcher">
   ```
3. **`windows/runner/main.cpp`**:
   ```cpp
   window.Create(L"Coffee Katta POS — Latur", origin, size);
   ```
4. **`web/index.html`**:
   ```html
   <title>Coffee Katta POS</title>
   ```
5. **`lib/main.dart`**:
   ```dart
   // Line 43:
   title: 'Coffee Katta POS',
   ```

### 1.2 Color Palette Re-Theming in `lib/core/app_theme.dart`
Replace the Shree Rajmandir Royal Maroon (`#650012`) with the Coffee Katta **Warm Specialty Cafe Palette**:

```dart
class AppTheme {
  // Brand Identity Colors (Coffee Katta Warm Palette)
  static const Color espressoBrown = Color(0xFF4A2C11); // Deep Espresso
  static const Color warmCaramel  = Color(0xFF8C5835); // Warm Coffee/Caramel
  static const Color latteCream    = Color(0xFFF9F6F0); // Warm Latte Cream Background
  static const Color warmAmber     = Color(0xFFD4A373); // Amber Accent
  static const Color softGrey      = Color(0xFFE8ECEF);
  
  // Backwards-Compatible Aliases (Keeps existing screens compile-clean)
  static const Color maroon        = espressoBrown; // Remaps old maroon to espresso
  static const Color cream         = latteCream;
  static const Color deepGreen     = Color(0xFF2D6A4F); // Rich Emerald (Available)
  static const Color darkBg        = Color(0xFF1E1E1E);
  
  // Table Status Colors
  static const Color statusAvailable = Color(0xFF2D6A4F); // Green (रिकामे टेबल)
  static const Color statusOccupied  = Color(0xFFD97706); // Warm Amber (सुरू टेबल)
  static const Color statusBilling   = Color(0xFF78350F); // Deep Brown (बिलिंग)
  
  static const Color successGreen  = statusAvailable;
  static const Color occupiedOrange= statusOccupied;
  static const Color billingBlue   = Color(0xFF1E3A8A);
  static const Color primaryRed    = Color(0xFFDC2626);
```

---

## 3. Phase 2: Database Multi-Tenancy Scoping (⏱️ ~1 Hour)

### 2.1 Change Firestore Business ID from `'rajmandir_main'` to `'coffee_katta'`
Update the hardcoded string in these exact **8 files**:

1. **`lib/services/billing_service.dart`** (Line 9):
   ```dart
   final String businessId = 'coffee_katta';
   ```
2. **`lib/services/kot_service.dart`** (Line 8):
   ```dart
   final String businessId = 'coffee_katta';
   ```
3. **`lib/services/table_service.dart`** (Line 7):
   ```dart
   final String businessId = 'coffee_katta';
   ```
4. **`lib/services/menu_service.dart`** (Line 7):
   ```dart
   final String businessId = 'coffee_katta';
   ```
5. **`lib/services/seed_data_service.dart`** (Line 10):
   ```dart
   final String businessId = 'coffee_katta';
   final String branchId = 'latur_main';
   ```
6. **`lib/services/branch_service.dart`** (Lines 13, 23):
   ```dart
   .doc('businesses/coffee_katta/branches/${branch.branchId}')
   ```
7. **`lib/services/analytics_service.dart`** (Line 15):
   ```dart
   static const String _businessId = 'coffee_katta';
   ```
8. **`lib/presentation/providers/branch_provider.dart`** (Lines 12, 27):
   ```dart
   final branchPath = 'businesses/coffee_katta/branches/$activeBranchId';
   // and line 27:
   .collection('businesses/coffee_katta/branches')
   ```

### 2.2 Default Branch Profile Document
Path: `/businesses/coffee_katta/branches/latur_main`
```json
{
  "branchId": "latur_main",
  "branchName": "Coffee Katta",
  "tagline": "The Taste of Togetherness • एकत्र येण्याची उत्तम चव",
  "location": "Near Rajiv Gandhi Chowk",
  "address": "Opposite City Centre, Rajiv Gandhi Chowk, Latur, Maharashtra 413512",
  "phone": "9876543210",
  "fssaiNumber": "11524042000123",
  "gstin": "27AAAAA0000A1Z5",
  "taxRatePercent": 5.0,
  "currencySymbol": "₹",
  "billFooterMessage": "धन्यवाद! पुन्हा भेट द्या! Visit Again!",
  "isActive": true
}
```

---

## 4. Phase 3: Menu & Categories Seed Data (⏱️ ~2 Hours)

Replace the contents of **`assets/data/menu_items.json`** with this initial 45-item Coffee Katta catalog. The existing `SeedDataService.seedMenuData()` will read this JSON and auto-create the categories and items in Firestore!

```json
[
  { "name": "Thick Cold Coffee", "price": 90, "category": "Cold Coffee & Shakes", "variants": ["Regular (250ml):0", "Large (350ml):30"] },
  { "name": "Cold Coffee with Crush", "price": 110, "category": "Cold Coffee & Shakes", "variants": ["Regular (250ml):0", "Large (350ml):30"] },
  { "name": "Hazelnut Cold Coffee", "price": 130, "category": "Cold Coffee & Shakes", "variants": ["Regular (250ml):0", "Large (350ml):40"] },
  { "name": "Irish Cold Coffee", "price": 130, "category": "Cold Coffee & Shakes", "variants": ["Regular (250ml):0", "Large (350ml):40"] },
  { "name": "Cold Coffee Monster (500ml)", "price": 170, "category": "Cold Coffee & Shakes", "variants": ["Single:0"] },
  { "name": "Belgian Chocolate Shake", "price": 160, "category": "Cold Coffee & Shakes", "variants": ["Regular:0", "Large:40"] },
  { "name": "KitKat Crunch Shake", "price": 150, "category": "Cold Coffee & Shakes", "variants": ["Regular:0", "Large:30"] },
  { "name": "Oreo Overload Shake", "price": 140, "category": "Cold Coffee & Shakes", "variants": ["Regular:0", "Large:30"] },

  { "name": "Katta Special Filter Coffee", "price": 40, "category": "Hot Beverages", "variants": ["Cup:0"] },
  { "name": "Espresso Shot", "price": 50, "category": "Hot Beverages", "variants": ["Single:0", "Double:30"] },
  { "name": "Cappuccino", "price": 110, "category": "Hot Beverages", "variants": ["Regular:0", "Large:30"] },
  { "name": "Cafe Latte", "price": 110, "category": "Hot Beverages", "variants": ["Regular:0", "Large:30"] },
  { "name": "Cafe Mocha", "price": 130, "category": "Hot Beverages", "variants": ["Regular:0", "Large:40"] },
  { "name": "Hot Chocolate", "price": 120, "category": "Hot Beverages", "variants": ["Regular:0", "Large:30"] },
  { "name": "Masala Kadak Chai", "price": 30, "category": "Hot Beverages", "variants": ["Cup:0"] },
  { "name": "Green Tea", "price": 40, "category": "Hot Beverages", "variants": ["Cup:0"] },

  { "name": "Veg Grilled Sandwich", "price": 90, "category": "Sandwiches & Toasts", "variants": ["Standard:0"] },
  { "name": "Veg Cheese Grilled Sandwich", "price": 120, "category": "Sandwiches & Toasts", "variants": ["Standard:0"] },
  { "name": "Corn & Cheese Sandwich", "price": 130, "category": "Sandwiches & Toasts", "variants": ["Standard:0"] },
  { "name": "Paneer Tikka Sandwich", "price": 150, "category": "Sandwiches & Toasts", "variants": ["Standard:0"] },
  { "name": "Chocolate Toast Sandwich", "price": 100, "category": "Sandwiches & Toasts", "variants": ["Standard:0"] },
  { "name": "Club Sandwich (3 Layers)", "price": 160, "category": "Sandwiches & Toasts", "variants": ["Standard:0"] },
  { "name": "Bun Maska", "price": 50, "category": "Sandwiches & Toasts", "variants": ["Standard:0"] },

  { "name": "Classic Veg Burger", "price": 90, "category": "Burgers & Wraps", "variants": ["Standard:0"] },
  { "name": "Crispy Veg Cheese Burger", "price": 120, "category": "Burgers & Wraps", "variants": ["Standard:0"] },
  { "name": "Paneer Makhani Burger", "price": 150, "category": "Burgers & Wraps", "variants": ["Standard:0"] },
  { "name": "Veggie Delight Wrap", "price": 110, "category": "Burgers & Wraps", "variants": ["Standard:0"] },
  { "name": "Paneer Tikka Wrap", "price": 140, "category": "Burgers & Wraps", "variants": ["Standard:0"] },

  { "name": "Salted French Fries", "price": 90, "category": "Snacks & Fries", "variants": ["Regular:0", "Large:40"] },
  { "name": "Peri Peri French Fries", "price": 110, "category": "Snacks & Fries", "variants": ["Regular:0", "Large:40"] },
  { "name": "Cheese Loaded Fries", "price": 150, "category": "Snacks & Fries", "variants": ["Regular:0"] },
  { "name": "Veg Cheese Garlic Bread", "price": 120, "category": "Snacks & Fries", "variants": ["Standard:0"] },
  { "name": "Cheese Corn Balls (6 Pcs)", "price": 130, "category": "Snacks & Fries", "variants": ["Standard:0"] },
  { "name": "Potato Wedges", "price": 100, "category": "Snacks & Fries", "variants": ["Standard:0"] },

  { "name": "Margherita Pizza (7 inch)", "price": 150, "category": "Pizzas & Combos", "variants": ["7 inch:0", "9 inch:80"] },
  { "name": "Farmhouse Veg Pizza (7 inch)", "price": 190, "category": "Pizzas & Combos", "variants": ["7 inch:0", "9 inch:90"] },
  { "name": "Paneer Special Pizza (7 inch)", "price": 220, "category": "Pizzas & Combos", "variants": ["7 inch:0", "9 inch:90"] },
  { "name": "Combo: Cold Coffee + Veg Burger", "price": 160, "category": "Pizzas & Combos", "variants": ["Standard:0"] },
  { "name": "Combo: Filter Coffee + Bun Maska", "price": 80, "category": "Pizzas & Combos", "variants": ["Standard:0"] }
]
```

---

## 5. Phase 4: Waiter Screen Beverage Customizer (⏱️ ~4 Hours)
File: **`lib/presentation/screens/waiter/order_screen.dart`**

### 4.1 Unlock Rule #42
Remove lines 1-4:
```dart
/// PROTECTED MODULE: WAITER (REMOVE THIS RESTRICTION - OWNER APPROVED)
```

### 4.2 Add Beverage Customizer Bottom Sheet
When an item is tapped in the Waiter screen:
1. If the item is in category `"Cold Coffee & Shakes"` or `"Hot Beverages"`, show a bottom sheet modal:
   - **Cup Size Selection**: `[ Regular ]` vs `[ Large (+₹30) ]`
   - **Sugar Level Quick Buttons**: `[ No Sugar ]` | `[ Less Sugar ]` | `[ Normal Sugar ]`
   - **Optional Add-on Chips**: `[+ Extra Ice Cream ₹30]` | `[+ Extra Shot ₹30]`
2. Construct the `CartItem`:
   ```dart
   final cartItem = CartItem(
     cartId: const Uuid().v4(),
     item: selectedItem,
     categoryName: category.name,
     quantity: 1,
     variant: selectedSize, // e.g. 'Large (350ml)'
     note: '$selectedSugar${selectedAddOns.isNotEmpty ? ", " + selectedAddOns.join(", ") : ""}',
   );
   ```
3. When firing KOT, map this cleanly into `KOTItem`:
   ```dart
   KOTItem(
     uniqueId: const Uuid().v4(),
     itemId: cartItem.item.itemId,
     name: cartItem.item.name,
     category: cartItem.categoryName,
     qty: cartItem.quantity,
     price: calculatedUnitPrice,
     variant: cartItem.variant ?? '',
     note: cartItem.note,
     status: 'placed',
   )
   ```

---

## 6. Phase 5: Thermal Receipt & RawBT Print Engine (⏱️ ~2 Hours)
File: **`lib/services/print_service.dart`**

### 6.1 Update Thermal Receipt Branding
Update lines 196–203 in `generateBillBytes()`:
```dart
// 1. Coffee Katta Branding Header (80mm ESC/POS)
bytes += generator.text(dsep);
bytes += generator.text('COFFEE KATTA', 
    styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
bytes += generator.text('THE TASTE OF TOGETHERNESS', 
    styles: const PosStyles(align: PosAlign.center, bold: true));
bytes += generator.text('NEAR RAJIV GANDHI CHOWK, LATUR', 
    styles: const PosStyles(align: PosAlign.center));
bytes += generator.text('Phone: 9876543210', 
    styles: const PosStyles(align: PosAlign.center));
if (branch.fssaiNumber.isNotEmpty) {
  bytes += generator.text('FSSAI: ${branch.fssaiNumber}', styles: const PosStyles(align: PosAlign.center));
}
if (branch.gstin != null && branch.gstin!.isNotEmpty) {
  bytes += generator.text('GSTIN: ${branch.gstin}', styles: const PosStyles(align: PosAlign.center));
}
bytes += generator.feed(1);
```

### 6.2 RawBT Driver Intent (Already Exists in Codebase)
The codebase already sends ESC/POS base64 bytes to RawBT via Android Intent:
```dart
// lib/services/print_service.dart (Lines 364-378)
Future<void> sendToRawBT(List<int> bytes) async {
  final String base64Data = base64.encode(bytes);
  final String url = 'rawbt:base64,$base64Data';
  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}
```
**Counter Hub Spooler Logic**: In `lib/presentation/screens/shared/kot_screen.dart` or a background provider, set up a stream listener:
```dart
// Listens for unprinted KOTs in Firestore and prints them automatically on Counter terminal
firestore.collection('businesses/coffee_katta/branches/latur_main/kots')
  .where('isPrinted', isEqualTo: false)
  .snapshots()
  .listen((snapshot) async {
    for (var doc in snapshot.docs) {
      final kot = KOTModel.fromJson(doc.data());
      final bytes = await printService.generateKOTBytes(kot, PrinterPaperSize.mm80);
      await printService.sendToRawBT(bytes);
      await doc.reference.update({'isPrinted': true, 'printedAt': FieldValue.serverTimestamp()});
    }
  });
```

---

## 7. Phase 6: Billing Math, 5% GST & Split Payment (⏱️ ~2 Hours)
Files: **`lib/services/billing_service.dart`** & **`lib/presentation/screens/admin/billing_screen.dart`**

### 7.1 5% Restaurant GST Calculation Math
Under Indian tax law (SAC 996331), cafe food is taxed at 5% (2.5% CGST + 2.5% SGST). In inclusive mode:
```dart
// In billing_service.dart:
final double subtotal = billItems.fold(0.0, (sum, item) => sum + (item.price * item.qty));
final double discountAmount = discountType == 'flat' ? discountValue.clamp(0, subtotal) : (subtotal * discountPercent) / 100;
final double netSubtotal = subtotal - discountAmount;

// Inclusive 5% GST extraction
final double taxableValue = netSubtotal / 1.05;
final double totalGst = netSubtotal - taxableValue;
final double cgst = (totalGst / 2).roundToDouble();
final double sgst = totalGst - cgst; // Prevents 1-paisa rounding mismatch

// Nearest ₹1 Round-off
final double rawTotal = netSubtotal + extraCharges;
final double roundedTotal = rawTotal.roundToDouble();
final double roundOff = roundedTotal - rawTotal;
```

### 7.2 Split-Payment Reconciliation
Ensure `billing_screen.dart` allows adding multiple tenders to `List<Payment>`:
```dart
List<Payment> payments = [
  Payment(mode: 'cash', amount: cashInput),
  Payment(mode: 'upi', amount: upiInput),
];
// Validate:
final double totalPaid = payments.fold(0.0, (s, p) => s + p.amount);
if ((totalPaid - roundedTotal).abs() > 0.01) {
  // Show error: "Payments must equal ₹${roundedTotal.toStringAsFixed(0)}"
}
```

---

## 8. Phase 7: Build, Run & Verification Protocol (⏱️ ~1 Hour)

Execute these commands in sequence in the terminal to verify the app compiles and runs:

```powershell
# 1. Clean and install dependencies
flutter clean
flutter pub get

# 2. Re-run Freezed code generation (if any models changed)
dart run build_runner build --delete-conflicting-outputs

# 3. Test compile on Windows Desktop
flutter run -d windows

# 4. Test compile on connected Android Phone (Waiter / Counter Device)
flutter run -d android
```

### Acceptance Checklist:
- [ ] App launches with "Coffee Katta POS" title.
- [ ] Visual theme is Warm Espresso Brown, Caramel, and Cream Latte (no Maroon).
- [ ] Categories show Coffee Katta cafe items (Cold Coffee, Burgers, Sandwiches).
- [ ] Waiter can tap Cold Coffee, select Regular/Large + Sugar level, and fire KOT.
- [ ] KOT shows up in Firestore `/businesses/coffee_katta/branches/latur_main/kots`.
- [ ] Counter terminal detects KOT and sends print bytes to RawBT.
- [ ] Bill settlements calculate 5% GST and support Split Payment (Cash + UPI) in Indian Rupees (`₹`).



if you need full menu here its link 
https://www.google.com/maps/place/Coffee+Katta/@18.3886065,76.5585475,17z/data=!3m1!4b1!4m6!3m5!1s0x3bcf83122a4c237b:0x330279a1ce39b19d!8m2!3d18.3886014!4d76.5611224!16s%2Fg%2F11y4h5spmk?entry=ttu&g_ep=EgoyMDI2MDkwNi4wIKXMDSoASAFQAw%3D%3D
</USER_REQUEST>
<ADDITIONAL_METADATA>
The current local time is: 2026-09-11T15:08:48+05:30.

The user's current state is as follows:
Browser State:
  Page F2A49A6D5D1C0A0A632792CAC70AA387 (Coffee Katta - Google Maps) - https://www.google.com/maps/place/Coffee+Katta/@18.3886394,76.5577342,17z/data=!... [ACTIVE]
    Viewport: 1152x633, Page Height: 633
</ADDITIONAL_METADATA>
<USER_SETTINGS_CHANGE>
The user changed setting `Model Selection` from None to Gemini 3.8 Flash (High). No need to comment on this change if the user doesn't ask about it. If reporting what model you are, please use a human readable name instead of the exact string.
</USER_SETTINGS_CHANGE>