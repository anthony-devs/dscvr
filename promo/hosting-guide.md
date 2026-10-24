# Hosting the DSCVR Landing Page

You have two solid options. Vercel is easiest for Next.js; Firebase Hosting works too since you already have a project.

---

## Option 1: Vercel (Recommended)

Vercel made Next.js — zero config, free tier, instant deploys.

### Steps

1. **Push the landing page to a repo** (can be the same DSCVR repo or a separate one):

```bash
cd ~/DSCVR
git add landing/
git commit -m "Add landing page"
git push
```

Or create a separate repo:
```bash
cd ~/DSCVR/landing
git init
git add .
git commit -m "DSCVR landing page"
gh repo create dscvr-landing --private --source=. --push
```

2. **Deploy on Vercel:**
   - Go to https://vercel.com and sign in with GitHub
   - Click "Add New Project"
   - Import the repo (if it's the DSCVR repo, set Root Directory to `landing`)
   - Framework Preset will auto-detect "Next.js"
   - Click "Deploy"

3. **Custom domain (optional):**
   - In Vercel project settings > Domains
   - Add your domain (e.g. `dscvr.app` or `getdscvr.com`)
   - Update DNS as Vercel instructs

**Result:** Your site is live at `https://your-project.vercel.app` within ~60 seconds.

Every push to main auto-deploys. PRs get preview URLs.

---

## Option 2: Firebase Hosting (Static Export)

Since you already have `dscvr-9d362` on Firebase, you can add the landing page there.

### Steps

1. **Update `next.config.mjs` for static export:**

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
};

export default nextConfig;
```

2. **Build the static site:**

```bash
cd ~/DSCVR/landing
npm run build
```

This creates an `out/` folder with the static HTML.

3. **Set up Firebase Hosting** (in the landing directory):

```bash
cd ~/DSCVR/landing
firebase init hosting
# Select existing project: dscvr-9d362
# Public directory: out
# Single-page app: Yes
# Don't overwrite index.html
```

4. **Deploy:**

```bash
firebase deploy --only hosting
```

**Result:** Live at `https://dscvr-9d362.web.app` (same domain as your Flutter web app).

**Note:** If you want the landing page on a different subdomain (e.g. `www.dscvr-9d362.web.app`) while keeping the Flutter app on the base domain, use Firebase Hosting's multi-site feature:

```bash
firebase hosting:sites:create dscvr-landing
firebase target:apply hosting landing dscvr-landing
```

Then update `firebase.json` with a target for `landing`.

---

## Option 3: Quick Share (No Deploy)

For sharing right now without a deploy, you can run the dev server locally and use a tunnel:

```bash
cd ~/DSCVR/landing
npm run dev
# In another terminal:
npx localtunnel --port 3000
```

This gives you a temporary public URL to share. Not permanent, but good for quick feedback.

---

## Recommended Setup

Go with **Vercel**. It's free, takes 2 minutes, and you get:
- Automatic HTTPS
- Global CDN
- Preview deploys for branches
- Analytics
- Custom domain support
- Zero config for Next.js

Your demo link (`https://dscvr-9d362.web.app/?demo=true`) stays on Firebase Hosting.
Your landing page lives on Vercel with its own clean URL.

Replace `[LINK]` in your social posts with the Vercel URL once deployed.
