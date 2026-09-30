---
name: travel-signal-feedback
description: Use when handling Kenneth's feedback in the #the-signal Slack channel about The Travel Signal posts, including false positives, guide/noise calls, headlines, summaries, tags, entities, clustering, or Slack delivery behavior.
version: 1.0.1
author: Klaw
metadata:
  hermes:
    tags: [travel-signal, feedback, classification, slack]
    related_skills: [coding-workflow, minions]
---

# Travel Signal Feedback

## Scope

Use this skill when Kenneth replies to an auto-posted The Travel Signal story in Slack (especially channel `C0B3947UCP7`, `#the-signal`) with feedback such as:

- “this should not be posted”
- “this is a guide” / “this is noise”
- headline/summary/tag/entity corrections
- “why did this post?”
- clustering/duplicate-story complaints
- Slack delivery or destination issues

The Travel Signal source repo is `~/the-travel-signal` (`git@github.com:kballenegger/the-travel-signal.git`). The live site is `https://thetravelsignal.com`.

## Precedence

- `coding-workflow` controls all coding/config/test/commit behavior.
- `minions` controls Slack-originated implementation work: spawn a worker by default for fixes, prompt/rule changes, tests, service restarts, and repo commits.
- This skill adds project feedback handling only; it does not override broader mandatory workflow skills.

## Feedback Handling Rule

Kenneth's feedback on a posted story is usually not a personal preference and should not be saved to memory. Treat it as product feedback for The Travel Signal pipeline.

Default flow:

1. **Acknowledge the correction briefly.** Do not defend the posted item.
2. **Classify the feedback type:**
   - false positive / should be noise
   - false negative / should have posted
   - wrong `noise_reason`
   - bad headline/summary
   - wrong tags/entities
   - wrong story merge/duplicate split
   - Slack delivery/destination issue
3. **Update the product source of truth, not memory:**
   - classifier prompt/rules/config,
   - deterministic prefilters,
   - entity/tag rules,
   - clustering logic,
   - notification/delivery logic,
   - regression tests.
4. **Spawn implementation work from Slack** unless Kenneth explicitly says to do it inline.
5. **Require regression coverage** using the exact complained-about article/title/URL when possible.
6. **Commit and push** the Travel Signal repo changes. If only live DB state changes, report row IDs and clean tracked status instead.
7. **Report what changed**: files, tests/healthcheck, commit hash, whether backfill/reclassification/restart is needed.

## Guide / Evergreen Noise Policy

If Kenneth says a story is a “guide,” “explainer,” “basic guide,” “evergreen,” or “not news,” handle it as classifier/prompt feedback.

Canonical example:

- Title: `What Does “SSSS” On Airline Boarding Pass Mean? Get Ready For A Search!`
- Topic: SSSS / Secondary Security Screening Selection / boarding-pass explainer.
- Expected result: `noise` with `noise_reason="guide"`; it should not be posted.

Generalize carefully: basic how-to/explainer/listicle/guide content is noise, but real travel-loyalty news, time-bound deals, program changes, route/product changes, and material policy changes can still be signal.

## Roundup Replies

When Kenneth replies `round up` to a posted Travel Signal story, treat it as a request for a concise, actionable news synthesis, not product feedback or a code-change request.

Default flow:

1. Open the Travel Signal story and capture its entities, summary, and cited source links.
2. If the Travel Signal body is sparse, follow the cited source(s). For JS/ad-heavy sources where `web_extract` fails, use browser extraction patterns such as `document.querySelector('article')?.innerText` and `document.querySelectorAll('article a')` to identify related detail pages.
3. Round up the practical facts: what changed, dates/fees/thresholds, user impact, and what Kenneth should do.
4. For points/transfer bonuses, rank likely utility and warn against speculative transfers unless there is an immediate redemption or unusually strong bonus.
5. Keep Slack output tight: no tables, no browsing narration, bullets plus a bottom-line/actionable takeaway.

## Investigation Checklist

Before prescribing a fix, trace the item through the pipeline:

1. Locate the article/title/URL in the Travel Signal DB or current feed output.
2. Inspect raw post fields, cleaned text, classifier decision, `noise_reason`, entities/tags, story merge state, and rendered/Slack output as relevant.
3. Identify which stage introduced the bad behavior.
4. Patch the narrowest source-of-truth rule/prompt/code path.
5. Add a regression test at that stage and, when useful, an end-to-end notification/classification test.

## Loyalty-Program and Brand Consistency Gate

Treat loyalty-program terminology as structured, high-risk editorial data—not free-form summary embellishment.

1. Derive the property/operator and loyalty program from the source and established entity mapping before generating a headline or summary.
2. Reject or hold a generated item when a claim mixes incompatible program vocabularies (for example, a Hyatt property with Marriott Bonvoy category language, or a Marriott property with World of Hyatt elite-benefit language).
3. Claims about award eligibility, category/award-chart moves, elite certificates, and policy changes require explicit support in the cited source. Never infer them from a property reopening, renovation, or unrelated operational announcement.
4. Apply the gate to all public surfaces—stored title, summary/body, tags/entities, slug, Slack fanout, RSS, and rendered page—not only the classifier decision.
5. For an already-published bad item, correct/remove it through the supported production remediation path and verify the public URL, homepage, and feed no longer expose the fabricated claim.
6. Add an exact regression fixture for the reported article plus a generalized cross-program vocabulary test.

Canonical regression example: LoyaltyLobby's `Park Hyatt Tokyo Finally Reopens The Delicatessen Shop From August 3, 2026` supports a Delicatessen reopening only. It must not produce a Marriott Bonvoy Category 8 move, a Globalist 1–7 award claim, or any equivalent unsupported loyalty-program assertion.

## Production Remediation After Classifier Fixes

When Kenneth asks to fix production for an already-pushed Travel Signal classifier/content correction, do not stop at code/test success. Deploy the exact commit and run targeted production remediation when possible:

1. Deploy the pushed Travel Signal ref via the `klaw-vps` git-ref deploy command (see `klaw-vps-service-deployment`).
2. Locate the exact production `raw_posts.id` by article URL/title and inspect the live schema before assuming columns. Current prod linkage uses `story_sources`; `noise_reason` lives in `noise_links`, not necessarily directly on `raw_posts`.
3. Prefer targeted reclassification: `python -u -m app.cli reclassify --raw-post-ids <id> --cleanup-orphans --continue-on-error` inside the prod container.
4. Verify DB effects directly: target `raw_posts.classification`, `classifier_meta`, absence from `story_sources`, deleted/absent `stories` row/slug, and new `noise_links` row with the deterministic/LLM reason.
5. Verify live user-visible surfaces with proxy env unset: bad story URL returns 404/absent, homepage and RSS/feed endpoints contain zero matches for the bad title/phrases, container is healthy, and app healthcheck is OK.

Session-specific detail: see `references/travel-signal-prod-roundup-remediation.md` for the roundup/news-digest deployment and targeted reclassification pattern.

## Spawn Prompt Requirements

For a spawned worker, include:

- the exact Slack correction text,
- title + URL + any generated summary shown in Slack,
- expected classification/output,
- repo path `~/the-travel-signal`,
- required tests and commit/push requirement,
- instruction to avoid memory updates for product feedback.

## Do Not

- Do not store story-specific product feedback in personal memory.
- Do not merely reply “noted” without updating the product prompt/rules when the feedback implies recurring classifier behavior.
- Do not patch Hermes source/config unless the issue is actually Hermes routing/prompt context and Kenneth explicitly asked for that.
- Do not use Slack bot-token delivery for story posting changes; Travel Signal Slack delivery uses webhook-only fanout.
