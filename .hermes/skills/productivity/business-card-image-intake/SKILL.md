---
name: business-card-image-intake
description: Use when Kenneth sends image(s) of business cards or hotel contact cards, especially via WhatsApp. Extract each card individually, route people vs hotel cards to the correct database, and save a cleaned card-scan artifact alongside the extracted data.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [business-cards, whatsapp, people-tracker, hotel-contacts, images, intake]
    related_skills: [people-tracker-contact-merge, hotel-travel-operations, coding-workflow, ocr-and-documents]
---

# Business Card Image Intake

## When to Use

Use this whenever Kenneth sends one or more images that appear to contain:

- a business card;
- a contact card / name card;
- a hotel/property contact card;
- multiple cards in one image or several images in a batch.

This is especially important on WhatsApp. Kenneth expects business-card images to be handled as contact intake, not as a generic image-description task.

## Mandatory Behavior

1. **Process each card individually.** If an image contains multiple cards, split the workflow by card and create/route one record per card. Do not collapse multiple people/cards into a single combined contact.
2. **Classify card type before writing:**
   - **Person/business card** → add to `people-tracker`.
   - **Hotel/property card** → add to the hotel contacts database, not people-tracker.
3. **Extract structured fields directly from the card:** name, role/title, company/property, email, phone, website, address, social handles, notes, and any visible metadata.
4. **Generate/save a clean business-card scan artifact** for each card: image containing just the card, cropped/perspective-corrected/cleaned when possible. Save it alongside the extracted data in the target system's artifact storage.
5. **Show Kenneth a concise summary for confirmation before committing contact ingestion** when the target workflow requires confirmation. Include the artifact path/reference and the destination database.
6. **If vision/OCR fails, say the exact failure and retry/fallback** instead of asking Kenneth to describe the card immediately:
   - retry `vision_analyze` if appropriate;
   - use OCR/document tooling;
   - inspect/crop the cached image locally;
   - only ask for resend/clarification when the image truly cannot be read.

## People-Tracker Route

For normal business/person cards:

1. Load/follow the workspace people-tracker intake flow.
2. Extract contact fields from the card.
3. Create or attach the cleaned card-scan artifact under the people-tracker's contact artifact location/convention. If the convention is unclear, inspect the repo before choosing a path.
4. Show Kenneth the extracted summary and ask for confirmation when needed.
5. On confirmation, ingest via the canonical people-tracker command, typically:

```bash
~/klaw-workspace/scripts/py ~/klaw-workspace/people-tracker/ingest.py --json '<extracted JSON>'
```

6. Include the artifact reference in the JSON/notes if the schema supports it; otherwise store a deterministic artifact file path and include it in notes/audit metadata.
7. After DB changes, follow project git/dump/healthcheck conventions from `coding-workflow` / `people-tracker-contact-merge`.

## Hotel-Contacts Route

For hotel/property contact cards:

1. Load/follow `hotel-travel-operations` and inspect the travel/hotel contacts schema before mutating.
2. Add the contact to the hotel contacts database, not people-tracker.
3. Store a cleaned card-scan artifact alongside the hotel-contact record using the target system's artifact convention. If the convention is unclear, inspect existing hotel-contact/folio/contact artifact paths first.
4. Preserve property name, brand/chain, department/contact role, email, phone, address, and source image/artifact path.
5. Verify the record can be queried from the hotel contacts database after insertion.

## Clean Scan Artifact Requirements

For every card:

- crop to the card boundary;
- perspective-correct/skew-correct when possible;
- preserve text legibility;
- avoid decorative hallucination or re-rendering that changes factual content;
- save as an image artifact (`.jpg`/`.png`) with a stable filename tied to the contact/card;
- keep the original cached/uploaded image available or referenced for audit when practical.

A “clean scan” means a cleaned-up image of the real card, not a newly designed replacement card.

## Multiple-Card Handling

If Kenneth sends multiple images/cards:

1. Enumerate cards as Card 1, Card 2, etc.
2. For each card, independently classify person vs hotel.
3. Extract and save a separate cleaned scan artifact for each.
4. Create/update separate records. Never merge cards unless the card clearly represents the same person/property and Kenneth confirms.

## Completion Report

Keep the report concise:

- cards processed count;
- per-card destination (`people-tracker` or `hotel contacts`);
- extracted name/company/property;
- artifact path/reference;
- confirmation needed or ingestion result.

## Pitfalls

- Do not treat a WhatsApp business-card photo as a generic “describe this image” request.
- Do not give up after one vision timeout; use fallback OCR/local image inspection.
- Do not put hotel/property cards into people-tracker.
- Do not combine multiple cards into one contact.
- Do not create a synthetic/redesigned card as the artifact; the artifact must be a cleaned scan of the actual card.
