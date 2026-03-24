# 
# Helper Functions for Midnight Sun Swing Festival
# Simple utility functions shared across QMD files

####### Setup Functions

#' Load required libraries and authenticate with Google
fn_setup <- function() {
  library(googlesheets4)
  library(blastula)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(glue)
  
  gs4_auth(email = AUTH_EMAIL)
}

#' Get the image string for email footer
fn_get_logo <- function() {
  add_image(file = here::here("assets", "midnightsunswing.jpeg"))
}

####### Data Reading Functions

#' Read registration data from Google Sheets
#' @param sheet_name Name of the sheet to read (default: "clean_groups_df")
#' @return Data frame with registration data
fn_read_data <- function(sheet_name = "clean_groups_df") {
  read_sheet(GOOGLE_SHEETS$responses, sheet = sheet_name)
}

#' Read final tally with confirmation status
fn_read_final_tally <- function() {
  read_sheet(GOOGLE_SHEETS$responses, sheet = "final_tally")
}

####### Text Generation Functions

#' Generate registration summary text (what they registered for)
#' @param lindy Boolean - registered for Lindy
#' @param solo Boolean - registered for Solo
#' @return String like "Lindy + Solo"
fn_registration_summary <- function(lindy, solo) {
  parts <- c(
    if (!is.na(lindy) && lindy) "Lindy" else NULL,
    if (!is.na(solo) && solo) "Solo" else NULL
  )
  paste(parts, collapse = " + ")
}

#' Generate confirmation summary text (what they're confirmed for)
#' @param lindy_in Boolean - confirmed for Lindy
#' @param solo_in Boolean - confirmed for Solo
#' @return String like "Lindy + Solo"
fn_confirmation_summary <- function(lindy_in, solo_in) {
  parts <- c(
    if (!is.na(lindy_in) && lindy_in) "Lindy" else NULL,
    if (!is.na(solo_in) && solo_in) "Solo" else NULL
  )
  paste(parts, collapse = " + ")
}

####### Price Calculation

#' Calculate total price based on confirmed tracks and extras
#' @param lindy_in Boolean - confirmed for Lindy
#' @param solo_in Boolean - confirmed for Solo (must be combined with Lindy)
#' @param fan Boolean - ordered a fan
#' @param tshirt Boolean - ordered t-shirt
#' @return Numeric price in euros
fn_calculate_price <- function(lindy_in, solo_in, fan = FALSE, tshirt = FALSE) {
  # Solo-only is not a valid option — warn if it ever happens
  if (!lindy_in && solo_in) {
    warning("Solo-only pricing is not supported (solo requires Lindy). Returning 0 base price.")
  }

  base_price <- case_when(
    lindy_in & solo_in  ~ PRICING$lindy_solo,
    lindy_in & !solo_in ~ PRICING$lindy_only,
    TRUE ~ 0
  )
  
  fan_price    <- if (fan)    PRICING$fan    else 0
  tshirt_price <- if (tshirt) PRICING$tshirt else 0
  
  base_price + fan_price + tshirt_price
}

####### Payment Text

#' Common bank transfer details block (reused across payment helpers)
fn_bank_details <- function() {
  glue(
    "**Bank transfer:**\n",
    "  - Bank account: **{PAYMENT_INFO$bank_account}**\n",
    "  - Payee: **{PAYMENT_INFO$payee}**\n",
    "  - BIC: **{PAYMENT_INFO$bic}** (SEPA only)\n",
    "  - Reference: **your email address**"
  )
}

#' Generate payment instructions text (legacy — uses a payment code as reference)
#' @param payment_code Unique payment reference code
#' @return Formatted payment instructions string
fn_payment_text <- function(payment_code) {
  glue("Please proceed with the **payment in the next {PAYMENT_INFO$payment_deadline_days} days** and use the code **{payment_code}** in the reference message.
You can pay by SEPA bank transfer to the following account:
  - Bank account: **{PAYMENT_INFO$bank_account}**
  - Payee: **{PAYMENT_INFO$payee}**
  - BIC: **{PAYMENT_INFO$bic}** (Only SEPA payments)
  - Address: **{PAYMENT_INFO$address}**
  - VAT ID: **{PAYMENT_INFO$vat_id}** _(In case you need it)_
  
You can also pay using _ePassi/Smartum/Edenred_ to Black Pepper Swing or by card if you are unable to do a bank transfer.")
}

#' Payment text for when a card capture fails
#' Tells the user their card couldn't be charged and provides alternative payment options.
#' @return Formatted string
fn_payment_card_failed_text <- function() {
  deadline <- PAYMENT_INFO$payment_deadline_days
  glue(
    "Unfortunately, we were **unable to process your card payment**. ",
    "Don't worry — you can complete your payment using the following ",
    "method within **{deadline} days**:\n\n",
    "{fn_bank_details()}\n\n",
    "If we don't receive your payment within {deadline} days, ",
    "your spot may be released to the next person on the waiting list."
  )
}

#' Payment text for invoice payments
#' Tells the user they are confirmed and an invoice will follow.
#' Invites them to reply with any billing details (company name, VAT, etc.).
#' @return Formatted string
fn_payment_invoice_text <- function() {
  glue(
    "We will send you the **invoice in the coming days** via a separate email.\n\n",
    "If you would like to include any additional information on the invoice ",
    "(such as a company name, VAT number, or billing address), ",
    "please **reply to this email** and let us know."
  )
}

#' Payment text for ePassi / Smartum / Edenred payments
#' Provides ePassi payment instructions with deadline (no bank transfer option).
#' @param total_price Numeric total price to display in the email.
#'   For CONFIRMED users this comes from Firebase (surcharge already included).
#'   For PARTIAL users this is recalculated (surcharge NOT included yet).
#' @param surcharge_included If TRUE, total_price already contains the 5€
#'   surcharge (default for Firebase-sourced prices). If FALSE, the surcharge
#'   is added on top (used for recalculated PARTIAL prices).
#' @return Formatted string
fn_payment_epassi_text <- function(total_price = NULL, surcharge_included = TRUE) {
  deadline <- PAYMENT_INFO$payment_deadline_days
  epassi_surcharge <- 5
  price_text <- if (!is.null(total_price) && total_price > 0) {
    display_price <- if (surcharge_included) total_price else total_price + epassi_surcharge
    glue(
      "pay **{display_price}€** to **Black Pepper Swing** ",
      "(includes a **{epassi_surcharge}€** invoice fee)"
    )
  } else {
    glue(
      "pay to **Black Pepper Swing** ",
      "(a **{epassi_surcharge}€** invoice fee applies)"
    )
  }
  glue(
    "Please complete your payment within **{deadline} days** using ",
    "**ePassi / Smartum / Edenred**: {price_text}.\n\n",
    "If we don't receive your payment within {deadline} days, ",
    "your spot may be released to the next person on the waiting list."
  )
}

####### Email Sending

#' Send an email with logging
#' @param email_object Composed email object from blastula
#' @param to Recipient email address
#' @param subject Email subject line
#' @param from Sender email (default: festival email)
#' @return TRUE if successful, FALSE otherwise
fn_send_email <- function(email_object, to, subject, from = FESTIVAL_INFO$email) {
  tryCatch({
    smtp_send(
      email_object,
      to = to,
      from = c("Midnight Sun Swing" = from),
      subject = subject,
      credentials = creds_file(file = "~/Documents/gmail_creds")
    )
    cat("Email sent to:", to, "\n")
    Sys.sleep(2)  # Rate limiting
    return(TRUE)
  }, error = function(e) {
    cat("Failed to send email to:", to, "- Error:", e$message, "\n")
    return(FALSE)
  })
}

#' Generate registration details text for emails
#' @param lindy_group Lindy group assignment
#' @param solo_group Solo group assignment
#' @param tshirt_answer T-shirt details
#' @param payment_status Payment status
#' @return Formatted details string
fn_registration_details <- function(lindy_group, solo_group, 
                                    tshirt_answer, payment_status) {
  glue("- Your Lindy group: **{coalesce(lindy_group, '-')}**
    - Your Solo group: **{coalesce(solo_group, '-')}**
    - T-shirt: **{coalesce(tshirt_answer, '-')}**
    - Payment status: **{coalesce(payment_status, '-')}**")
}

#' Get the waitlist options text from config
fn_waitlist_options <- function() {
  EMAIL_MESSAGES$waitlist_options
}

#' Get social media links text from config
fn_social_links <- function() {
  EMAIL_MESSAGES$social_links
}
