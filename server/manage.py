#!/usr/bin/env python3
"""Server setup helpers.

    python manage.py hash-password   prompts for the admin password, prints ADMIN_PASSWORD_HASH
    python manage.py gen-secret      a random value for ADMIN_KEY, SESSION_SECRET, DEV_API_SECRET or CRON_SECRET
    python manage.py alerts          finds new items for everyone with alerts on (run daily)
"""
import getpass
import secrets
import sys

from staff import hash_password, password_problems


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
        print("Put both on the server (Railway > Variables), plus ADMIN_KEY and SESSION_SECRET from: python manage.py gen-secret")
        return 0
    print(__doc__)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
