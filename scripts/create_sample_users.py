import subprocess
import urllib.request
import json
import sys

API_KEY = "AIzaSyAm9h3_byJdTcjsgFtSearGez7w7rCAigI"
PROJECT_ID = "coffee-katta-pos"

USERS_TO_CREATE = [
    {
        "email": "admin@coffeekatta.com",
        "password": "AdminPassword@123",
        "name": "Coffee Katta Admin",
        "role": "admin",
        "pin": "1111",
        "branchIds": ["latur_main"],
    },
    {
        "email": "cashier@coffeekatta.com",
        "password": "CashierPassword@123",
        "name": "Main Counter Cashier",
        "role": "cashier",
        "pin": "2222",
        "branchIds": ["latur_main"],
    },
    {
        "email": "waiter@coffeekatta.com",
        "password": "WaiterPassword@123",
        "name": "Floor Captain (Waiter)",
        "role": "waiter",
        "pin": "3333",
        "branchIds": ["latur_main"],
    },
]

def get_access_token():
    try:
        token = subprocess.check_output("gcloud auth print-access-token", shell=True).decode("utf-8").strip()
        return token
    except Exception as e:
        print(f"[!] Warning: Could not retrieve gcloud access token: {e}")
        return None

def create_auth_user(email, password):
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}"
    payload = json.dumps({"email": email, "password": password, "returnSecureToken": True}).encode("utf-8")
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("localId"), data.get("idToken")
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        if "EMAIL_EXISTS" in err_body:
            print(f"[*] Account {email} already exists in Firebase Auth. Signing in to fetch UID...")
            return sign_in_user(email, password)
        elif "CONFIGURATION_NOT_FOUND" in err_body:
            print(f"[!] ERROR: Firebase Authentication is not yet enabled for project '{PROJECT_ID}'.")
            print(f"    Please visit: https://console.firebase.google.com/project/{PROJECT_ID}/authentication")
            print(f"    Click 'Get started', select 'Email/Password', enable it, and click 'Save'.")
            sys.exit(1)
        else:
            print(f"[!] Failed to create user {email}: {err_body}")
            return None, None

def sign_in_user(email, password):
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}"
    payload = json.dumps({"email": email, "password": password, "returnSecureToken": True}).encode("utf-8")
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("localId"), data.get("idToken")
    except Exception as e:
        print(f"[!] Sign-in error for {email}: {e}")
        return None, None

def write_firestore_user(token, uid, user_info):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/users/{uid}"
    
    branch_ids = user_info["branchIds"]
    branch_values = [{"stringValue": b} for b in branch_ids]
    
    doc = {
        "fields": {
            "userId": {"stringValue": uid},
            "name": {"stringValue": user_info["name"]},
            "email": {"stringValue": user_info["email"]},
            "role": {"stringValue": user_info["role"]},
            "branchIds": {
                "arrayValue": {
                    "values": branch_values
                }
            },
            "isActive": {"booleanValue": True}
        }
    }
    
    body = json.dumps(doc).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="PATCH", headers={
        "Authorization": f"Bearer {token}",
        "X-Goog-User-Project": PROJECT_ID,
        "Content-Type": "application/json"
    })
    
    with urllib.request.urlopen(req) as resp:
        print(f"[+] Firestore user profile saved: /users/{uid} ({user_info['role']}: {user_info['email']})")

def main():
    print(f"=== Coffee Katta POS: Sample User Provisioning ({PROJECT_ID}) ===")
    token = get_access_token()
    if not token:
        print("[!] No gcloud access token available. Aborting.")
        return

    for u in USERS_TO_CREATE:
        print(f"\nProvisioning {u['role'].upper()}: {u['email']}...")
        uid, id_token = create_auth_user(u["email"], u["password"])
        if uid:
            write_firestore_user(token, uid, u)
            print(f"  -> SUCCESS! UID: {uid} | Email: {u['email']} | Pass: {u['password']} | PIN: {u['pin']}")
        else:
            print(f"  -> FAILED for {u['email']}")

if __name__ == "__main__":
    main()
