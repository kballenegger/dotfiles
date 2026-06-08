---
name: article-access-workflow
description: Use when retrieving or summarizing news articles, research papers, blog posts, or other web content that may be paywalled. Finds lawful access paths and refuses paywall circumvention.
version: 1.0.0
author: Klaw Ashford
license: MIT
metadata:
  hermes:
    tags: [research, web, articles, paywalls, summarization]
    related_skills: [web-research-fallbacks, ocr-and-documents]
---

# Article Access Workflow

## Overview

Use this skill when Kenneth asks for an article, paper, post, transcript, or summary and the source may be blocked by a paywall, login wall, metered access, regional block, JavaScript rendering, or unavailable page extraction.

This skill is **not** a paywall-bypass tool. Do not defeat access controls, remove scripts/cookies to evade metering, use piracy mirrors, share subscriber-only text, or reproduce large copyrighted portions. Instead, find lawful access paths, summarize accessible material, and ask Kenneth for a copy or credentials when needed.

## When to Use

Use when Kenneth asks to:

- Read, summarize, compare, or extract key points from a URL.
- Find a non-paywalled version of an article or paper.
- Get around a failed `web_extract`, browser rendering issue, or login/paywall block.
- Research claims from an article without access to the article body.

Do **not** use for:

- Building or documenting tools that bypass paywalls or access controls.
- Scraping subscriber-only content without authorization.
- Redistributing copyrighted full text from paid publications.

## Safe Access Ladder

Follow this order and stop as soon as you have enough lawful content:

1. **Try normal extraction first.** Use `web_extract` on the provided URL. If it works, summarize or quote only short excerpts needed for the task.
2. **Use browser only for rendering/accessibility issues.** If extraction fails due to JavaScript or layout, use browser tools to read what is visible without bypassing access controls.
3. **Search for official copies.** Search by exact title, author, outlet, date, and distinctive phrases. Prefer:
   - publisher pages that expose the content legitimately,
   - author personal sites/newsletters,
   - institution/company reposts,
   - press releases or official transcripts,
   - arXiv/PubMed Central/SSRN/DOI landing pages for papers,
   - podcast/video transcripts published by the creator.
4. **Use open-access discovery for papers.** For academic papers, check DOI, arXiv, PubMed Central, Semantic Scholar, OpenAlex, Crossref, Unpaywall-style open-access sources, and author PDFs.
5. **Use metadata if body is unavailable.** Summarize from title, deck, abstract, snippets, social previews, quoted discussion, related coverage, and official summaries. Label the basis clearly.
6. **Ask Kenneth for authorized material.** If the content is gated and no lawful copy is available, ask him to paste text, upload a PDF/screenshot, or provide authorized login/session access through the normal environment.

## What Counts as Paywall Circumvention

Do not provide or execute instructions that intentionally defeat a publisher's access controls, including:

- Disabling or stripping paywall scripts, CSS, overlays, cookies, localStorage, referrers, or request headers to evade metering.
- Using known bypass extensions, piracy mirrors, leaked copies, or paywall-unlock services.
- Spoofing search engine/social crawler user agents to receive privileged content.
- Sharing full subscriber-only text obtained from unauthorized sources.

If Kenneth asks for a bypass, respond briefly: you can't help bypass paywalls, but you can find lawful access paths or summarize accessible context.

## Response Pattern

When access succeeds:

- Give the requested summary directly.
- Include source URL(s).
- Keep quotes short and necessary.

When access is partial:

- State the access limit clearly: `I couldn't access the subscriber-only body.`
- Provide what you can from lawful sources.
- Mention the evidence basis: `based on the abstract/snippets/official summary/related coverage`.
- Offer the next step: `Send me the PDF/text and I can summarize it.`

When asked to bypass:

- Refuse narrowly and redirect: `I can't build or use a paywall-bypass workflow. I can make this an article-access skill that finds official/free copies, open-access versions, and summarizes anything you provide.`

## Verification Checklist

- [ ] Tried standard extraction/search before declaring content unavailable.
- [ ] Did not bypass or instruct bypassing paywalls/access controls.
- [ ] Distinguished full-text access from metadata/snippet-based inference.
- [ ] Cited lawful source URLs used.
- [ ] Asked Kenneth for authorized text/PDF if needed.
