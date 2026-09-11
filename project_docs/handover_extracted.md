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
   description: "Coffee Katta Specialty Cafe POS 
<truncated 14541 bytes>
, Run & Verification Protocol (⏱️ ~1 Hour)

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