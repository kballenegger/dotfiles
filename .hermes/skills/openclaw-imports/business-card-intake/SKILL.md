---
name: business-card-intake
description: Use when Kenneth sends one or more business card / hotel card images. Extract each card individually, save a cleaned card-scan artifact, and insert people cards into People Tracker or hotel cards into Travel Tracker hotel_contacts.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [business-cards, people-tracker, hotel-contacts, ocr, artifacts]
    related_skills: [ocr-and-documents, people-tracker-contact-merge, hotel-travel-operations]
---

# Business Card Intake

## Overview

Kenneth expects business-card images to be treated as structured contact intake, not as a generic image-description task. When he sends a card image, extract the contact data, create a clean cropped/deskewed scan containing just the card, and save both the structured record and artifact in the correct tracker.

Hotel/property cards are not people contacts. They go to Travel Tracker `hotel_contacts`; ordinary personal/professional cards go to People Tracker.

## When to Use

Use this when:

- Kenneth sends a photo or scan of a business card.
- Kenneth sends multiple card images or a photo containing multiple cards.
- Kenneth says “add this card”, “save this business card”, “people tracker this”, or similar.
- A card appears to be for a hotel/property/front desk/concierge/reservations/guest relations contact.

Do not use this for ordinary email signatures unless there is a card-like artifact to clean/save; follow the People Tracker intake flow instead.

## Classification

Process every visible card independently.

1. **Hotel card** → Travel Tracker `hotel_contacts` when the card is for a hotel/property/chain contact, concierge, front desk, reservations, guest relations, general manager, duty manager, sales office, or property QR/contact card.
2. **Person/business card** → People Tracker when the card identifies an individual or company contact that is not a hotel property contact.
3. **Ambiguous** → Ask Kenneth only if classification changes the destination and the image/text does not make it clear. Otherwise act with the obvious default.

If one image contains multiple cards, crop/process/insert each card separately; do not combine multiple cards into one contact record.

## Extraction Workflow

1. Load `ocr-and-documents`; use vision first for layout/content and macOS Vision OCR fallback if vision fails.
2. Extract structured fields per card:
   - person card: `name`, `nickname`, `email`, `phone`, `company`, `role`, `location`, `social_handles`, `tags`, `notes`, `source`, `interaction_summary`, `interaction_channel`.
   - hotel card: `chain`, `property_name`, `property_id` if present, `email`, `contact_type`, `contact_name`, `phone`, `source`, `verified`, `notes`.
3. Preserve uncertainty in `notes`; do not invent missing names, emails, or phone numbers.
4. Normalize obvious OCR issues in emails/phones, but keep the raw/uncertain text in notes when confidence is low.
5. For multiple cards, produce one structured object and one artifact per card.

## Clean Card Scan Artifact

For every card, generate a cleaned image containing just that card:

1. Detect the card boundary if possible; crop to the card, apply perspective correction, rotate upright, trim background, and lightly enhance contrast/white balance.
2. If boundary detection fails, manually crop based on the visible card bounds; do not save the full original photo as the clean artifact unless there is no better option.
3. Save artifacts alongside the destination tracker data:
   - People cards: `~/klaw-workspace/people-tracker/artifacts/business_cards/<YYYYMMDD>_<slug>.png`
   - Hotel cards: `~/klaw-workspace/travel-tracker/artifacts/hotel_cards/<YYYYMMDD>_<slug>.png`
4. Reference the artifact path from the inserted record when the schema supports it; otherwise include the artifact path in `notes`.
5. Keep the original inbound image path in `notes` for provenance when useful.

Recommended implementation: use OpenCV/Pillow from `~/klaw-workspace/scripts/py` to crop/deskew/enhance; if OpenCV is unavailable, use Pillow crop/rotate/contrast and report the limitation.

## People Tracker Insert

Use the existing intake writer:

```bash
cd ~/klaw-workspace/people-tracker
~/klaw-workspace/scripts/py ingest.py --json '<extracted JSON>' --out-json
```

Rules:

- `name` is required for People Tracker. If the card lacks a person name but is not a hotel card, ask Kenneth before creating a generic company record.
- Set `source` to `business_card`.
- Set `interaction_channel` to `business_card`.
- Include the cleaned artifact path in `notes` if there is no dedicated artifact field.
- If the insert reports an existing contact, do not blindly overwrite; inspect/update/merge using `people-tracker-contact-merge` when needed.

After live DB changes, regenerate `people_tracker.sql`, run the project healthcheck, and commit/push tracked changes.

## Hotel Contact Insert

Use Travel Tracker DB `~/klaw-workspace/travel-tracker/travel_tracker.db`, table `hotel_contacts`:

```sql
chain, property_name, property_id, email, contact_type, contact_name, phone, source, verified, notes
```

Rules:

- `property_name` is required. If the card lacks a property name, ask Kenneth or infer only when the hotel name is visible elsewhere on the card.
- Set `source='business_card'` or `source='hotel_card'`.
- Set `verified=1` if the contact came directly from a printed hotel card; use `verified=0` if OCR confidence is low.
- Map contact type conservatively: `concierge`, `front_desk`, `reservations`, `guestrelations`, `gm`, `fom`, `duty_manager`, `sales`, or `general`.
- Avoid duplicates by checking existing rows for the same `property_name` plus email/phone before inserting.
- Include the cleaned artifact path and original image path in `notes` if no artifact field exists.

After live DB changes, regenerate any tracked SQL dump if the project uses one, run the relevant healthcheck/tests if present, and commit/push tracked changes.

## Reporting Back

Keep the WhatsApp reply concise. For each card, report:

- destination: People Tracker or hotel_contacts,
- extracted name/property and key email/phone,
- artifact saved path,
- whether insertion succeeded, updated an existing record, or needs Kenneth confirmation.

## Common Pitfalls

1. Do not answer with only a visual description when the image is a card; intake it.
2. Do not put hotel/property cards into People Tracker.
3. Do not merge multiple cards into one record.
4. Do not skip the cleaned card artifact; Kenneth explicitly wants it saved alongside extracted data.
5. Do not fabricate unreadable text. Mark uncertainty and ask only when required fields are missing.
6. Do not commit binary DB files unless the repo intentionally tracks them; prefer tracked SQL dumps/artifact files.

## Verification Checklist

- [ ] Every visible card was processed individually.
- [ ] Destination classification was correct: People Tracker vs hotel_contacts.
- [ ] Clean cropped/deskewed image artifact exists on disk.
- [ ] Structured record was inserted/updated or blocked for explicit confirmation.
- [ ] Artifact path/provenance was recorded in notes or a schema field.
- [ ] Healthcheck/tests and DB integrity checks passed where available.
- [ ] Git changes were committed and pushed.
