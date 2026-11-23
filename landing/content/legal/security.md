How we look after your account and your library.

## Sign-in and accounts

- Passwords are handled by Google's Firebase Authentication. We never see or store them.
- You can sign in with Google. Every sign-in is checked on our server before any of your data is read.
- Settings lists the devices you are signed in on, and you can sign any of them out.

## Your data

- Everything travels over HTTPS.
- Your library, notes, Pinda conversations and reports are stored in Google Cloud (Firestore and Cloud Storage) and are private to you unless you share them.
- You can delete your account from Settings. That removes your library, files and sign-in.
- Card payments are handled by Paystack. We never see or store your card number.

## How the service is run

- The app and API run on Google Cloud Run and Firebase Hosting, behind rate limits that stop abuse.
- Links and files fetched on your behalf go through checks that block private network addresses.
- Staff access to the admin console needs a password and a second factor.

## Report a vulnerability

If you find a security problem, please write to [mail@askpinda.com](mailto:mail@askpinda.com) before making it public. Include what you found and how to reproduce it. We will reply within three working days, fix real issues quickly and credit you if you like. Please don't access other people's data or disrupt the service while testing.

Our contact details for researchers are also in [security.txt](/.well-known/security.txt).
