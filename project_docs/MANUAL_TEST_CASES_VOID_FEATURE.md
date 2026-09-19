# 🧪 Coffee Katta POS — Manual Test Cases: Bill Void / Cancel / Refund Flow (P0-3)

**Document Version**: 1.0  
**Feature**: P0-3 Bill Void / Cancel / Refund Flow & Audit Log  
**Target Platform**: Windows Desktop (POS Terminal) + Android Tablet / Mobile Form Factors  
**Target Environment**: Live Dev / Production (`coffee-katta-pos`)  
**Date**: 15 September 2026  

---

## 📋 Test Execution Summary Matrix

| Suite ID | Suite Name | Test Cases | Priority | Execution Type |
|---|---|---|---|---|
| **TS-01** | Standard Bill Void with Table Restoration (Re-bill Flow) | 2 | 🔴 P0 Critical | End-to-End Flow |
| **TS-02** | Total Bill Void without Table Restoration (Order Abandoned & Past Bills) | 3 | 🔴 P0 Critical | End-to-End Flow |
| **TS-03** | Void Reason Dialog & Form Validation | 3 | 🟠 P1 High | UI / Input Validation |
| **TS-04** | Invoice Register Filter & Search Behavior | 3 | 🟠 P1 High | UI / Filter Testing |
| **TS-05** | Real-Time Dashboard & Financial Analytics Reversal | 2 | 🔴 P0 Critical | Accounting Consistency |
| **TS-06** | Thermal ESC/POS Slip & PDF Receipt Watermarking | 2 | 🟡 P2 Medium | Hardware / Printing |
| **TS-07** | Idempotency, Concurrency & Security Constraints | 2 | 🔴 P0 Critical | Security & Integrity |
| **TOTAL** | **7 Suites** | **17 Cases** | | |

---

## Suite 1: Standard Bill Void with Table Restoration (Re-bill Flow)

### TC-VOID-001: Void a recent same-day invoice and restore table to active floor for correction
* **Priority**: 🔴 P0 (Blocker)
* **Objective**: Verify that voiding a recent same-day invoice (< 2 hours) with "Restore Table & Re-open Order" opted-in returns the table to `occupied` status with its active order and KOT items intact.
* **Preconditions**:
  1. POS application is logged in with Admin or Cashier role.
  2. Table **T3** has an active order with at least 2 KOT items (e.g., 2x Cold Coffee @ ₹60 = ₹120).
  3. Bill has been generated for T3 (Invoice ID e.g., `INV-260915-001` within the last hour) and table is cleared or in `billing` status.
* **Execution Steps**:
  1. Navigate to **Reports Dashboard** → click on **INVOICE AUDIT LOG** tab.
  2. Locate invoice `INV-260915-001` in the data table or mobile list.
  3. Click the red **Cancel / Void icon** (`Icons.cancel_outlined`) in the Actions column.
  4. In the "Void Invoice" dialog:
     - Verify dialog displays correct Table Name (`Table 3`) and Total Amount (`₹120.00`).
     - Select preset reason: **"Wrong Table Billed"**.
     - Notice the checkbox **"Restore Table & Re-open Order"** is **UNCHECKED by default** for safety.
     - Explicitly **CHECK** the checkbox **"Restore Table & Re-open Order"**.
  5. Click **Confirm Void**.
* **Expected Results**:
  1. Loading spinner shows briefly, then dialog closes.
  2. Success SnackBar appears: `"Invoice INV-260915-001 voided successfully. Table 3 has been re-opened."`
  3. In the Invoice Register:
     - `INV-260915-001` now has a red strikethrough (`INV-260915-001`) with a red `[VOIDED]` badge.
     - Void action button is replaced with a disabled grey block icon (`Icons.block_rounded`).
  4. Navigate back to the **Tables Floor Screen**:
     - Table **T3** status changes from `available` back to **`occupied`** (warm highlighted card).
     - Table badge displays **2 items**, total amount **₹120.00**.
     - Tapping T3 opens the active order containing the original KOT items ready for adjustments or re-billing.
* **Status**: [ ] Pass / [ ] Fail

---

### TC-VOID-002: Re-bill the restored table and generate a new consecutive invoice
* **Priority**: 🔴 P0 (Blocker)
* **Objective**: Confirm that a restored table can take additional KOTs, calculate the updated total, and successfully bill out with a new unique invoice number.
* **Preconditions**:
  1. TC-VOID-001 has been executed; Table T3 is restored to `occupied`.
* **Execution Steps**:
  1. Select Table **T3**.
  2. Add 1x **Bun Maska** (@ ₹50) and punch KOT.
  3. Click **Proceed to Bill**.
  4. Verify item aggregation displays 2x Cold Coffee (₹120) + 1x Bun Maska (₹50) = Subtotal ₹170.
  5. Select payment mode: Cash ₹170.
  6. Click **Generate Bill & Settle**.
* **Expected Results**:
  1. A new unique invoice ID is generated (e.g. `INV-260915-002`).
  2. Table T3 clears back to `available`.
  3. Invoice Audit Log displays two records:
     - `INV-260915-001` (`[VOIDED]` — ₹120)
     - `INV-260915-002` (`[ACTIVE]` — ₹170)
* **Status**: [ ] Pass / [ ] Fail

---

## Suite 2: Total Bill Void without Table Restoration (Order Abandoned / Past Bills)

### TC-VOID-003: Void an invoice with table restoration unchecked (Walkout / Cancelled Order)
* **Priority**: 🔴 P0 (Blocker)
* **Objective**: Verify that voiding an invoice with table restoration unchecked cancels the revenue without disturbing floor tables.
* **Preconditions**:
  1. Table **T5** was billed and cleared (Invoice `INV-260915-003` for ₹250). Table T5 is currently `available`.
* **Execution Steps**:
  1. Navigate to **Reports Dashboard** → **INVOICE AUDIT LOG**.
  2. Find `INV-260915-003`.
  3. Click the red **Void** icon.
  4. Select reason: **"Customer Dispute / Cancelled"**.
  5. Enter custom notes: *"Customer refused order and walked out"*.
  6. Verify the checkbox **"Restore Table & Re-open Order"** is **UNCHECKED by default**. Leave it unchecked.
  7. Click **Confirm Void**.
* **Expected Results**:
  1. Success SnackBar appears: `"Invoice INV-260915-003 voided successfully."` (No table re-opened message).
  2. The invoice is marked `[VOIDED]` in the audit log.
  3. Navigate to Tables Floor Screen:
     - Table **T5** remains **`available`** (vacant).
     - It does NOT restore any old order or KOTs.
* **Status**: [ ] Pass / [ ] Fail

---

### TC-VOID-004: Table restoration on an already newly occupied table (Safety Collision Check)
* **Priority**: 🟠 P1 (High)
* **Objective**: Verify that if a table was cleared, occupied by new guests, and an old bill is voided with table restoration, the POS gracefully handles the state without crashing or overwriting the new guests' order.
* **Preconditions**:
  1. Table **T2** was previously billed with Invoice `INV-260915-004`.
  2. Table T2 is currently seated with NEW guests and has an active order in progress.
* **Execution Steps**:
  1. Go to **Invoice Audit Log**.
  2. Void `INV-260915-004` with "Restore Table" checked.
  3. Click **Confirm Void**.
* **Expected Results**:
  1. Bill is voided and revenue reversed.
  2. The table guard detects T2 is already occupied with an active session and preserves the new guests' order without data corruption.
* **Status**: [ ] Pass / [ ] Fail

---

### TC-VOID-004B: Historical / Past-Session Bill Table Restoration Lockout
* **Priority**: 🔴 P0 (Blocker)
* **Objective**: Verify that attempting to void a bill from yesterday or older (> 2 hours) locks out the "Restore Table" checkbox to prevent ghost orders on today's live floor.
* **Preconditions**:
  1. Locate a historical bill in the Invoice Audit Log (e.g. from yesterday `14/09` or earlier).
* **Execution Steps**:
  1. Click the red **Void** icon on the historical bill.
  2. In the "Void Invoice" dialog, inspect the table restoration section.
* **Expected Results**:
  1. The title reads: `"Restore Table (Disabled for Past Bills)"`.
  2. The subtitle reads: `"Bill is from [Date/Time]. Historical tables cannot be re-opened on today's floor."`
  3. The checkbox is completely **DISABLED / UNCLICKABLE** (`onChanged: null`).
  4. Clicking **Confirm Void** voids the bill and reverses accounting, but leaves today's table floor completely untouched.
* **Status**: [ ] Pass / [ ] Fail

---

## Suite 3: Void Reason Dialog & Form Validation

### TC-VOID-005: Validation guard on empty or too short void reason
* **Priority**: 🟠 P1 (High)
* **Objective**: Ensure staff cannot void bills without a descriptive audit explanation (minimum 3 characters).
* **Preconditions**:
  1. Any active bill exists in the Invoice Register.
* **Execution Steps**:
  1. Click Void on the bill.
  2. Select preset **"Other Reason"** (which clears the text field).
  3. Leave the text field completely empty and click **Confirm Void**.
  4. Type 2 characters: `"No"` and click **Confirm Void**.
* **Expected Results**:
  1. The dialog does NOT proceed.
  2. An error SnackBar appears: `"Please enter a valid reason (min 3 characters)."`.
  3. The bill remains active and unchanged in Firestore.
* **Status**: [ ] Pass / [ ] Fail

---

### TC-VOID-006: Reason presets auto-population and custom notes entry
* **Priority**: 🟡 P2 (Medium)
* **Objective**: Verify all 7 preset dropdown options function smoothly.
* **Execution Steps**:
  1. Open the Void dialog.
  2. Cycle through each dropdown option:
     - "Wrong Table Billed"
     - "Customer Dispute / Cancelled"
     - "Wrong Payment Mode"
     - "Duplicate Entry"
     - "Cashier Error"
     - "Order Returned"
     - "Other Reason"
* **Expected Results**:
  1. Selecting any preset (except "Other Reason") auto-populates the text field with the preset text.
  2. Selecting "Other Reason" clears the field and sets focus for custom typing.
  3. User can append custom text to preset text (e.g. `"Cashier Error - selected UPI instead of Card"`).
* **Status**: [ ] Pass / [ ] Fail

---

### TC-VOID-007: Dialog cancellation behavior
* **Priority**: 🟡 P2 (Medium)
* **Objective**: Verify tapping "Cancel" aborts the void flow with zero side-effects.
* **Execution Steps**:
  1. Open Void dialog on an active bill.
  2. Type a reason.
  3. Tap **Cancel** button (or outside dialog barrier).
* **Expected Results**:
  1. Dialog closes immediately.
  2. Bill remains `[ACTIVE]`.
  3. No Firestore writes occur.
* **Status**: [ ] Pass / [ ] Fail

---

## Suite 4: Invoice Register Filter & Search Behavior

### TC-VOID-008: Status filter chips (`ALL`, `ACTIVE`, `VOIDED`)
* **Priority**: 🟠 P1 (High)
* **Objective**: Verify that the newly added Status ChoiceChips correctly filter the invoice list.
* **Preconditions**:
  1. At least 2 active bills and 1 voided bill exist in the selected date range.
* **Execution Steps**:
  1. Open **Invoice Audit Log**.
  2. Tap **`ACTIVE`** status chip.
     - Verify ONLY non-voided bills are shown. Zero `[VOIDED]` tags visible.
  3. Tap **`VOIDED`** status chip.
     - Verify ONLY voided bills are shown. All visible rows have red strikethrough IDs and `[VOIDED]` tags.
  4. Tap **`ALL`** status chip.
     - Verify both active and voided bills appear in chronological descending order.
* **Status**: [ ] Pass / [ ] Fail

---

### TC-VOID-009: Search bar with voided bills
* **Priority**: 🟡 P2 (Medium)
* **Objective**: Verify searching by invoice number, cashier, or table works across voided bills.
* **Execution Steps**:
  1. In the search bar, type the invoice ID of a voided bill (e.g. `INV-260915-001`).
  2. Type the cashier name associated with that voided bill.
  3. Type the table name of that voided bill.
* **Expected Results**:
  1. The voided bill is correctly filtered and displayed with its `[VOIDED]` indicator.
* **Status**: [ ] Pass / [ ] Fail

---

### TC-VOID-010: Bill Details Modal — Void Audit Trail card display
* **Priority**: 🟠 P1 (High)
* **Objective**: Verify the receipt inspection modal displays the full audit trail when opening a voided bill.
* **Execution Steps**:
  1. In the Invoice Register, tap on a voided bill row (or the Eye icon).
  2. Bottom sheet modal slides up.
* **Expected Results**:
  1. Header shows invoice ID in red strikethrough with a `[VOIDED]` tag.
  2. Prominent **VOID AUDIT TRAIL** box is displayed in light red:
     - Icon: Red warning/cancel icon.
     - **Reason**: Shows the exact text entered when voiding.
     - **Voided by**: Shows staff name/email and exact date/time (`dd/MM/yyyy hh:mm a`).
     - **Table restored status**: Displays `"✓ Table was restored to active floor"` if restored.
  3. Grand Total line shows `GRAND TOTAL (VOIDED)` in red text.
  4. The "Void / Cancel This Invoice" button is **HIDDEN** (cannot re-void).
* **Status**: [ ] Pass / [ ] Fail

---

## Suite 5: Real-Time Dashboard & Financial Analytics Reversal

### TC-VOID-011: Real-time Dashboard revenue & bill count deduction
* **Priority**: 🔴 P0 (Blocker)
* **Objective**: Verify that voiding a bill immediately deducts its total and count from today's live revenue in real time without requiring an app restart.
* **Preconditions**:
  1. Note the current figures on the Admin Dashboard:
     - **Total Revenue**: e.g., ₹5,000
     - **Total Bills**: e.g., 20
     - **Cash / UPI breakdown**: e.g., Cash ₹3,000, UPI ₹2,000
* **Execution Steps**:
  1. Generate a new bill: Table T1, Amount = **₹500** (Paid via **UPI**).
  2. Verify Dashboard updates:
     - Total Revenue = **₹5,500**
     - Total Bills = **21**
     - UPI Total = **₹2,500**
  3. Go to Invoice Audit Log and **Void** this ₹500 bill (Reason: `"Test reversal"`).
  4. Immediately return to the **Dashboard Screen**.
* **Expected Results**:
  1. Dashboard **Total Revenue** reverts back to **₹5,000** (-₹500 deducted).
  2. **Total Bills** reverts back to **20** (-1 deducted).
  3. **UPI Total** reverts back to **₹2,000** (-₹500 deducted).
  4. Zero data lag or ghost figures.
* **Status**: [ ] Pass / [ ] Fail

---

### TC-VOID-012: Pre-aggregated `analytics_daily` document verification
* **Priority**: 🔴 P0 (Blocker)
* **Objective**: Confirm that Firestore document `/businesses/coffee_katta/branches/latur_main/analytics_daily/{today}` reflects negative increments.
* **Execution Steps**:
  1. In Firebase Console (or via Reports Tab), inspect the `analytics_daily` document for today's date.
  2. Verify fields after voiding TC-VOID-011:
     - `totalSales`: reflects net of active bills only.
     - `paymentStats.upi`: reflects net UPI amount.
     - `itemStats`: item quantities and revenues for the voided bill items are decremented.
* **Expected Results**:
  1. Pre-aggregated analytics match the sum of active bills exactly.
* **Status**: [ ] Pass / [ ] Fail

---

## Suite 6: Thermal ESC/POS Slip & PDF Receipt Watermarking

### TC-VOID-013: PDF invoice generation watermark on voided bills
* **Priority**: 🟡 P2 (Medium)
* **Objective**: Verify that generating a PDF of a voided bill clearly stamps it as cancelled.
* **Execution Steps**:
  1. Open Invoice Audit Log.
  2. Tap the **Print / PDF** icon on a voided bill.
  3. Preview the generated PDF document.
* **Expected Results**:
  1. PDF renders cleanly.
  2. Directly below the header, a boxed red banner appears:  
     `*** CANCELLED / VOIDED INVOICE ***`
  3. Directly below the banner, the reason appears:  
     `REASON: [REASON IN CAPITAL LETTERS]`
  4. The normal duplicate reprint banner is suppressed in favor of the void banner.
* **Status**: [ ] Pass / [ ] Fail

---

### TC-VOID-014: ESC/POS Thermal byte stream void watermark
* **Priority**: 🟡 P2 (Medium)
* **Objective**: Verify thermal printer output formats the cancellation header on 58mm / 80mm receipt rolls.
* **Execution Steps**:
  1. Send reprint command to a configured thermal ESC/POS printer (or inspect byte stream via simulator / `printer_management_test.dart`).
* **Expected Results**:
  1. The receipt prints:
     ```
     ================================
               COFFEE KATTA
          RAJIV GANDHI CHOWK, LATUR
                RETAIL INVOICE
      *** CANCELLED / VOIDED INVOICE ***
        REASON: WRONG TABLE BILLED
     --------------------------------
     ```
  2. Void watermark is centered and bold.
* **Status**: [ ] Pass / [ ] Fail

---

## Suite 7: Idempotency, Concurrency & Security Constraints

### TC-VOID-015: Double-void prevention (Idempotency Guard)
* **Priority**: 🔴 P0 (Blocker)
* **Objective**: Verify that once an invoice is voided, it cannot be voided a second time, preventing negative revenue double-deductions.
* **Execution Steps**:
  1. Find a bill that is already marked `[VOIDED]`.
  2. Notice the Action column icon is changed to a disabled grey block icon.
  3. Open the bill details modal and verify the "Void / Cancel This Invoice" button is absent.
  4. (Simulated programmatic check): Attempting to call `BillingService.voidBill()` on this bill throws an exception: `"Bill [ID] is already voided."`
* **Expected Results**:
  1. It is impossible for a user or network retry to void an invoice twice.
  2. Revenue cannot be subtracted more than once.
* **Status**: [ ] Pass / [ ] Fail

---

### TC-VOID-016: Waiter role permission denial (Security Check)
* **Priority**: 🔴 P0 (Blocker)
* **Objective**: Ensure that Waiter accounts cannot void bills or access the Invoice Audit Log.
* **Preconditions**:
  1. Log in with a **Waiter** role account (e.g. `waiter@coffeekatta.com`).
* **Execution Steps**:
  1. Observe available navigation items on the waiter home screen.
  2. Attempt to navigate to the Reports Dashboard / Invoice Register.
* **Expected Results**:
  1. Reports Dashboard and Invoice Register are restricted to Admin/Cashier roles.
  2. Waiters have no UI access to void invoices, ensuring financial integrity.
* **Status**: [ ] Pass / [ ] Fail

---

## 🏁 Execution Sign-Off

| Role | Name | Signature | Date | Result |
|---|---|---|---|---|
| **Lead QA Tester** | | | | [ ] PASS / [ ] FAIL |
| **Store Manager** | | | | [ ] PASS / [ ] FAIL |
| **Principal Architect** | Senior Architect | *Verified via Automated Test Suite (86/86)* | 15-09-2026 | ✅ PASS |
