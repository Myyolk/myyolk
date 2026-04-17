# MyYolk — Monthly Check-In Reminder Setup

## What this does
On the 3rd of every month, sends a branded email to every Pro user who hasn't
logged the previous month in their Budget Tracker. Email includes:
- Previous month budget vs actual totals
- Over-budget category callouts (top 5)
- One-click deep link to the Budget Tracker tab

---

## Step 1 — Get a free Resend account (2 min)

1. Go to https://resend.com and sign up (free tier = 3,000 emails/month)
2. Add and verify your domain `myyolk.com` (DNS records, takes ~10 min to propagate)
3. Create an API key → copy it

---

## Step 2 — Add secrets to Supabase

In Supabase Dashboard → Settings → Edge Functions → Secrets, add:

| Secret name         | Value                        |
|---------------------|------------------------------|
| `RESEND_API_KEY`    | Your Resend API key          |

The `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically available
in all edge functions — no need to add them manually.

---

## Step 3 — Deploy the edge function

Install Supabase CLI if you haven't:
```bash
brew install supabase/tap/supabase
```

Login and link your project:
```bash
supabase login
supabase link --project-ref lcecdqihjdpmsmiwabkk
```

Deploy:
```bash
supabase functions deploy send-checkin-reminder
```

---

## Step 4 — Set up the cron schedule

1. Open Supabase Dashboard → SQL Editor
2. Open `cron-setup.sql`
3. Replace `YOUR_PROJECT_REF` with `lcecdqihjdpmsmiwabkk`
4. Replace `YOUR_ANON_KEY` with your project's anon key (Settings → API)
5. Run the SQL

---

## Step 5 — Test it manually

Option A — via SQL Editor (uncomment the manual trigger at the bottom of cron-setup.sql)

Option B — via curl:
```bash
curl -X POST https://lcecdqihjdpmsmiwabkk.supabase.co/functions/v1/send-checkin-reminder \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

The response will show `{ sent: N, skipped: N, errors: N }`.

---

## Email from address

The function sends from `reminders@myyolk.com`. Make sure this address is
verified in Resend under your myyolk.com domain. Alternatively change it to
`myyolkapp@gmail.com` temporarily while testing (Resend supports Gmail for
testing on free tier).

---

## Notes
- Users who already logged the current month are automatically skipped
- Users with no budget set up at all are skipped
- The `isManual` flag (POST requests) bypasses the "already logged" check
  so you can test against real accounts
