# ──────────────────────────────────────────────────────────────────────
# Test: fn_create_off_session_payment() via Stripe Test Mode
# ──────────────────────────────────────────────────────────────────────
#
# Prerequisites:
#   1. Set STRIPE_SECRET_KEY to your **test** key (sk_test_...)
#      either in .Renviron or interactively before sourcing this file.
#   2. Run this file interactively in RStudio / Quarto console.
#
# Uses an existing Stripe test customer and payment method.
# No real money is involved.
# ──────────────────────────────────────────────────────────────────────

library(httr2)
source(here::here("R", "config.R"))
source(here::here("R", "helpers.R"))
source(here::here("R", "firestore_api.R"))

# IMPORTANT: do NOT hardcode the test key here. Set it before sourcing this
# file, e.g. in ~/.Renviron:
#   STRIPE_SECRET_KEY=sk_test_...
# or interactively: Sys.setenv(STRIPE_SECRET_KEY = "sk_test_...")
stripe_key <- Sys.getenv("STRIPE_SECRET_KEY")
if (!nzchar(stripe_key)) {
  stop(
    "STRIPE_SECRET_KEY is not set.\n",
    "Set it with: Sys.setenv(STRIPE_SECRET_KEY = 'sk_test_...')"
  )
}
if (!grepl("^sk_test_", stripe_key)) {
  stop(
    "Safety check: STRIPE_SECRET_KEY must be a TEST key (sk_test_...).\n",
    "Set it with: Sys.setenv(STRIPE_SECRET_KEY = 'sk_test_...')"
  )
}

cat("Using Stripe test key:", substr(stripe_key, 1, 12), "...\n\n")

# ── Test credentials ─────────────────────────────────────────────────
TEST_CUSTOMER_ID       <- "cus_TtuqJhoJmzgVzu"
TEST_PAYMENT_METHOD_ID <- "pm_1Szb60Pk2Yv1r7CIvMnUryyv"

# ── Diagnostic: list payment methods on customer ─────────────────────
cat("═══ DIAGNOSTIC: Payment methods on customer ═══\n")
pm_list <- request(paste0(STRIPE_BASE_URL, "/customers/", TEST_CUSTOMER_ID, "/payment_methods")) |>
  req_auth_basic(stripe_key, "") |>
  req_url_query(limit = 10) |>
  req_error(is_error = function(resp) FALSE) |>
  req_perform() |>
  resp_body_json()

if (!is.null(pm_list$error)) {
  cat("  ERROR:", pm_list$error$message, "\n\n")
} else if (length(pm_list$data) == 0) {
  cat("  No payment methods found on this customer.\n")
  cat("  You may need to attach one first, or check the customer ID.\n\n")
} else {
  for (pm_item in pm_list$data) {
    cat("  ", pm_item$id, " — ", pm_item$type)
    if (!is.null(pm_item$card)) {
      cat(" (", pm_item$card$brand, " ****", pm_item$card$last4, ")")
    }
    cat("\n")
  }
  cat("\n  → Update TEST_PAYMENT_METHOD_ID above if needed.\n\n")
}

# ── Key check: make sure fn_get_stripe_key() returns the same key ─────
cat("═══ KEY CHECK ═══\n")
fn_key <- fn_get_stripe_key()
cat("  Local stripe_key:       ", substr(stripe_key, 1, 16), "...\n")
cat("  fn_get_stripe_key():    ", substr(fn_key, 1, 16), "...\n")
cat("  Keys match:             ", identical(stripe_key, fn_key), "\n\n")
if (!identical(stripe_key, fn_key)) {
  cat("  ⚠ MISMATCH! The function uses a different key.\n")
  cat("  The raw request works because it uses your test key directly,\n")
  cat("  but fn_get_stripe_key() reads a different STRIPE_SECRET_KEY.\n")
  cat("  Check if another source() file or .Renviron overrides it.\n\n")
}

# ── Test 0: Raw debug request (bypass function, see full response) ────
cat("═══ TEST 0: Raw debug request (1€) ═══\n")
debug_resp <- request(paste0(STRIPE_BASE_URL, "/payment_intents")) |>
  req_auth_basic(stripe_key, "") |>
  req_method("POST") |>
  req_body_form(
    amount         = 100,
    currency       = "eur",
    customer       = TEST_CUSTOMER_ID,
    payment_method = TEST_PAYMENT_METHOD_ID,
    confirm        = "true",
    off_session    = "true"
  ) |>
  req_error(is_error = function(resp) FALSE) |>
  req_perform()

debug_result <- resp_body_json(debug_resp)
cat("  HTTP status:", resp_status(debug_resp), "\n")

if (!is.null(debug_result$error)) {
  cat("  Error type:", debug_result$error$type, "\n")
  cat("  Error code:", debug_result$error$code %||% "(none)", "\n")
  cat("  Error message:", debug_result$error$message, "\n")
  cat("  Error param:", debug_result$error$param %||% "(none)", "\n\n")

  # Could be that the PM needs to be retrieved differently.
  # Let's try retrieving the PM directly to see if it's visible:
  cat("  Checking PM directly...\n")
  pm_check <- request(paste0(STRIPE_BASE_URL, "/payment_methods/", TEST_PAYMENT_METHOD_ID)) |>
    req_auth_basic(stripe_key, "") |>
    req_error(is_error = function(resp) FALSE) |>
    req_perform() |>
    resp_body_json()

  if (!is.null(pm_check$error)) {
    cat("  Direct PM lookup ALSO failed:", pm_check$error$message, "\n")
    cat("  → The PM might belong to a Connect account.\n")
    cat("     Try the Visa card instead: pm_1Sw70QPk2Yv1r7CIesTycBKq\n\n")
  } else {
    cat("  Direct PM lookup succeeded — PM exists.\n")
    cat("  PM customer:", pm_check$customer %||% "(not attached)", "\n")
    cat("  → This might be an API version or Connect account issue.\n\n")
  }
} else {
  cat("  PASS — PaymentIntent:", debug_result$id, "status:", debug_result$status, "\n\n")
}

# ── Test 1: Try with Visa card instead ───────────────────────────────
TEST_VISA_PM <- "pm_1Sw70QPk2Yv1r7CIesTycBKq"
cat("═══ TEST 1: Off-session charge with Visa card (1€) ═══\n")
result <- tryCatch({
  fn_create_off_session_payment(
    customer_id       = TEST_CUSTOMER_ID,
    payment_method_id = TEST_VISA_PM,
    amount_cents      = 100
  )
}, error = function(e) {
  cat("  FAIL:", conditionMessage(e), "\n")
  NULL
})

if (!is.null(result) && result$status == "succeeded") {
  cat("  PASS — PaymentIntent:", result$id, "status:", result$status, "\n")
  cat("  Amount:", result$amount / 100, "€\n\n")
} else if (!is.null(result)) {
  cat("  UNEXPECTED — status:", result$status, "\n\n")
} else {
  cat("  FAIL — see error above\n\n")
}

# ── Test 2: Realistic amount (205€ = Lindy pass) ────────────────────
cat("═══ TEST 2: Realistic amount — 205€ (Lindy pass) ═══\n")
result2 <- tryCatch({
  fn_create_off_session_payment(
    customer_id       = TEST_CUSTOMER_ID,
    payment_method_id = TEST_VISA_PM,
    amount_cents      = 20500
  )
}, error = function(e) {
  cat("  FAIL:", conditionMessage(e), "\n")
  NULL
})

if (!is.null(result2) && result2$status == "succeeded") {
  cat("  PASS — PaymentIntent:", result2$id, "status:", result2$status, "\n")
  cat("  Amount:", result2$amount / 100, "€\n\n")
} else if (!is.null(result2)) {
  cat("  UNEXPECTED — status:", result2$status, "\n\n")
} else {
  cat("  FAIL — see error above\n\n")
}

# ── Test 3: Invalid payment method ID ────────────────────────────────
cat("═══ TEST 3: Invalid payment method ID ═══\n")
result3 <- tryCatch({
  fn_create_off_session_payment(
    customer_id       = TEST_CUSTOMER_ID,
    payment_method_id = "pm_nonexistent_12345",
    amount_cents      = 100
  )
}, error = function(e) {
  cat("  PASS — correctly errored:", conditionMessage(e), "\n\n")
  "expected_error"
})

if (!identical(result3, "expected_error")) {
  cat("  FAIL — should have thrown an error\n\n")
}

# ── Test 4: has_card_on_file guard (simulates notebook logic) ────────
cat("═══ TEST 4: has_card_on_file guard logic ═══\n")
for (case in list(
  list(cust = NA,            pm = "pm_123",        expect = FALSE, label = "customer_id is NA"),
  list(cust = "",            pm = "pm_123",        expect = FALSE, label = "customer_id is empty"),
  list(cust = "cus_123",     pm = NA,              expect = FALSE, label = "payment_method_id is NA"),
  list(cust = "cus_123",     pm = "",              expect = FALSE, label = "payment_method_id is empty"),
  list(cust = "cus_123",     pm = "pm_123",        expect = TRUE,  label = "both present")
)) {
  has_card <- !is.na(case$cust) && case$cust != "" &&
              !is.na(case$pm)   && case$pm   != ""
  status <- if (has_card == case$expect) "PASS" else "FAIL"
  cat("  ", status, " — ", case$label, " → has_card_on_file =", has_card, "\n")
}

cat("\n══════════════════════════════════\n")
cat(" ALL TESTS COMPLETE\n")
cat("══════════════════════════════════\n")

