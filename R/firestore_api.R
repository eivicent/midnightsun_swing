# 
# Firestore and Stripe API utilities for MSS Registration System
# Functions to read/write registration data from Firebase Firestore
# and capture/cancel Stripe payments

library(httr2)
library(jsonlite)
library(gargle)
library(dplyr)

####### Configuration

# Firebase project ID - update this after creating your Firebase project
FIREBASE_PROJECT_ID <- Sys.getenv("FIREBASE_PROJECT_ID", "mss-registration")

# Firestore REST API base URL
FIRESTORE_BASE_URL <- paste0(
 "https://firestore.googleapis.com/v1/projects/",
 FIREBASE_PROJECT_ID,
 "/databases/(default)/documents"
)

# Stripe API base URL
STRIPE_BASE_URL <- "https://api.stripe.com/v1"

####### Authentication

#' Get Firebase access token using service account
#' 
#' Requires GOOGLE_APPLICATION_CREDENTIALS environment variable to be set
#' to the path of your Firebase service account JSON file
#' 
#' @return Access token string
fn_get_firebase_token <- function() {
 token <- gargle::credentials_service_account(
   scopes = "https://www.googleapis.com/auth/datastore",
   path = Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS")
 )
 token$credentials$access_token
}

#' Get Stripe secret key from environment
#' 
#' @return Stripe secret key string
fn_get_stripe_key <- function() {
 key <- Sys.getenv("STRIPE_SECRET_KEY")
 if (key == "") {
   stop("STRIPE_SECRET_KEY environment variable not set")
 }
 key
}

####### Firestore Helper Functions

#' Parse Firestore document value to R value
#' 
#' @param value Firestore value object with type wrapper
#' @return R value
fn_parse_firestore_value <- function(value) {
 if (is.null(value)) return(NA)
 
 # Get the type key (stringValue, integerValue, etc.)
 type_key <- names(value)[1]
 val <- value[[type_key]]
 
 switch(type_key,
   "stringValue" = as.character(val),
   "integerValue" = as.integer(val),
   "doubleValue" = as.numeric(val),
   "booleanValue" = as.logical(val),
   "nullValue" = NA,
   "timestampValue" = as.POSIXct(val, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
   "mapValue" = lapply(val$fields, fn_parse_firestore_value),
   "arrayValue" = lapply(val$values, fn_parse_firestore_value),
   val
 )
}

#' Parse Firestore document to data frame row
#' 
#' @param doc Firestore document object
#' @return Named list with document data
fn_parse_firestore_document <- function(doc) {
 # Extract document ID from name (last part of path)
 doc_id <- basename(doc$name)
 
 # Parse all fields
 fields <- lapply(doc$fields, fn_parse_firestore_value)
 fields$id <- doc_id
 
 fields
}

#' Convert R value to Firestore format
#' 
#' @param value R value
#' @return Firestore value object
fn_to_firestore_value <- function(value) {
 if (is.null(value) || (length(value) == 1 && is.na(value))) {
   return(list(nullValue = NULL))
 }
 
 if (is.logical(value)) {
   return(list(booleanValue = value))
 }
 
 if (is.integer(value)) {
   return(list(integerValue = as.character(value)))
 }
 
 if (is.numeric(value)) {
   return(list(doubleValue = value))
 }
 
 if (inherits(value, "POSIXt")) {
   return(list(timestampValue = format(value, "%Y-%m-%dT%H:%M:%SZ")))
 }
 
 # Default to string
 list(stringValue = as.character(value))
}

#' Convert named list to Firestore fields format
#' 
#' @param fields Named list of values
#' @return Firestore fields object
fn_to_firestore_fields <- function(fields) {
 lapply(fields, fn_to_firestore_value)
}

####### Firestore Query Helpers

#' Build a Firestore fieldFilter for a single field
#'
#' @param field_name Field path string (e.g. "pass")
#' @param values Character/numeric/logical vector. Length 1 uses EQUAL; length > 1 uses IN.
#' @return List representing a fieldFilter clause
fn_build_field_filter <- function(field_name, values) {
 if (length(values) == 1) {
   list(
     fieldFilter = list(
       field = list(fieldPath = field_name),
       op    = "EQUAL",
       value = fn_to_firestore_value(values)
     )
   )
 } else {
   list(
     fieldFilter = list(
       field = list(fieldPath = field_name),
       op    = "IN",
       value = list(
         arrayValue = list(
           values = lapply(values, fn_to_firestore_value)
         )
       )
     )
   )
 }
}

#' Build a Firestore structuredQuery body from a named list of filters
#'
#' @param filters Named list: each name is a field path, each value is a scalar or vector.
#' @return List suitable for JSON-encoding as a runQuery request body.
fn_build_structured_query <- function(filters) {
 field_filters <- Map(fn_build_field_filter, names(filters), filters)
 field_filters <- unname(field_filters)

 where_clause <- if (length(field_filters) == 1) {
   field_filters[[1]]
 } else {
   list(compositeFilter = list(op = "AND", filters = field_filters))
 }

 list(
   structuredQuery = list(
     from  = list(list(collectionId = "registrations")),
     where = where_clause
   )
 )
}

####### Firestore API Functions

#' Fetch registrations from Firestore
#'
#' When \code{filters} is NULL (default) all documents are fetched via the list
#' endpoint (paginated).
#' When \code{filters} is a named list, a Firestore \code{runQuery} structured
#' query is used so only matching documents are returned (server-side filtering).
#'
#' @param filters Optional named list of field filters.
#'   Single value uses EQUAL, vector of values uses IN.
#'   Example: \code{list(pass = "blues_workshop")} or
#'            \code{list(pass = c("lindy", "lindy_solo"))}.
#' @param page_size Page size for the unfiltered list endpoint (ignored when
#'   filters are provided).
#' @return Data frame with registrations
#' @export
fn_get_registrations <- function(filters = NULL, page_size = 300) {
 token <- fn_get_firebase_token()

 if (!is.null(filters)) {
   return(fn_get_registrations_query(token, filters))
 }

 fn_get_registrations_list(token, page_size)
}

#' (internal) Fetch registrations via runQuery with server-side filters
fn_get_registrations_query <- function(token, filters) {
 query_body <- fn_build_structured_query(filters)

 response <- request(paste0(FIRESTORE_BASE_URL, ":runQuery")) |>
   req_headers(
     Authorization  = paste("Bearer", token),
     `Content-Type` = "application/json"
   ) |>
   req_method("POST") |>
   req_body_json(query_body) |>
   req_error(is_error = function(resp) FALSE) |>
   req_perform()

 if (resp_status(response) != 200) {
   stop("Failed to query registrations: ", resp_body_string(response))
 }

 results <- resp_body_json(response)

 # runQuery returns a list of objects; only those with a "document" key
 # contain actual documents (empty results return only readTime).
 docs <- Filter(function(r) !is.null(r$document), results)

 if (length(docs) == 0) {
   message("No registrations found matching filters")
   return(data.frame())
 }

 rows <- lapply(docs, function(r) fn_parse_firestore_document(r$document))
 df   <- bind_rows(rows)

 filter_desc <- paste(
   names(filters),
   vapply(filters, function(v) paste(v, collapse = "|"), character(1)),
   sep = "=", collapse = ", "
 )
 message("Fetched ", nrow(df), " registrations (filters: ", filter_desc, ")")
 df
}

#' (internal) Fetch all registrations via paginated list endpoint
fn_get_registrations_list <- function(token, page_size) {
 all_documents <- list()
 page_token <- NULL
 page_num <- 0

 repeat {
   page_num <- page_num + 1

   req <- request(paste0(FIRESTORE_BASE_URL, "/registrations")) |>
     req_headers(Authorization = paste("Bearer", token)) |>
     req_url_query(pageSize = page_size) |>
     req_error(is_error = function(resp) FALSE)

   if (!is.null(page_token)) {
     req <- req |> req_url_query(pageToken = page_token)
   }

   response <- req |> req_perform()

   if (resp_status(response) != 200) {
     stop("Failed to fetch registrations: ", resp_body_string(response))
   }

   data <- resp_body_json(response)

   if (!is.null(data$documents) && length(data$documents) > 0) {
     all_documents <- c(all_documents, data$documents)
   }

   message("  Page ", page_num, ": fetched ", length(data$documents %||% list()), " documents")

   if (is.null(data$nextPageToken) || data$nextPageToken == "") {
     break
   }
   page_token <- data$nextPageToken
 }

 if (length(all_documents) == 0) {
   message("No registrations found")
   return(data.frame())
 }

 rows <- lapply(all_documents, fn_parse_firestore_document)
 df <- bind_rows(rows)

 message("Fetched ", nrow(df), " registrations (", page_num, " page(s))")
 df
}

#' Get a single registration by ID
#' 
#' @param doc_id Firestore document ID
#' @return Named list with registration data
#' @export
fn_get_registration <- function(doc_id) {
 token <- fn_get_firebase_token()
 
 response <- request(paste0(FIRESTORE_BASE_URL, "/registrations/", doc_id)) |>
   req_headers(Authorization = paste("Bearer", token)) |>
   req_error(is_error = function(resp) FALSE) |>
   req_perform()
 
 if (resp_status(response) != 200) {
   stop("Failed to fetch registration: ", resp_body_string(response))
 }
 
 doc <- resp_body_json(response)
 fn_parse_firestore_document(doc)
}

#' Update registration fields in Firestore
#' 
#' @param doc_id Firestore document ID
#' @param fields Named list of fields to update
#' @return TRUE on success
#' @export
fn_update_registration <- function(doc_id, fields) {
 token <- fn_get_firebase_token()
 
 # Add updated_at timestamp
 fields$updated_at <- Sys.time()
 
 # Build update mask (each field needs its own updateMask.fieldPaths parameter)
 update_mask <- paste0("updateMask.fieldPaths=", names(fields), collapse = "&")
 
 # Convert fields to Firestore format
 firestore_fields <- fn_to_firestore_fields(fields)
 
 url <- paste0(
   FIRESTORE_BASE_URL, "/registrations/", doc_id,
   "?", update_mask
 )
 
 response <- request(url) |>
   req_headers(
     Authorization = paste("Bearer", token),
     `Content-Type` = "application/json"
   ) |>
   req_method("PATCH") |>
   req_body_json(list(fields = firestore_fields)) |>
   req_error(is_error = function(resp) FALSE) |>
   req_perform()
 
 if (resp_status(response) != 200) {
   stop("Failed to update registration: ", resp_body_string(response))
 }
 
 message("Updated registration ", doc_id)
 TRUE
}

#' Update payment status for a registration
#' 
#' @param doc_id Firestore document ID
#' @param status New payment status
#' @return TRUE on success
#' @export
fn_update_payment_status <- function(doc_id, status) {
 fn_update_registration(doc_id, list(payment_status = status))
}

####### Stripe API Functions

#' Capture a pre-authorized Stripe payment
#' 
#' @param payment_intent_id Stripe PaymentIntent ID (starts with pi_)
#' @param amount_to_capture Optional amount to capture (in cents). If NULL, captures full amount.
#' @return Stripe PaymentIntent object
#' @export
fn_capture_payment <- function(payment_intent_id, amount_to_capture = NULL) {
 stripe_key <- fn_get_stripe_key()
 
 url <- paste0(STRIPE_BASE_URL, "/payment_intents/", payment_intent_id, "/capture")
 
 req <- request(url) |>
   req_auth_basic(stripe_key, "") |>
   req_method("POST")
 
 # Add amount if specified
 if (!is.null(amount_to_capture)) {
   req <- req |> req_body_form(amount_to_capture = amount_to_capture)
 }
 
 response <- req |>
   req_error(is_error = function(resp) FALSE) |>
   req_perform()
 
 result <- resp_body_json(response)
 
 if (resp_status(response) != 200) {
   stop("Failed to capture payment: ", result$error$message)
 }
 
 message("Captured payment ", payment_intent_id, " - Status: ", result$status)
 result
}

#' Cancel a pre-authorized Stripe payment (release hold)
#' 
#' @param payment_intent_id Stripe PaymentIntent ID (starts with pi_)
#' @return Stripe PaymentIntent object
#' @export
fn_cancel_preauth <- function(payment_intent_id) {
 stripe_key <- fn_get_stripe_key()
 
 url <- paste0(STRIPE_BASE_URL, "/payment_intents/", payment_intent_id, "/cancel")
 
 response <- request(url) |>
   req_auth_basic(stripe_key, "") |>
   req_method("POST") |>
   req_error(is_error = function(resp) FALSE) |>
   req_perform()
 
 result <- resp_body_json(response)
 
 if (resp_status(response) != 200) {
   stop("Failed to cancel payment: ", result$error$message)
 }
 
 message("Canceled pre-auth ", payment_intent_id, " - Status: ", result$status)
 result
}

#' Create an off-session payment using a stored card
#'
#' When a pre-auth expires and capture fails, this creates a new PaymentIntent
#' and charges the customer's saved card immediately (off-session).
#' Requires that the original payment used `setup_future_usage: 'off_session'`
#' so that SCA was handled at registration time.
#'
#' @param customer_id Stripe Customer ID (starts with cus_)
#' @param payment_method_id Stripe PaymentMethod ID (starts with pm_)
#' @param amount_cents Amount to charge in cents
#' @param description Internal description visible in Stripe Dashboard
#'   (default: "MSS - Off-session re-charge")
#' @param statement_descriptor_suffix Appended to your account's default
#'   statement descriptor (max 22 chars). E.g. "LINDY" → "MSS* LINDY"
#'   on the customer's card statement.
#' @return Stripe PaymentIntent object
#' @export
fn_create_off_session_payment <- function(customer_id, payment_method_id,
                                          amount_cents,
                                          description = "MSS - Off-session re-charge",
                                          statement_descriptor_suffix = "FESTIVAL") {
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
      off_session = "true",
      description = description,
      statement_descriptor_suffix = statement_descriptor_suffix
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

#' Get Stripe PaymentIntent details
#' 
#' @param payment_intent_id Stripe PaymentIntent ID
#' @return Stripe PaymentIntent object
#' @export
fn_get_payment_intent <- function(payment_intent_id) {
 stripe_key <- fn_get_stripe_key()
 
 url <- paste0(STRIPE_BASE_URL, "/payment_intents/", payment_intent_id)
 
 response <- request(url) |>
   req_auth_basic(stripe_key, "") |>
   req_error(is_error = function(resp) FALSE) |>
   req_perform()
 
 result <- resp_body_json(response)
 
 if (resp_status(response) != 200) {
   stop("Failed to get payment intent: ", result$error$message)
 }
 
 result
}

####### Convenience Functions

#' Capture payment and update registration status
#' 
#' @param doc_id Firestore document ID
#' @param payment_intent_id Stripe PaymentIntent ID
#' @return TRUE on success
#' @export
fn_confirm_registration <- function(doc_id, payment_intent_id) {
 # Capture the payment
 fn_capture_payment(payment_intent_id)
 
 # Update registration status
 fn_update_registration(doc_id, list(payment_status = "captured"))
 
 message("Registration ", doc_id, " confirmed and payment captured")
 TRUE
}

#' Cancel registration and release pre-auth
#' 
#' @param doc_id Firestore document ID
#' @param payment_intent_id Stripe PaymentIntent ID (can be NULL for non-card payments)
#' @return TRUE on success
#' @export
fn_cancel_registration <- function(doc_id, payment_intent_id = NULL) {
 # Cancel the pre-auth if it exists
 if (!is.null(payment_intent_id) && payment_intent_id != "") {
   tryCatch({
     fn_cancel_preauth(payment_intent_id)
   }, error = function(e) {
     message("Note: Could not cancel pre-auth (may already be canceled): ", e$message)
   })
 }
 
 # Update registration status
 fn_update_registration(doc_id, list(payment_status = "canceled"))
 
 message("Registration ", doc_id, " canceled")
 TRUE
}

#' Process confirmed registrations - capture all pre-authorized payments
#' 
#' @param registrations Data frame of registrations to confirm
#' @return Summary of results
#' @export
fn_process_confirmations <- function(registrations) {
 results <- list(success = 0, failed = 0, errors = c())
 
 for (i in seq_len(nrow(registrations))) {
   reg <- registrations[i, ]
   
   tryCatch({
     if (!is.na(reg$stripe_payment_intent_id) && reg$stripe_payment_intent_id != "") {
       fn_confirm_registration(reg$id, reg$stripe_payment_intent_id)
     } else {
       # Non-card payment - just update status
       fn_update_payment_status(reg$id, "confirmed")
     }
     results$success <- results$success + 1
   }, error = function(e) {
     results$failed <- results$failed + 1
     results$errors <- c(results$errors, paste(reg$id, ":", e$message))
     message("Error processing ", reg$id, ": ", e$message)
   })
 }
 
 message("\nProcessed ", results$success + results$failed, " registrations")
 message("Success: ", results$success)
 message("Failed: ", results$failed)
 
 results
}
