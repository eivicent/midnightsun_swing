# Configuration file for Midnight Sun Swing Festival Management System
# Simple configuration for easy maintenance

# Current festival year
CURRENT_YEAR <- "2026"

# Google Sheets URLs
GOOGLE_SHEETS <- list(
  responses = "https://docs.google.com/spreadsheets/d/1SeBYtYHBqXbiMc3HsSY7Y5kSSMDBp1SE8xZIm9_qJig/edit?resourcekey=&gid=1332098813#gid=1332098813",
  feedback = "https://docs.google.com/spreadsheets/d/1w6gBzV0NJi6RcpKAMWE7SGR-px_B9Oo6lNQmZywSbuY/edit?resourcekey=&gid=1456259706#gid=1456259706",
  registrations_2026 = "https://docs.google.com/spreadsheets/d/1SINrOcbDEU1iDwl2O7WPNNsl5iX8ivHFYx3LAGAviYo/edit?gid=0#gid=0",
  # Blues: standalone (separate sheet — create one and paste URL here, or reuse registrations_2026 for shared file)
  registrations_2026_blues = "https://docs.google.com/spreadsheets/d/1r_mKmJD7IvCam5tfeRLMTgNSikxuHMnaeVFjGyynLS4/edit?gid=0#gid=0"
)

# Authentication
AUTH_EMAIL <- "vicent.boned.11@gmail.com"

# File paths
ASSETS <- list(
  logo = "assets/midnightsunswing.jpeg",
  schedule_pdf = "MNS - Schedule - 2026.pdf",
  schedule_mobile_pdf = "MNS - Schedule - 2026 - mobile.pdf"
)

# Festival information
FESTIVAL_INFO <- list(
  name = "Midnight Sun Swing Festival",
  year = CURRENT_YEAR,
  website = "https://www.midnightsunswing.fi/",
  instagram = "https://www.instagram.com/midnightsun_swing/",
  facebook = "https://fb.me/e/jrCZ1gQH4",
  email = "midnightsunswing@gmail.com",
  safe_space_phone = "+358505231534"
)

# Payment information
PAYMENT_INFO <- list(
  bank_account = "FI87 7997 7998 0331 74",
  payee = "Osuuskunta Swing Kollektiivi",
  bic = "HOLVFIHH",
  address = "Karjalankatu 2, 00520 Helsinki, Finland",
  vat_id = "FI28578381",
  payment_deadline_days = 7
)

# Pricing structure (2026: Lindy + Solo only, no Balboa)
# Surcharges (handled manually, not included in automated emails):
#   ePassi / Smartum / Edenred: +5€
#   Invoice: +10€
PRICING <- list(
  lindy_only = 205,
  lindy_solo = 260,
  tshirt = 25,
  fan = 18
)

# Group capacities (number of couples/pairs for partnered tracks, individuals for solo)
GROUP_CAPACITIES <- list(
  intermediate = 23,
  intermediate_advanced = 25,
  advanced = 45,
  solo = 40,
  # Blues workshop: single level
  blues_intermediate_plus = 22
)

# Follower overflow: extra confirmed follower spots above the pair quota per level.
# Rationale: leaders are typically scarcer than followers; admitting a small
# surplus of followers as CONFIRMED keeps everyone moving while still leaving
# room for a leader who arrives later to be paired with one of them.
# Set to 0 for any level to disable overflow there.
OVERFLOW_FOLLOWERS <- list(
  intermediate = 2,
  intermediate_advanced = 0,
  advanced = 3,
  blues_intermediate_plus = 2
)

# Email subject lines
EMAIL_SUBJECTS <- list(
  confirmation = "MSS 2026 - Confirmation",
  partial_confirmation = "MSS 2026 - Partial Confirmation",
  waitlist = "MSS 2026 - Waitlist",
  capture_failed = "MSS 2026 - Payment Issue",
  payment_reminder = "MSS 2026 - Payment Reminder",
  schedule = "MSS 2026 - Schedule Information",
  feedback = "MSS 2026 - Feedback Request",
  thank_you = "Thank you for registering - Midnight Sun Swing Festival 2026",
  photos = "Photos from Midnight Sun Swing Festival 2026",
  save_the_date = "Save the Date - Midnight Sun Swing Festival 2027"
)

# Venue information
VENUES <- list(
  hietsu = "https://maps.app.goo.gl/bxYwcnodgNHN8E6W7",
  german_school = "https://maps.app.goo.gl/mKZVPrhF6hZWwYhk7",
  black_pepper = "https://maps.app.goo.gl/VBj2rpWGXZst76Du5"
)

# Email messages - simple and easy to edit
EMAIL_MESSAGES <- list(
  # Confirmation messages
  confirmation = "Thank you for registering to Midnight Sun Swing Festival 2026. We are happy to **confirm your spot**!",
  partial_confirmation = "Thank you for registering to Midnight Sun Swing Festival 2026. We are happy to **partially confirm** your spot for it! \n(That means that you are IN one of the tracks, and on the waitlist for the other)",
  waitlist = "Thank you for registering to Midnight Sun Swing Festival 2026. Unfortunately, **we currently don't have enough leaders to pair everyone**, so you are on the waiting list for now.",
  waitlist_sold_out = "Thank you for registering to Midnight Sun Swing Festival 2026. Unfortunately, **this level is fully booked**, so you are on the waiting list for now.",
  
  # Payment status
  payment_captured = "Your **card payment has been collected**. No further action is needed on your side. Thank you!",
  
  # Payment reminder
  payment_reminder = "We **confirmed** your spot in the festival a while ago, but we haven't received your payment yet. **If you have already paid, please let us know, as we might have missed it!** (apologies about that)",
  
  # Waitlist options
  waitlist_options = "Here are a few things that can help:\n  - **Spread the word among leaders!** The more leaders register, the sooner we can get you in\n  - Invite a leader friend to register **in the same level** _(make sure they add your email as their partner so you get paired together)_\n  - **Switch to leader role** yourself if there are spots available\n\n  We are actively looking for more leaders and will let you know as soon as we can fit you in. If you want to withdraw from the queue of this track you can send us an email.",
  waitlist_options_sold_out = "Here are a few things that can help:\n  - **Register for a different level** if you are comfortable dancing at another level\n  - **Wait for a spot to open up** — if someone sells their pass we will move you in\n\n  We will let you know as soon as a spot becomes available. If you want to withdraw from the waitlist you can send us an email.",
  
  # Social media links
  social_links = "Follow us to be up to date with all the information about Midnight Sun Swing Festival in the [Website](https://www.midnightsunswing.fi/) // [Instagram](https://www.instagram.com/midnightsun_swing/) // [Facebook](https://fb.me/e/jrCZ1gQH4)\n\nSchedule and other details will be sent to you closer to the festival but you can check the preliminary one on our website.",
  
  # Schedule information
  schedule_intro = "Hello **{name}**, we hope that you are as thrilled as we are to spend a fantastic summer weekend in Helsinki with a lot of classes and two nights of non-stop dancing!\n\nHere you have all the information needed:",
  
  # Classes information
  classes_info = "**Classes Information:**\n\n-   **Lindy Hop** will have 4 classes of 60 minutes and they will be at [Hietsun Paviljonki](https://maps.app.goo.gl/bxYwcnodgNHN8E6W7) and [Helsinki German School](https://maps.app.goo.gl/mKZVPrhF6hZWwYhk7)\n    \n-   **Solo Jazz** will have 2 classes of 90 min at [Hietsun Paviljonki](https://maps.app.goo.gl/bxYwcnodgNHN8E6W7)\n\n- Doors will open 15 min before the classes start, please be on time to respect your colleagues and teachers\n\n- Find the schedule attached to this email, or in our [instagram feed](https://www.instagram.com/midnightsun_swing/) in the coming days",
  
  # Parties information
  parties_info = "**Parties Information:**\n\n-   On Friday, the party will **start at 19.30h** with an amazing culture talk open for all Lindy or Solo participants by [Bobby White](https://swungover.wordpress.com/), where we'll watch some clips and learn about the Harvest Moon Ball. After that *Professor Cunningham and his Old School Band* will make us swing until the sunset (or sunrise?)\n\n-   On Saturday the party will **start at 20.30h** so you can all get a longer rest before another night of swinging tunes by the *Professor Cunningham and his Old School Band*\n\n-   On Sunday, we will have a farewell social dance with DJ, but to spice things up we have two special treats: We will have another culture talk / QA with Ursula Hicks and we will get to dance to the tunes of DJ Bobby White. **Starting at 16.30h**\n\n-   Friday, Saturday and Sunday parties will be at Hietsun Paviljonki, which will remain open after classes in case you want to stay there until the party starts",
  
  # Other important information
  other_info = "**Other important information:**\n\n-   The entrance to Hietsu will be on the beach side during the parties\n\n-   This year we will use the small room as cloakroom. Please do not bring your backpacks to the dance floor / corridor.\n\n-   There will be a coffee corner, where you can get coffee and home made snacks, but you can bring your own! In case you want to buy from us, we accept cash and Mobile Pay\n\n-   We recommend you bring a refillable water bottle with you, and (maybe) swimsuit and towel for the **#midnightsunswim**",
  
  # Code of conduct
  code_of_conduct = "**Code of conduct and safe space**\n\n-   We want to make this weekend safe and enjoyable for everyone and we expect that you will follow the [code of conduct](https://www.midnightsunswing.fi/code-of-conduct/) of our Helsinki scene and act respectfully to everyone\n\n-   If you need advice or come across any unwanted behaviour you can contact any of the organisers personally or via [email](midnightsunswing@gmail.com) or call our safe space person April Karkulahti (+358505231534)\n\n-   There will be a photographer in the event, [Marina](https://www.instagram.com/nina__capri/) and the photos taken may be published on our social media and used to promote our future events. If you do not wish to appear in any of the photos please let us or her know during the weekend",
  
  # Closing message
  closing = "We wish everyone a joyful and unforgettable festival weekend!\n\nIf you have any further questions don't hesitate to reach us by email, Facebook or Instagram.\n\nCheers from the Midnight Sun Swing Team"
)
