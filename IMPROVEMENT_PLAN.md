# Improvement Plan — Midnight Sun Swing Registration System

> **Constraint**: Registration is live until July 2026. Nothing can break.
> Each phase is independently valuable — you can stop after any phase and still benefit.

---

## Phase 0: Safety Nets (Do Now — Zero Risk)

These changes add protection without modifying any existing logic.

### 0.1 — Add `DRY_RUN` flag to `fn_send_email()`

Modify `R/helpers.R` so that `fn_send_email()` checks a global `DRY_RUN` flag.
When `TRUE`, it logs what *would* be sent but doesn't actually call `smtp_send`.

This is a one-line addition to the existing function. All existing notebooks
continue to work identically (the flag defaults to `FALSE`).

**Files changed**: `R/helpers.R`
**Risk**: None — additive change, default behavior unchanged.

### 0.2 — Add `_sync_metadata` sheet write

At the end of every notebook that writes to Google Sheets, add a small chunk
that writes a `_sync_metadata` tab with the timestamp and source file.
This tells anyone looking at the spreadsheet when it was last updated.

**Files changed**: `01_registration/2026_registration_lindy.qmd`,
  `01_registration/2026_registration_blues.qmd`,
  `02_confirmation_emails/2026_confirmation.qmd`,
  `02_confirmation_emails/2026_confirmation_blues.qmd`
**Risk**: None — adds a new sheet tab, doesn't touch existing tabs.

### 0.3 — Add structured audit log to confirmation notebooks

After each email send + Firestore update in the confirmation loop, append a row
to an in-memory `audit_log` tibble. At the end of the run, write it to a
`confirmation_audit_log` sheet tab.

Fields: `timestamp`, `email`, `status`, `payment_method`, `payment_captured`,
`email_sent`, `error` (if any).

**Files changed**: `02_confirmation_emails/2026_confirmation.qmd`,
  `02_confirmation_emails/2026_confirmation_blues.qmd`
**Risk**: None — additive; existing logic untouched.

### 0.4 — Git commit everything & tag the current state

Before making any changes, commit the current working state and tag it
`v2026-working` so you can always revert.

**Risk**: None.

---

## Phase 1: During Active Season (Low Risk, High Value)

These changes improve safety and reduce manual work without changing
the data flow. Do them one at a time, test after each.

### 1.1 — Enable the "Update Firebase" chunk by default

Currently `2026_registration_lindy.qmd` has the Firebase writeback chunk
set to `eval: false`. This is the root cause of the split-brain problem:
Firestore doesn't know about assignment results, so the confirmation
notebook has to join Sheets + Firestore.

**Change**: Set `eval: true` on the `update-firebase` chunk (line 842).
The chunk already has proper diffing logic — it only updates documents
whose status actually changed.

**Validation**: Run the registration notebook once with `eval: true`.
Check that Firebase documents now have `status`, `lindy_in`, `solo_in`
fields matching what's in the `final_tally` sheet.

**Files changed**: `01_registration/2026_registration_lindy.qmd`
**Risk**: Low — the chunk already exists and works, it's just gated.
The confirmation notebook still reads from Sheets for status, so even
if something goes wrong in Firebase, the email flow is unaffected.

### 1.2 — Extract pairing engine into a testable function

The core assignment logic in `2026_registration_lindy.qmd` (roughly lines
80–700) is the most complex and valuable code in the project. Extract it
into `R/pairing.R` as a pure function:

```r
fn_assign_groups <- function(df_registrations, prev_tally, capacities,
                              run_timestamp) {
 # ... all the pairing/waitlist/hold logic ...
 # Returns: final_tally tibble
}
```

The notebook then becomes:

```r
df_raw <- fn_get_registrations(...)
final_tally <- fn_assign_groups(df_raw, prev_tally,
                                 GROUP_CAPACITIES, RUN_TIMESTAMP)
write_sheet(final_tally, ...)
```

**Why now**: This doesn't change any behavior — it's a refactor. But it
lets you write tests (Phase 2) and makes the notebook much shorter and
easier to review when you run it.

**Files changed**: New `R/pairing.R`, modified `2026_registration_lindy.qmd`
**Risk**: Low — pure refactor. Run the notebook before and after and
compare `final_tally` output to verify identical results.

### 1.3 — Re-charge expired pre-auths instead of falling back to bank transfer ✅

When a Stripe pre-auth expires (7 days) and the capture fails, the current
flow sends the user bank transfer instructions. This creates manual
reconciliation work and delays payment.

**Better**: Create a new PaymentIntent using the same card, charge it
immediately off-session. The user's card is charged without them needing
to visit any page.

**This is fully supported** because the registration website already:
- Creates a Stripe Customer (`stripe_customer_id` in Firestore)
- Stores the payment method (`stripe_payment_method_id` in Firestore)
- Uses `setup_future_usage: 'off_session'` (SCA handled at registration)

**Implementation**:

Add `fn_create_off_session_payment()` to `R/firestore_api.R`:

```r
fn_create_off_session_payment <- function(customer_id, payment_method_id,
                                          amount_cents) {
  stripe_key <- fn_get_stripe_key()
  resp <- request(paste0(STRIPE_BASE_URL, "/payment_intents")) |>
    req_auth_basic(stripe_key, "") |>
    req_method("POST") |>
    req_body_form(
      amount = amount_cents,
      currency = "eur",
      customer = customer_id,
      payment_method = payment_method_id,
      confirm = "true",
      off_session = "true"
    ) |>
    req_error(is_error = function(resp) FALSE) |>
    req_perform()
  result <- resp_body_json(resp)
  if (resp_status(resp) != 200) {
    stop("Off-session payment failed: ", result$error$message)
  }
  message("Off-session payment succeeded: ", result$id)
  result
}
```

Then update the confirmation notebook's capture-failed branch:

```
Current flow:
  capture fails → send bank transfer email

New flow:
  capture fails → attempt off-session charge with same card
    → if charge succeeds → send "payment collected" email
    → if charge also fails → send bank transfer email (fallback)
```

**Prerequisites**: The confirmation notebook must read `stripe_customer_id`
and `stripe_payment_method_id` from Firestore (currently only
`stripe_payment_intent_id` is selected in `df_firebase_slim`). Add them
to the `select()` call.

**Files changed**: `R/firestore_api.R`, `02_confirmation_emails/2026_confirmation.qmd`,
  `02_confirmation_emails/2026_confirmation_blues.qmd`
**Risk**: Low — the fallback to bank transfer email remains if the
off-session charge fails. No worse than today.

### 1.4 — Unify the setup pattern ✅

Every notebook starts with slightly different `library()` calls and
`source()` patterns. Standardize them all to:

```r
source(here::here("R", "config.R"))
source(here::here("R", "helpers.R"))
source(here::here("R", "firestore_api.R"))  # only if needed
fn_setup()
```

And move all `library()` calls (dplyr, tidyr, stringr, glue, purrr,
blastula, googlesheets4) into `fn_setup()`.

**Files changed**: `R/helpers.R`, all active 2026 `.qmd` files
**Risk**: Very low — just consolidating imports.

---

## Phase 2: After Festival (July–August 2026)

The festival is over, no live registrations. This is when you make
structural changes.

### 2.1 — Write tests for the pairing engine

Using the extracted `fn_assign_groups()` from Phase 1.2, write tests
with `testthat` that cover:

- Basic leader/follower pairing
- Partner requests (mutual match)
- Capacity limits → waitlist overflow
- Solo queue ordering (priority tiers)
- Hold period expiry
- Idempotency (running twice produces same result)
- Edge cases: single registration, all leaders, all followers

Use a snapshot of real 2026 data (anonymized) as a test fixture.

**Files**: New `tests/` directory with `testthat` structure
**Depends on**: Phase 1.2

### 2.2 — Parameterize notebooks (eliminate year duplication)

Replace year-specific notebooks with parameterized ones:

```
01_registration/
├── registration_lindy.qmd      # reads CURRENT_YEAR from config.R
├── registration_blues.qmd
└── archive/
    ├── 2024_registration.qmd   # kept for reference
    ├── 2025_registration.qmd
    └── 2026_registration_lindy.qmd  # the one we refactored from
```

The key changes:
- Remove all hardcoded year references from notebook logic
- The 2024/2025 Google Sheets → Firestore difference is handled by a
  config flag (`DATA_SOURCE = "firestore"` vs `DATA_SOURCE = "sheets"`)
- Email copy comes entirely from `config.R` (already mostly true)

**Depends on**: Phase 1.2 (pairing engine extracted), Phase 1.4 (setup unified)

### 2.3 — Make Firestore the single source of truth

Now that Firebase writeback is enabled (Phase 1.1), flip the confirmation
notebook to read assignment results from Firestore instead of Sheets:

```r
# Before (current):
final_tally <- read_sheet(GOOGLE_SHEETS$registrations_2026, sheet = "final_tally")
df_firebase <- fn_get_registrations()
df_registrations <- final_tally |> left_join(df_firebase_slim, by = "id")

# After:
df_registrations <- fn_get_registrations(
  filters = list(pass = c("lindy", "lindy_solo"))
)
# Everything is already in Firestore — no join needed
```

Google Sheets becomes write-only (mirror for humans). Add a standalone
`refresh_sheet.qmd` notebook that dumps Firestore → Sheets on demand.

**Depends on**: Phase 1.1 (Firebase writeback enabled and validated)

### 2.4 — Move to a transactional email provider

Replace blastula + Gmail SMTP with a proper provider (Resend, Postmark,
or Amazon SES). Benefits:

- No more `Sys.sleep(2)` rate limiting
- Delivery tracking (bounces, opens)
- No dependency on local `gmail_creds` file
- Higher sending limits

Keep `fn_send_email()` as the interface — just swap the implementation.

**Files changed**: `R/helpers.R`
**Depends on**: Nothing — can be done anytime after the festival.

---

## Phase 3: Before 2027 Registration Opens

### 3.1 — Convert shared code to an R package

Turn `R/` into a proper R package (`msstools` or similar):

```
msstools/
├── DESCRIPTION
├── NAMESPACE
├── R/
│   ├── config.R
│   ├── helpers.R
│   ├── firestore_api.R
│   └── pairing.R
├── tests/
│   └── testthat/
└── man/
```

Notebooks load it with `devtools::load_all()` during development or
`library(msstools)` if installed.

**Benefits**: Namespace isolation (no more `rm(list = ls())`), proper
dependency management, testable, documented.

### 3.2 — Consolidate repos (optional)

If the `stripe-preauth-website` is stable and rarely changes, consider
a monorepo:

```
midnightsun_swing/
├── website/           # stripe-preauth-website code
├── processing/        # R notebooks + msstools package
├── shared/
│   └── SCHEMA.md      # Firestore document schema (shared contract)
└── README.md
```

Even if you keep separate repos, create `SCHEMA.md` documenting every
field in the Firestore `registrations` collection, which system writes
it, and its allowed values.

### 3.3 — Add a Firebase Cloud Function for Sheets sync (optional)

If you want the spreadsheet to update in real-time (every new
registration appears immediately), deploy a small Cloud Function that
triggers on Firestore writes and upserts rows in the spreadsheet.

This is optional — the "write Sheets at end of notebook run" pattern
from Phase 0.2 may be sufficient.

---

## Implementation Order (Visual)

```
NOW (registration is live)
│
├── 0.4  Git tag current state
├── 0.1  DRY_RUN flag
├── 0.2  _sync_metadata sheet
├── 0.3  Audit log in confirmation
│
├── 1.1  Enable Firebase writeback chunk
├── 1.3  Re-charge expired pre-auths (off-session) ✅
├── 1.4  Unify setup pattern ✅
├── 1.2  Extract pairing engine → R/pairing.R
│
JULY (festival happens)
│
├── 2.1  Tests for pairing engine
├── 2.2  Parameterize notebooks + archive old years
├── 2.3  Firestore as single source of truth
├── 2.4  Transactional email provider
│
BEFORE 2027 REGISTRATION
│
├── 3.1  R package
├── 3.2  Monorepo / shared schema
└── 3.3  Cloud Function for Sheets sync (optional)
```

---

## What NOT to Change

- **Don't touch 2024/2025 notebooks** — they're historical artifacts.
  Archive them but don't refactor them.
- **Don't change the Firestore schema** during active registration.
  Only add new fields, never rename or remove existing ones.
- **Don't automate email sending** — keep it manual with review.
  The DRY_RUN flag + preview chunk is the right level of safety.
- **Don't migrate away from Google Sheets entirely** — it's genuinely
  useful for co-organizer visibility. Just make it write-only.
