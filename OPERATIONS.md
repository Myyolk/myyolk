# MyYolk Operations Manual

Last updated: May 15, 2026

This is the single source of truth for operating MyYolk. If something breaks at 2am, the answer is probably in here.

---

## 1. Quick Reference

### Daily commands cheat sheet

**Deploy a code change (after replacing `myyolk-beta.html` in `~/Desktop/myyolk/`):**
```bash
cd ~/Desktop/myyolk
git add myyolk-beta.html
git commit -m "Description of what changed"
git push
```

**Push live (after testing on beta):**
```bash
cp myyolk-beta.html myyolk-app.html
git add myyolk-app.html
git commit -m "Promote beta to live"
git push
```

**Hard refresh in browser:** `Cmd + Shift + R`

**Cache-bust URL when testing:** add `?bust=N` to the URL (e.g., `myyolk.com/myyolk-beta.html?bust=5`)

---

### "How do I..." quick lookups

| Task | Where to do it |
|---|---|
| Grant someone permanent Pro | Edit `ADMIN_EMAILS` in `myyolk-beta.html`, push to GitHub |
| Grant someone N months of Pro | Supabase SQL Editor: `UPDATE user_data SET pro_until = NOW() + INTERVAL '2 months' WHERE user_id = 'uuid';` |
| Revoke someone's Pro | Supabase SQL Editor: `UPDATE user_data SET pro_until = NULL WHERE user_id = 'uuid';` |
| Find someone's UUID | Supabase → Authentication → Users → search email → copy ID |
| See user signups | Supabase → Authentication → Users |
| Check Edge Function logs | Supabase → Edge Functions → parse-paystub (or parse-ssa) → Logs |
| Update Anthropic credit | platform.claude.com → Billing |
| Renew GitHub token | github.com/settings/tokens → click your token → Regenerate |
| Roll back a broken deploy | `git revert HEAD && git push` |

---

### Key URLs

| Service | URL | Login |
|---|---|---|
| Live app | https://myyolk.com/myyolk-app.html | (no login needed) |
| Beta app | https://myyolk.com/myyolk-beta.html | (no login needed) |
| GitHub repo | https://github.com/Myyolk/myyolk | username: `Myyolk` |
| Supabase dashboard | https://supabase.com/dashboard/project/lcecdqihjdpmsmiwabkk | (your Supabase login) |
| Anthropic console | https://platform.claude.com | dean.p.sheppard@gmail.com |
| Local repo on Mac | `~/Desktop/myyolk/` | — |
| Old repo backup | `~/Downloads/myyolk/` | (DO NOT DELETE — safety net) |

---

## 2. Architecture Overview

MyYolk is intentionally simple. Four pieces:

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  USER'S BROWSER                                              │
│  └─ myyolk-beta.html or myyolk-app.html (one big HTML file)  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
                            │
              served by     ▼
┌──────────────────────────────────────────────────────────────┐
│ GITHUB PAGES (hosting)                                        │
│ — Static file hosting, free, automatic on git push           │
│ — myyolk.com is a custom domain pointing here                │
└──────────────────────────────────────────────────────────────┘

When the user clicks Save or Sign In, the HTML talks to Supabase:

┌──────────────────────────────────────────────────────────────┐
│ SUPABASE (backend)                                            │
│ — Auth (sign in, password reset)                              │
│ — Database (user_data table stores user plans)               │
│ — Edge Functions (parse-paystub, parse-ssa)                  │
│ — Secrets (ANTHROPIC_API_KEY)                                │
└──────────────────────────────────────────────────────────────┘

When user uploads a pay stub or SSA statement, the Edge Function calls:

┌──────────────────────────────────────────────────────────────┐
│ ANTHROPIC API (Claude)                                        │
│ — Reads the PDF/image                                         │
│ — Returns structured JSON with the parsed data               │
│ — Costs ~$0.02 per upload                                    │
└──────────────────────────────────────────────────────────────┘
```

**Single-file HTML model:** The whole app is one HTML file (~650KB). All HTML, CSS, and JavaScript live inside it. There's no build step, no bundler, no framework. Edits happen with Python scripts that do `str.replace` on the file.

**Why single-file:** Faster iteration. No `npm run build` between every change. Cost: harder to maintain as it grows — eventually MyYolk will outgrow this, but not yet.

---

## 3. GitHub

### Repo info

- **URL:** https://github.com/Myyolk/myyolk
- **Owner:** Myyolk (the account, not your personal one)
- **Main branch:** `main`
- **Local clone:** `~/Desktop/myyolk/`
- **Backup local clone:** `~/Downloads/myyolk/` (do NOT delete — safety net)

### Files in the repo

| File | Purpose |
|---|---|
| `myyolk-beta.html` | Beta version — where you test new features |
| `myyolk-app.html` | Live version — what paying customers see |
| `index.html` | Landing page at myyolk.com |
| `OPERATIONS.md` | This file |

### The Personal Access Token (PAT)

GitHub no longer accepts your password for `git push`. You need a PAT.

**Your current token:** Stored in Google Password Manager under `github.com / Myyolk`. Also cached in macOS Keychain so Terminal usually doesn't ask.

**When the token expires:**

GitHub emails you ~15 hours before expiration. Click the regenerate link in the email or go to **github.com/settings/tokens** → click your token → **Regenerate**.

**Critical settings when regenerating:**
- Expiration: **No expiration** (so you don't get bothered again)
- Scopes: `repo` only

**Save the new token immediately** — it's only shown once. Copy to Google Passwords.

**If `git push` fails after regenerating:**

```bash
# Clear stale token from Keychain
printf "host=github.com\nprotocol=https\n\n" | git credential-osxkeychain erase

# Then push — it'll prompt for username and password
git push
```

When prompted:
- Username: **`Myyolk`** (not your email)
- Password: paste the new token

### Standard deploy workflow

This is the workflow we use for every change:

1. Claude makes the edit using a Python script in `/home/claude/`
2. Claude provides a downloaded `myyolk-beta.html`
3. You drop it into `~/Desktop/myyolk/` (replacing the existing file)
4. Run:
   ```bash
   cd ~/Desktop/myyolk
   git add myyolk-beta.html
   git commit -m "What changed"
   git push
   ```
5. Wait ~30 seconds for GitHub Pages to deploy
6. Hard-refresh the beta URL (`Cmd+Shift+R`)
7. Verify it works

**Pre-deploy backup (recommended for big changes):**
```bash
cp myyolk-beta.html myyolk-beta-backup-$(date +%Y%m%d-%H%M%S).html
```

### Rolling back a bad deploy

```bash
cd ~/Desktop/myyolk
git revert HEAD       # creates a new commit that undoes the last one
git push
```

Or to roll back multiple commits:
```bash
git log --oneline             # find the commit hash you want to go back to
git reset --hard <hash>       # WARNING: discards uncommitted local changes
git push --force              # force-push the rollback
```

### Promoting beta to live

When `myyolk-beta.html` is stable and tested:

```bash
cd ~/Desktop/myyolk
cp myyolk-beta.html myyolk-app.html
git add myyolk-app.html
git commit -m "Promote beta to live"
git push
```

---

## 4. Supabase

### Project info

- **Project URL:** `https://lcecdqihjdpmsmiwabkk.supabase.co`
- **Project ref:** `lcecdqihjdpmsmiwabkk`
- **Dashboard:** https://supabase.com/dashboard/project/lcecdqihjdpmsmiwabkk
- **Region:** (whichever you picked — visible in Settings)

### Keys (where they live, what they do)

| Key | Found at | Used by | Safe to expose? |
|---|---|---|---|
| **Anon (publishable) key** | Project Settings → API → `anon` key | Browser JS in `myyolk-beta.html` | ✅ Yes — designed to be public |
| **Service role key** | Project Settings → API → `service_role` key | Edge Functions (server-side only) | ❌ NEVER expose in browser |

Your anon key is already hardcoded in the HTML — that's by design. The service role key is NOT in the HTML; it lives only in Supabase secrets where Edge Functions can read it.

### The `user_data` table

This is where all user plan data lives. One row per user.

| Column | Type | Purpose |
|---|---|---|
| `id` | uuid | Internal row ID |
| `user_id` | uuid | Links to auth.users — who owns this row |
| `data` | jsonb | The user's full MyYolk plan (big JSON blob) |
| `updated_at` | timestamptz | Last save time |
| `pro_until` | timestamptz | When Pro access expires (NULL = not Pro this way) |

**To inspect:** Supabase → Table Editor → user_data

### Edge Functions

| Function | URL | Purpose | JWT Verification |
|---|---|---|---|
| `parse-paystub` | `/functions/v1/parse-paystub` | Reads pay stub PDFs via Claude | OFF |
| `parse-ssa` | `/functions/v1/parse-ssa` | Reads SSA statement PDFs via Claude | OFF |

**To view/edit code:** Supabase → Edge Functions → click function → Code tab

**To see logs:** Supabase → Edge Functions → click function → Logs tab. Shows every call, what it received, what it returned, any errors.

**To redeploy:** Edit the code in the editor → click "Deploy updates" → confirm.

**To update secrets:** Supabase → Edge Functions → Secrets in left sidebar.

Currently stored secrets:
- `ANTHROPIC_API_KEY` — used by both parse-paystub and parse-ssa

### Common SQL operations (SQL Editor)

Navigate to: Supabase dashboard → SQL Editor in left sidebar.

**⚠️ Warning:** Supabase remembers the last saved query you opened. Always check what's in the editor before clicking Run. Clear it or write fresh.

#### Grant Pro for 2 months
```sql
UPDATE user_data 
SET pro_until = NOW() + INTERVAL '2 months' 
WHERE user_id = 'their-uuid-here';
```

#### Grant Pro for 1 year
```sql
UPDATE user_data 
SET pro_until = NOW() + INTERVAL '1 year' 
WHERE user_id = 'their-uuid-here';
```

#### Revoke Pro
```sql
UPDATE user_data 
SET pro_until = NULL 
WHERE user_id = 'their-uuid-here';
```

#### Find someone's UUID by email

Supabase → Authentication → Users → search by email → click the row → copy the UUID. There's no SQL way to do this from the SQL Editor by default (auth.users is hidden).

#### See all users with active Pro (via pro_until)
```sql
SELECT user_id, pro_until 
FROM user_data 
WHERE pro_until > NOW();
```

#### Delete a user's plan data (but keep their account)
```sql
DELETE FROM user_data WHERE user_id = 'their-uuid';
```

#### Count total signups
```sql
SELECT COUNT(*) FROM auth.users;
```

#### Count users who've saved at least once
```sql
SELECT COUNT(*) FROM user_data;
```

### Auth users

**To see all signups:** Supabase → Authentication → Users

**To delete a user's account entirely:** Click the row → three-dot menu → Delete user. This cascades to delete their `user_data` row.

**To send a password reset:** Click row → three-dot menu → Send password recovery.

---

## 5. Anthropic API

### Account info

- **Login:** dean.p.sheppard@gmail.com
- **URL:** platform.claude.com
- **API key location:** Stored as Supabase secret `ANTHROPIC_API_KEY`. The actual key is in the Anthropic console under API Keys.

### Pricing

- **Pay stub parse:** ~$0.02 per upload
- **SSA parse:** ~$0.02 per upload
- **Model used:** `claude-sonnet-4-5`

### Topping up

1. Go to platform.claude.com → Billing
2. Add credit (start with $5-10, scales fine for testing)
3. The API key automatically uses available credit

### Monitoring usage

platform.claude.com → Usage shows daily API calls and spend.

### If parse-paystub or parse-ssa stops working

1. Check Supabase Edge Function logs first (most informative)
2. Common causes:
   - Out of Anthropic credit → top up
   - JWT toggle accidentally turned ON → turn OFF
   - API key revoked or expired → regenerate in Anthropic console, update Supabase secret

---

## 6. Admin Allowlist & Pro Access

### How Pro access is determined

A user becomes Pro if **either**:

1. Their email is in `ADMIN_EMAILS` in `myyolk-beta.html`, **OR**
2. Their `user_data.pro_until` is a future date

### Current ADMIN_EMAILS

```js
var ADMIN_EMAILS = [
  'dean.p.sheppard@gmail.com',       // Dean
  'myyolkapp@gmail.com',             // System account
  'qatest@myyolk.com',               // QA test
  'densies@gmail.com',               // Densie
  'brookeabby@icloud.com',           // Brooke
  'jamiefaithsheppard@gmail.com',    // Jamie
  // 'bill@example.com',             // Bill - TBC
];
```

### Adding a new admin (permanent free Pro)

1. Edit `myyolk-beta.html` (and `myyolk-app.html` when promoting to live)
2. Add their email to `ADMIN_EMAILS`
3. Push to GitHub
4. They sign in and get Pro automatically

### Granting time-limited Pro (rewards, future Stripe)

Run in Supabase SQL Editor:
```sql
UPDATE user_data 
SET pro_until = NOW() + INTERVAL '2 months' 
WHERE user_id = 'their-uuid';
```

They get Pro until that date passes. After that, automatically back to free.

### Checking who's Pro right now

```sql
-- Users with active pro_until
SELECT u.email, ud.pro_until
FROM auth.users u
JOIN user_data ud ON ud.user_id = u.id
WHERE ud.pro_until > NOW()
ORDER BY ud.pro_until DESC;
```

---

## 7. The Python Deploy Workflow

### Why this exists

Editing 650KB of HTML manually is error-prone. Python scripts let us make precise, repeatable edits.

### The standard pattern

Every Python script Claude writes follows this shape:

```python
PATH = "/home/claude/myyolk-beta.html"

with open(PATH, "r", encoding="utf-8") as f:
    html = f.read()

OLD = """exact existing text"""
NEW = """replacement text"""

if html.count(OLD) != 1:
    print(f"ERROR: expected 1 match, got {html.count(OLD)}")
    sys.exit(1)

html = html.replace(OLD, NEW)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(html)
```

The `count() != 1` check is critical — if the OLD string matches 0 or 2+ places, the script aborts instead of breaking things silently.

### Rules of thumb (these have saved us many times)

1. **Always `grep -n` first** to find exact existing text before writing the OLD string
2. **Never edit HTML files locally in Claude's environment and just deliver the result** — always use Python str.replace scripts so the diff is reviewable
3. **Never use `zsh heredoc`** for baking changes into HTML — fragile with quotes/special chars
4. **Backup before complex multi-patch deploys:** `cp myyolk-beta.html myyolk-beta-backup-$(date +%Y%m%d-%H%M%S).html`

---

## 8. Common Breakage Scenarios + Fixes

### "Git push fails with Invalid username or token"

Token expired or got corrupted. See **Section 3 → The Personal Access Token** above.

### "Edge function returns Invalid JWT"

The JWT toggle on the Edge Function got switched ON. Fix:

1. Supabase → Edge Functions → click the function (parse-paystub or parse-ssa)
2. Settings tab
3. **Verify JWT with legacy secret** → toggle OFF
4. Save changes

### "GitHub Pages showing old version"

GitHub Pages caches aggressively. Two fixes:

1. **Hard refresh in browser:** `Cmd+Shift+R`
2. **Cache-bust URL:** append `?bust=N` (e.g., `myyolk.com/myyolk-beta.html?bust=5`). Increment N each time.

If still stale, wait 1-2 minutes — global CDN propagation takes time.

### "User says they can't sign in"

1. Supabase → Authentication → Users → search their email
2. Check: do they exist? Is account confirmed?
3. If unconfirmed: click row → "Send confirmation email"
4. If forgot password: click row → "Send password recovery"

### "Pay stub OCR returns garbage / errors"

1. Supabase → Edge Functions → parse-paystub → Logs tab
2. Look at the most recent failed call
3. Common causes:
   - **"ANTHROPIC_API_KEY not configured"** → Secret got deleted. Re-add it.
   - **"Anthropic API error: 401"** → Bad API key. Regenerate at platform.claude.com.
   - **"Anthropic API error: 429"** → Rate limit. Out of credit. Top up.
   - **"Could not parse Claude response as JSON"** → Claude returned malformed JSON. Rare. Check the `raw` field in the error.

### "I broke the site — need to revert"

```bash
cd ~/Desktop/myyolk
git log --oneline | head      # find the commit hash from before the break
git reset --hard <hash>       # local rollback
git push --force              # update GitHub
```

Hard refresh and the broken version is gone within 1-2 min.

---

## 9. Pricing Model & Tiers (Current)

### Pricing (as of May 15, 2026)

- **Monthly:** $12.99/mo
- **Annual:** $99/yr (37% savings vs monthly)

### Refund policy

> *"Try MyYolk Pro for 30 days. If it's not for you, email info@myyolk.com for a full refund. No questions asked. After 30 days, no refunds — but you can cancel anytime and keep access through the end of your billing period."*

### Tier breakdown

| Feature | Anonymous | Free signup | Pro |
|---|---|---|---|
| Profile + first projection | ✅ | ✅ | ✅ |
| Income/Accounts/SS (manual) | ❌ signup gate | ✅ | ✅ |
| Pay stub upload OCR | ❌ | ❌ | ✅ Pro |
| SSA upload OCR | ❌ | ❌ | ✅ Pro |
| Statement Import (CSV) | ❌ | ❌ | ✅ Pro |
| Budget Tracker | ❌ | ❌ | ✅ Pro |
| Budget Planner / Projections / Readiness | ❌ | ✅ | ✅ |
| What-If / Early Retirement / Summary | View-only with preview demo | View-only with preview demo | ✅ Full |

### Where pricing is referenced in the code

- Paywall modal subtitle
- Upgrade banners on the 4 Pro tabs
- Toast notification

Search the HTML for `$99` or `$12.99` to find all references.

---

## 10. What's NOT Documented Yet (TBD)

These are coming. Update this section as they ship:

- [ ] **Stripe wiring** — Checkout flow, webhook, subscription management. Pricing already set ($12.99/mo, $99/yr). Account not yet created.
- [ ] **Roth conversion modeling** — Simple v1 of the Pro feature.
- [ ] **Demo video** — Script and screen recordings to hand to a Billo/Fiverr UGC creator.
- [ ] **Legal pages** — Terms of Service. Privacy Policy may need updates for billing.
- [ ] **Refund handling** — Workflow for processing a refund request (use Stripe's refund button + revoke pro_until).
- [ ] **Email automation** — Welcome email on signup. Monthly check-in reminder. Currently uses Resend via Supabase Edge Functions + pg_cron.

---

## Glossary

- **Edge Function** — Server-side code that runs on Supabase's servers, not in the user's browser. Used when you need to keep secrets (API keys) hidden or do heavy work.
- **JWT** — A signed token that proves who a user is. Supabase uses these for auth.
- **pg_cron** — A Postgres extension that schedules SQL to run on a recurring basis (e.g., monthly).
- **PAT (Personal Access Token)** — A long random string GitHub uses instead of a password for command-line git operations.
- **PR (Pull Request)** — A way to propose changes on GitHub before merging. We don't use these; we commit directly to main.
- **RLS (Row Level Security)** — Supabase feature that controls which users can read/write which rows in the database.
- **Resend** — Third-party service for sending transactional emails (signup confirmations, password resets, etc.).
- **Webhook** — A URL that an external service (Stripe, GitHub) calls when something happens, so your app can react.

---

*End of manual. Update this whenever something changes. Last revision: May 15, 2026.*
