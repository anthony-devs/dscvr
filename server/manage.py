#!/usr/bin/env python3
"""Server setup helpers.

    python manage.py hash-password   prompts for the admin password, prints ADMIN_PASSWORD_HASH
    python manage.py totp-setup      makes the authenticator secret (ADMIN_TOTP_SECRET) and the QR to scan
    python manage.py gen-secret      a random value for SESSION_SECRET, DEV_API_SECRET or CRON_SECRET
    python manage.py alerts          finds new items for everyone with alerts on (run daily)
"""
import getpass
import secrets
import sys

from passwords import hash_password, password_problems, totp_at, totp_new_secret, totp_uri


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "gen-secret":
        print(secrets.token_urlsafe(48))
        return 0
    if cmd == "alerts":
        from config import Config
        from security import init_firebase
        import alerts
        init_firebase(Config.FIREBASE_PROJECT_ID)
        print(alerts.run())
        return 0
    if cmd == "totp-setup":
        user = (input("Admin username (same as ADMIN_USERNAME): ").strip().lower()) or "founder"
        secret = totp_new_secret()
        uri = totp_uri(secret, user)
        print(f"\nADMIN_TOTP_SECRET={secret}\n")
        print("Add it to your authenticator app (Google Authenticator, Authy, 1Password, Microsoft Authenticator):")
        print("  1. Open the app, tap +, then 'Enter a setup key'.")
        print(f"  2. Account: DSCVR Admin. Key: {secret}. Type: time based.")
        try:
            import qrcode  # optional: pip install qrcode
            img = qrcode.make(uri)
            img.save("admin-totp-qr.png")
            print("  Or scan admin-totp-qr.png (delete it afterwards).")
        except Exception:  # noqa: BLE001
            print("  (Install 'qrcode[pil]' if you would rather scan a QR code.)")
        print("\nThen put ADMIN_TOTP_SECRET on the server (Railway > Variables). Keep it private, like a password.")
        print(f"Check: the app should now show a 6-digit code. For reference the code right now is {totp_at(secret, int(__import__('time').time() // 30))}.")
        return 0
    if cmd == "hash-password":
        user = input("Admin username (ADMIN_USERNAME): ").strip().lower()
        pw = getpass.getpass("Password: ")
        bad = password_problems(pw, user)
        if bad:
            print("Too weak. It needs " + ", ".join(bad) + ".")
            return 1
        if pw != getpass.getpass("Again: "):
            print("They don't match.")
            return 1
        print(f"\nADMIN_USERNAME={user}\nADMIN_PASSWORD_HASH={hash_password(pw)}\n")
        print("Put both on the server (Railway > Variables). Then run: python manage.py totp-setup")
        return 0
    print(__doc__)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
