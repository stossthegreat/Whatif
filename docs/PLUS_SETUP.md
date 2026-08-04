# Rivlr+ — turning subscriptions on

The code shipped in build 63 is complete and tested, but it stays **dormant**
until the accounts below exist. Nothing breaks while it's off: no paywall
appears, every account behaves as free, and the app runs exactly as it did in
build 62. Work top to bottom.

---

## 1. App Store Connect — the money agreement

Nothing purchasable works until this is done, no matter what the code says.

1. **Business → Agreements, Tax, and Banking** → complete the **Paid
   Applications** agreement. It needs your bank details and tax forms.
   Status must read **Active**.
2. Apply for the **App Store Small Business Program**
   (developer.apple.com/app-store/small-business-program). Commission drops
   from 30% to **15%** while you earn under $1M/year. This is free money —
   do it before your first sale.

## 2. App Store Connect — the two products

**Your app → Monetization → Subscriptions → create a group** called
`Rivlr Plus`. Inside it, create two auto-renewable subscriptions:

| Product ID | Duration | Price |
|---|---|---|
| `rivlr_plus_weekly` | 1 week | 4.99 |
| `rivlr_plus_monthly` | 1 month | 14.99 |

Each product needs a **display name**, a **description**, and a **review
screenshot** (a photo of the paywall screen is fine) or review will reject it.

Prices are read from the store at runtime — changing them later needs no new
build.

## 3. RevenueCat

1. Create a project → add an **App Store** app → paste your bundle id
   `com.rivlr.app` and your **App-Specific Shared Secret** (App Store
   Connect → your app → App Information).
2. **Products** → import/add both product IDs above.
3. **Entitlements** → create one called exactly **`plus`** → attach both
   products.
4. **Offerings** → create the default offering (`default`) with two packages:
   Weekly → `rivlr_plus_weekly`, Monthly → `rivlr_plus_monthly`.
   The paywall shows packages in this order, and marks the **last one** as
   "Best value" — so put monthly second.
5. **API keys** → copy two things:
   - the **public Apple SDK key** (starts `appl_…`)
   - a **secret v1 API key**
6. **Integrations → Webhooks** → add
   `https://<your-railway-domain>/api/rc/webhook`, and set the
   **Authorization header** to a long random string you invent.

## 4. Put the keys in place

**In the app** — `lib/revenuecat_config.dart`:

```dart
static const String appleKey = 'appl_XXXXXXXXXXXX';   // public SDK key
```

That single line is what switches the paid layer on in the client.

**On Railway** — add two variables and redeploy:

| Variable | Value |
|---|---|
| `RC_SECRET_KEY` | the secret v1 API key |
| `RC_WEBHOOK_AUTH` | the exact Authorization string from step 3.6 |

The server logs `RC_SECRET_KEY not set — Rivlr+ is off` on boot until this is
done, so the boot log tells you whether it took.

## 5. Test it before real money

1. App Store Connect → **Users and Access → Sandbox Testers** → create one.
2. On the device: Settings → App Store → sign out of the sandbox account,
   then run the TestFlight build and buy — iOS will prompt for the sandbox
   login at purchase time.
3. Check, in order:
   - the paywall shows **real prices** (not "Loading plans…")
   - after buying, Settings shows **Who you meet** without the Rivlr+ tag
   - picking "women only" sticks after force-quitting and reopening
   - **Restore purchases** works after deleting and reinstalling the app
   - RevenueCat dashboard → the customer shows the `plus` entitlement
   - Railway logs show the webhook arriving

Sandbox subscriptions renew every few minutes instead of weekly, so you can
watch a renewal and an expiry inside half an hour.

---

## How entitlement actually works (for future you)

- The phone **never** decides who is Plus. It asks the server, and the server
  asks RevenueCat.
- `users.plus_until` in Postgres is the single source of truth. Everything
  gated reads `isPlus(user)`, which is just that timestamp vs now.
- Webhooks are only a **trigger**: on any event we re-ask RevenueCat what's
  true, so we never have to interpret event types (a `CANCELLATION` means
  auto-renew is off, *not* access ended — getting that backwards would cut
  off people who already paid).
- Every webhook is deduped on RevenueCat's `event.id` and written to the
  `purchases` table, so a retried delivery can't double-apply.
- If RevenueCat is unreachable, we **never revoke** — worst case the entitlement
  stays as it was until the next successful check.
- A lapsed subscription drops the filter back to "everyone" but keeps the
  saved preference, so resubscribing restores what they picked.
