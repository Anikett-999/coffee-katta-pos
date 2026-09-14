import subprocess
import urllib.request
import urllib.error
import json
import os
import sys
import re

PROJECT_ID = "coffee-katta-pos"
BUSINESS_ID = "coffee_katta"
TARGET_BRANCHES = [
    {
        "id": "branch_001",
        "name": "Coffee Katta - Flagship",
        "location": "Latur, Maharashtra",
        "address": "Near Rajiv Gandhi Chowk, Latur, Maharashtra 413512",
        "phone": "+91 98765 43210",
        "instagramId": "@coffeekatta_official",
    },
    {
        "id": "latur_main",
        "name": "Coffee Katta - Flagship",
        "location": "Latur, Maharashtra",
        "address": "Opposite Town Hall, Shivaji Chowk, Latur, Maharashtra 413512",
        "phone": "+91 98765 43210",
        "instagramId": "@coffeekatta_official",
    }
]

def get_access_token():
    try:
        token = subprocess.check_output("gcloud auth print-access-token", shell=True).decode("utf-8").strip()
        return token
    except Exception as e:
        print(f"[!] Error: Could not retrieve gcloud access token: {e}")
        sys.exit(1)

def to_firestore_value(val):
    if val is None:
        return {"nullValue": None}
    elif isinstance(val, bool):
        return {"booleanValue": val}
    elif isinstance(val, int):
        return {"integerValue": str(val)}
    elif isinstance(val, float):
        return {"doubleValue": float(val)}
    elif isinstance(val, str):
        return {"stringValue": val}
    elif isinstance(val, list):
        return {"arrayValue": {"values": [to_firestore_value(v) for v in val]}}
    elif isinstance(val, dict):
        return {"mapValue": {"fields": {k: to_firestore_value(v) for k, v in val.items()}}}
    else:
        return {"stringValue": str(val)}

def patch_document(token, doc_path, fields_dict):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{doc_path}"
    payload = json.dumps({
        "fields": {k: to_firestore_value(v) for k, v in fields_dict.items()}
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        },
        method="PATCH"
    )

    try:
        with urllib.request.urlopen(req) as resp:
            return True
    except urllib.error.HTTPError as e:
        print(f"[!] HTTP Error patching {doc_path}: {e.code} - {e.read().decode('utf-8')}")
        return False

def delete_document(token, doc_path):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{doc_path}"
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {token}"},
        method="DELETE"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return True
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"[!] HTTP Error deleting {doc_path}: {e.code}")
        return False

def list_documents(token, col_path):
    all_docs = []
    page_token = ""
    while True:
        url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{col_path}?pageSize=300"
        if page_token:
            url += f"&pageToken={page_token}"
        req = urllib.request.Request(
            url,
            headers={"Authorization": f"Bearer {token}"}
        )
        try:
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                docs = data.get("documents", [])
                all_docs.extend(docs)
                page_token = data.get("nextPageToken", "")
                if not page_token:
                    break
        except urllib.error.HTTPError as e:
            break
    return all_docs

def slugify(text):
    text = text.lower()
    text = re.sub(r'[^a-z0-9]+', '_', text).strip('_')
    return text

def main():
    if sys.stdout.encoding != 'utf-8':
        sys.stdout.reconfigure(encoding='utf-8')

    token = get_access_token()
    print(f"[*] Authenticated with gcloud for Firestore project: {PROJECT_ID}")

    # 1. Root business doc
    print(f"[*] Setting Business doc: businesses/{BUSINESS_ID}")
    patch_document(token, f"businesses/{BUSINESS_ID}", {
        "businessId": BUSINESS_ID,
        "businessName": "Coffee Katta",
        "brandColor": "#4A2C11",
        "currency": "INR",
        "currencySymbol": "₹"
    })

    # Official 15 Categories from Physical Menu
    CATEGORIES = [
        {"id": "cat_katta_coffee", "name": "Katta Coffee", "order": 1},
        {"id": "cat_hot_beverages", "name": "Hot Beverages", "order": 2},
        {"id": "cat_freak_shakes", "name": "Freak Shakes", "order": 3},
        {"id": "cat_katta_frappe", "name": "Katta Frappé", "order": 4},
        {"id": "cat_polare_ice_tea", "name": "Polare Ice Tea", "order": 5},
        {"id": "cat_katta_starter", "name": "Katta Starter", "order": 6},
        {"id": "cat_on_the_sides", "name": "On the Sides", "order": 7},
        {"id": "cat_katta_starter_non_veg", "name": "Katta Starter (Non Veg)", "order": 8},
        {"id": "cat_on_the_sides_non_veg", "name": "On the Sides (Non Veg)", "order": 9},
        {"id": "cat_artisan_pizzas", "name": "Artisan Pizzas", "order": 10},
        {"id": "cat_gourmet_burgers", "name": "Gourmet Burgers", "order": 11},
        {"id": "cat_grilled_sandwiches", "name": "Grilled Sandwiches", "order": 12},
        {"id": "cat_italian_pasta", "name": "Italian Pasta", "order": 13},
        {"id": "cat_egg_specialties", "name": "Egg Specialties", "order": 14},
        {"id": "cat_waffle_special_menu", "name": "Waffle Special Menu", "order": 15},
    ]

    # Load 106 Menu Items from assets/data/menu_items.json
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, "..", "assets", "data", "menu_items.json")
    with open(json_path, "r", encoding="utf-8") as f:
        menu_items_data = json.load(f)

    # Process all target branches
    for branch_info in TARGET_BRANCHES:
        branch_id = branch_info["id"]
        branch_path = f"businesses/{BUSINESS_ID}/branches/{branch_id}"
        print(f"\n=======================================================")
        print(f"[*] Seeding Branch: {branch_id} ({branch_info['name']})")
        print(f"=======================================================")

        # 2. Branch doc
        patch_document(token, branch_path, {
            "branchId": branch_id,
            "branchName": branch_info["name"],
            "location": branch_info["location"],
            "address": branch_info["address"],
            "phone": branch_info["phone"],
            "instagramId": branch_info["instagramId"],
            "reviewQrUrl": "",
            "currencySymbol": "₹",
            "isActive": True
        })

        # 3. Categories
        cat_map = {}
        valid_cat_ids = set()
        print(f"[*] Seeding {len(CATEGORIES)} menu categories for {branch_id}...")
        for cat in CATEGORIES:
            valid_cat_ids.add(cat["id"])
            cat_doc_path = f"{branch_path}/menu_categories/{cat['id']}"
            patch_document(token, cat_doc_path, {
                "categoryId": cat["id"],
                "name": cat["name"],
                "order": cat["order"]
            })
            cat_map[cat["name"]] = cat["id"]
            print(f"    - [{cat['id']}] {cat['name']} (order: {cat['order']})")

        # Clean old categories
        existing_cats = list_documents(token, f"{branch_path}/menu_categories")
        for doc in existing_cats:
            doc_name = doc["name"].split("/")[-1]
            if doc_name not in valid_cat_ids:
                print(f"    [Cleaning old category] Deleting {doc_name}")
                delete_document(token, f"{branch_path}/menu_categories/{doc_name}")

        # 4. Menu Items
        print(f"[*] Seeding {len(menu_items_data)} menu items for {branch_id}...")
        valid_item_doc_ids = set()

        for idx, item in enumerate(menu_items_data, 1):
            cat_name = item["category"]
            cat_id = cat_map.get(cat_name, "cat_other")
            item_slug = slugify(item["name"])
            item_id = f"item_{item_slug}"
            valid_item_doc_ids.add(item_id)

            group_name = item.get("groupName", "")
            if not group_name:
                if cat_name == "Egg Specialties":
                    group_name = "Egg"
                elif not item.get("isVeg", True):
                    group_name = "Non-Veg"
                elif "jain" in item["name"].lower():
                    group_name = "Jain"

            item_doc_path = f"{branch_path}/menu_items/{item_id}"
            patch_document(token, item_doc_path, {
                "itemId": item_id,
                "name": item["name"],
                "categoryId": cat_id,
                "groupName": group_name,
                "price": float(item["price"]),
                "variants": item.get("variants", []),
                "isVeg": item.get("isVeg", True),
                "isAvailable": True
            })
            veg_symbol = "🟢" if item.get("isVeg", True) else "🔴"
            print(f"    [{idx:02d}/{len(menu_items_data)}] {veg_symbol} {item['name']} (₹{item['price']}) -> {cat_name}")

        # Remove any stale menu items not in current list
        existing_items = list_documents(token, f"{branch_path}/menu_items")
        for doc in existing_items:
            doc_name = doc["name"].split("/")[-1]
            if doc_name not in valid_item_doc_ids:
                print(f"    [Cleaning stale item] Deleting {doc_name}")
                delete_document(token, f"{branch_path}/menu_items/{doc_name}")

        # 5. Tables: T1 to T20
        print(f"[*] Seeding 20 tables (T1 - T20) for {branch_id}...")
        valid_table_ids = set()
        for i in range(1, 21):
            table_id = f"T{i}"
            valid_table_ids.add(table_id)

            if 1 <= i <= 8:
                section = "Indoor AC"
                capacity = 4
            elif 9 <= i <= 12:
                section = "Outdoor Patio"
                capacity = 4
            elif 13 <= i <= 14:
                section = "Outdoor Patio"
                capacity = 6
            else:
                section = "Katta High Tops"
                capacity = 2

            table_doc_path = f"{branch_path}/tables/{table_id}"
            patch_document(token, table_doc_path, {
                "tableId": table_id,
                "name": f"Table {i}",
                "section": section,
                "capacity": capacity,
                "status": "available",
                "activeOrderId": None,
                "totalAmount": 0.0,
                "itemCount": 0,
                "kotCount": 0,
                "unprintedKotCount": 0
            })

        # Delete any old table IDs
        existing_tables = list_documents(token, f"{branch_path}/tables")
        for doc in existing_tables:
            doc_name = doc["name"].split("/")[-1]
            if doc_name not in valid_table_ids:
                print(f"    [Cleaning old table] Deleting {doc_name}")
                delete_document(token, f"{branch_path}/tables/{doc_name}")

        # 6. Global counters
        print(f"[*] Initializing global counters for {branch_id}...")
        counter_path = f"{branch_path}/counters/global"
        patch_document(token, counter_path, {
            "kotCounter": 1000,
            "billCounter": 1000,
            "lastResetDate": "2026-09-11",
            "lastBillResetDate": "2026-09-11"
        })

    print("\n[SUCCESS] Firestore multi-branch seeding completed successfully!")
    print(f"Updated branches: {[b['id'] for b in TARGET_BRANCHES]}")
    print(f"- 9 Categories each")
    print(f"- {len(menu_items_data)} Menu Items each")
    print(f"- 20 Tables (T1-T20) each")
    print(f"- Global Counters initialized")

if __name__ == "__main__":
    main()
