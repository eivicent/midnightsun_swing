# MSS 2026 — Generate ePassi & Invoice payment sheet
#
# Creates a single Google Sheet tab listing all ePassi and Invoice
# participants across both Lindy and Blues.

rm(list = ls())
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)
library(googlesheets4)
library(here)

source(here::here("R", "config.R"))
source(here::here("R", "firestore_api.R"))
source(here::here("R", "helpers.R"))

PAID_STATUSES <- c("paid_organiser", "paid_BPS")

# ── 1. Load tallies ─────────────────────────────────────────────────────────

lindy_tally <- read_sheet(GOOGLE_SHEETS$registrations_2026, sheet = "final_tally")
blues_tally <- read_sheet(GOOGLE_SHEETS$registrations_2026_blues, sheet = "blues_final_tally")

cat("Lindy:", nrow(lindy_tally), "rows | Blues:", nrow(blues_tally), "rows\n")

# ── 2. Firebase payment details ─────────────────────────────────────────────

df_firebase <- fn_get_registrations() |>
  filter(!is.na(email) & email != "") |>
  mutate(email = str_to_lower(email))

for (col in c("stripe_payment_intent_id", "payment_method", "payment_status")) {
  if (!col %in% names(df_firebase)) df_firebase[[col]] <- NA_character_
}
if (!"fan" %in% names(df_firebase)) df_firebase$fan <- FALSE

firebase_slim <- df_firebase |>
  select(id, stripe_payment_intent_id, payment_method, payment_status, fan)

# ── 3. Build combined table ─────────────────────────────────────────────────

infer_payment <- function(df) {
  df |>
    select(-any_of("payment_status")) |>
    left_join(firebase_slim, by = "id") |>
    mutate(
      name  = str_to_title(name),
      email = str_to_lower(email),
      payment_method = case_when(
        !is.na(payment_method) & payment_method != "" ~ payment_method,
        !is.na(stripe_payment_intent_id) &
          stripe_payment_intent_id != ""              ~ "card",
        TRUE                                          ~ "epassi"
      )
    )
}

df_lindy <- infer_payment(lindy_tally) |>
  filter(status %in% c("CONFIRMED", "PARTIAL"),
         payment_method %in% c("epassi", "invoice"),
         !payment_status %in% PAID_STATUSES) |>
  mutate(
    confirmed_for = pmap_chr(list(lindy_in, solo_in), function(l, s) {
      parts <- c(if (coalesce(l, FALSE)) "Lindy", if (coalesce(s, FALSE)) "Solo")
      if (length(parts) == 0) "-" else paste(parts, collapse = " + ")
    }),
    surcharge   = if_else(payment_method == "epassi", 5, 10),
    total_price = case_when(
      !is.na(amount_cents) ~ amount_cents / 100,
      TRUE ~ pmap_dbl(list(lindy_in, solo_in, fan), function(l, s, f) {
        fn_calculate_price(coalesce(l, FALSE), coalesce(s, FALSE),
                           fan = coalesce(as.logical(f), FALSE))
      }) + surcharge
    ),
    event = "Lindy"
  )

df_blues <- infer_payment(blues_tally) |>
  filter(status == "CONFIRMED",
         payment_method %in% c("epassi", "invoice"),
         !payment_status %in% PAID_STATUSES) |>
  mutate(
    confirmed_for = "Blues Workshop",
    surcharge     = if_else(payment_method == "epassi", 5, 10),
    total_price   = if_else(!is.na(amount_cents), amount_cents / 100, 0 + surcharge),
    event         = "Blues"
  )

out_cols <- c("event", "name", "email", "role", "level", "status",
              "confirmed_for", "payment_method", "payment_status", "total_price")

df_all <- bind_rows(
  df_lindy |> select(any_of(out_cols)),
  df_blues |> select(any_of(out_cols))
) |>
  mutate(
    role  = str_to_title(role),
    level = str_to_title(level),
    payment_status = coalesce(payment_status, "pending")
  ) |>
  arrange(payment_method, event, name)

# ── 4. Summary ───────────────────────────────────────────────────────────────

cat("\n=== SUMMARY ===\n")
df_all |> count(payment_method, event) |> print()
cat("Total amount:", sum(df_all$total_price), "€\n")

# ── 5. Write to Google Sheets ────────────────────────────────────────────────

OUTPUT_SHEET <- GOOGLE_SHEETS$registrations_2026

summary_tbl <- df_all |>
  group_by(payment_method) |>
  summarise(people = n(), amount = sum(total_price), .groups = "drop")

write_sheet(summary_tbl, ss = OUTPUT_SHEET, sheet = "ePassi & Invoice")
range_write(df_all, ss = OUTPUT_SHEET, sheet = "ePassi & Invoice", range = "A4")

cat("\nDone! Written 'ePassi & Invoice' sheet to:", OUTPUT_SHEET, "\n")
