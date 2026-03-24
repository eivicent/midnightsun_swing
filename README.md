# Midnight Sun Swing Festival

Registration management and email automation for the Midnight Sun Swing Festival in Helsinki.

## Project Structure

```
midnightsun_swing/
├── R/
│   ├── config.R                   # Constants, URLs, email messages
│   ├── helpers.R                  # Shared utility functions
│   ├── firestore_api.R            # Firebase integration (2026)
│   ├── diagnose_sheets_auth.R     # Google Sheets auth diagnostic
│   ├── fix_sheets_auth.R          # Google Sheets auth fix script
│   └── check_spreadsheet_access.R # Check specific spreadsheet access
├── 01_registration/               # Process registrations, assign groups
│   ├── 2024_registration.qmd
│   ├── 2025_registration.qmd
│   ├── 2026_registration.qmd
│   └── 2025_summaries.qmd
├── 02_confirmation_emails/        # Send confirmation/waitlist/partial emails
│   ├── 2024_confirmation.qmd
│   ├── 2025_confirmation.qmd
│   ├── 2026_confirmation.qmd
│   └── 2025_confirmation_changes.qmd
├── 03_payment_emails/             # Payment reminders
│   └── 2025_payment_reminder.qmd
├── 04_schedule_emails/            # Pre-festival schedule + info emails
│   ├── 2024_schedule.qmd
│   └── 2025_schedule.qmd
├── 05_feedback_emails/            # Post-festival feedback requests
│   ├── 2025_feedback.qmd
│   └── feedback_analyser.qmd
├── 06_thank_you_photos/           # Thank you and photos emails
│   ├── 2024_thank_you.qmd
│   └── 2025_thank_you.qmd
├── assets/                        # Logo, PDFs
├── TROUBLESHOOTING_SHEETS_AUTH.md # Google Sheets auth guide
└── README.md
```

## Workflow

The folders are numbered by workflow order:

1. **Registration** - Process registrations from Google Forms, assign participants to groups
2. **Confirmation Emails** - Send confirmation, partial confirmation, or waitlist emails
3. **Payment Emails** - Send payment reminders to unpaid participants
4. **Schedule Emails** - Send pre-festival information with schedule and venue details
5. **Feedback Emails** - Post-festival feedback request
6. **Thank You / Photos** - Post-festival thank you and photos announcement

## Usage

Each QMD file is a standalone action. To run:

1. Open the QMD file in RStudio
2. Run chunks interactively or render the document

### Setup

Each file should start with:

```r
source(here::here("R", "config.R"))
source(here::here("R", "helpers.R"))
fn_setup()
```

## Configuration

All constants are in `R/config.R`:

- `CURRENT_YEAR` - Festival year
- `GOOGLE_SHEETS` - URLs to registration and feedback sheets
- `PRICING` - Pass prices
- `EMAIL_SUBJECTS` - Email subject lines
- `EMAIL_MESSAGES` - Email body text templates
- `PAYMENT_INFO` - Bank account details
- `FESTIVAL_INFO` - Festival contact info and social links

## Troubleshooting

### Google Sheets Authentication Issues

If you encounter permission errors when writing to Google Sheets (403 PERMISSION_DENIED or 401 UNAUTHENTICATED):

**Quick Diagnostic:**
```r
source(here::here("R", "diagnose_sheets_auth.R"))
```

**Quick Fix:**
```r
source(here::here("R", "fix_sheets_auth.R"))
```

**Check Specific Spreadsheet:**
```r
source(here::here("R", "check_spreadsheet_access.R"))
```

See `TROUBLESHOOTING_SHEETS_AUTH.md` for detailed troubleshooting guide.

### Common Issues

1. **Can read but not write**: Spreadsheet permissions issue - ensure `midnightsunswing@gmail.com` has Editor access
2. **401 UNAUTHENTICATED**: OAuth token expired - run `gs4_auth()` to re-authenticate
3. **403 PERMISSION_DENIED**: Either wrong scopes or Google Sheets API not enabled

## Adding a New Year

1. Copy an existing year's file (e.g., `2025_registration.qmd` → `2026_registration.qmd`)
2. Update `CURRENT_YEAR` in `config.R`
3. Update Google Sheets URLs in `config.R` if needed
4. Update year-specific text in `EMAIL_SUBJECTS` and `EMAIL_MESSAGES`
