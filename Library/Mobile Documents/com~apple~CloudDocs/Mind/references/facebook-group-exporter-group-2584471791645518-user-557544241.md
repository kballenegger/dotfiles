# Facebook Group Post Exporter Script (User-in-Group URL Mode)

- Last updated: 2026-04-15 04:05:29
- Source script: `~/klaw-workspace/tmp/facebook-userscripts/export-group-posts-by-user.user.js`
- Source README: `~/klaw-workspace/tmp/facebook-userscripts/README.md`
- Commit: `6a1ac6f`
- Version: v3.2.0
- Patch note: auto-expands "See more" before text extraction

## Script

```javascript
// ==UserScript==
// @name         FB Group Posts Export by User
// @namespace    https://github.com/kenneth-bot/klaw-workspace
// @version      3.2.0
// @description  Export posts from a Facebook group user page (/groups/<gid>/user/<uid>) as JSON + photo ZIP. URL-driven, no hardcoded IDs.
// @author       Kenneth
// @match        https://www.facebook.com/groups/*/user/*
// @grant        GM_xmlhttpRequest
// @connect      fbcdn.net
// @connect      cdnjs.cloudflare.com
// @require      https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js
// @run-at       document-idle
// ==/UserScript==

(function () {
  'use strict';

  // ═══════════════════════════════════════════════════════════════
  // ██  CONFIG
  // ═══════════════════════════════════════════════════════════════
  const CONFIG = {
    // ── Scrolling ──────────────────────────────────────────────
    SCROLL_INTERVAL_MS: 1500,
    SCROLL_STEP_PX: 1200,
    MAX_SCROLL_ATTEMPTS: 500,
    IDLE_THRESHOLD: 8,
    RETRY_BURSTS: 3,
    RETRY_BURST_WAIT_MS: 4000,

    // ── Photo download ─────────────────────────────────────────
    DOWNLOAD_PHOTOS: true,
    MAX_PHOTOS_PER_POST: 50,
    MAX_TOTAL_PHOTOS: 500,
    PHOTO_FETCH_TIMEOUT_MS: 15000,
    JSZIP_CDN: 'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js',

    DRY_RUN: false,
  };
  // ═══════════════════════════════════════════════════════════════

  /* ────────── URL parsing ────────── */

  /**
   * Parse group ID and user ID from the current URL.
   * Expected pattern: /groups/<groupId>/user/<userId>/...
   * Returns { groupId, userId } or null.
   */
  function parseIdsFromUrl(url) {
    const match = (url || window.location.href).match(
      /\/groups\/(\d+)\/user\/(\d+)/
    );
    if (!match) return null;
    return { groupId: match[1], userId: match[2] };
  }

  const PAGE_IDS = parseIdsFromUrl();
  if (!PAGE_IDS) {
    console.log('[FB-Export] Not on a /groups/<gid>/user/<uid> page. Exiting.');
    return;
  }

  const { groupId, userId } = PAGE_IDS;

  /* ────────── logging ────────── */

  function log(...args) {
    console.log('[FB-Export]', ...args);
  }
  function warn(...args) {
    console.warn('[FB-Export]', ...args);
  }

  /* ────────── URL helpers ────────── */

  function cleanUrl(raw) {
    try {
      const u = new URL(raw);
      u.search = '';
      u.hash = '';
      return u.toString();
    } catch {
      return raw;
    }
  }

  function urlPathKey(rawUrl) {
    try {
      const u = new URL(rawUrl);
      return u.origin + u.pathname;
    } catch {
      return rawUrl;
    }
  }

  /* ────────── permalink extraction ────────── */

  function extractPermalink(postEl) {
    const candidateLinks = postEl.querySelectorAll('a[href]');

    // 1. Direct /posts/ or /permalink/ link (best case)
    for (const a of candidateLinks) {
      const h = a.href;
      if (
        (h.includes('/posts/') || h.includes('/permalink/')) &&
        h.includes(groupId)
      ) {
        // Strip comment_id if present (comment links contain the post URL)
        try {
          const u = new URL(h);
          u.searchParams.delete('comment_id');
          u.searchParams.delete('reply_comment_id');
          u.search = '';
          u.hash = '';
          return u.toString();
        } catch {
          return cleanUrl(h);
        }
      }
    }

    // 2. Numeric post ID link under the group
    for (const a of candidateLinks) {
      const h = a.href;
      if (
        h.includes('/groups/' + groupId + '/') &&
        /\/\d+\/?(\?|$)/.test(h)
      ) {
        return cleanUrl(h);
      }
    }

    // 3. Photo links often contain set=gm.<postId> — extract post ID
    for (const a of candidateLinks) {
      const h = a.href || '';
      const setMatch = h.match(/set=gm\.(\d+)/);
      if (setMatch) {
        return `https://www.facebook.com/groups/${groupId}/posts/${setMatch[1]}/`;
      }
    }

    return null;
  }

  /* ────────── timestamp extraction ────────── */

  function extractTimestamp(postEl) {
    // 1. Classic <abbr> timestamps (older FB layout)
    const abbrEls = postEl.querySelectorAll('abbr[data-utime], abbr[title]');
    for (const el of abbrEls) {
      return el.getAttribute('title') || el.textContent.trim();
    }

    // 2. Modern FB: aria-labelledby on timestamp links → hidden <span id="...">
    //    These links often have href containing __cft__ or /posts/
    const labelledEls = postEl.querySelectorAll('a[aria-labelledby]');
    for (const el of labelledEls) {
      // Skip elements inside comments
      if (el.closest('[role="article"]')) continue;
      const labelId = el.getAttribute('aria-labelledby');
      if (!labelId) continue;
      const labelEl = document.getElementById(labelId);
      if (labelEl) {
        const text = labelEl.textContent.trim();
        if (text && text.length < 60 && /\d/.test(text)) return text;
      }
    }

    // 3. Timestamp link text (links to /posts/ or /permalink/)
    const links = postEl.querySelectorAll('a[href]');
    for (const a of links) {
      // Skip links inside comment articles
      if (a.closest('[role="article"]')) continue;
      const h = a.href || '';
      if (
        (h.includes('/posts/') || h.includes('/permalink/') || h.includes('__cft__')) &&
        (h.includes(groupId) || h.includes('__cft__'))
      ) {
        const txt = a.textContent.trim();
        if (txt.length > 0 && txt.length < 60 && /\d/.test(txt)) return txt;
      }
    }

    // 4. aria-label with date-like patterns (skip comment articles)
    const ariaEls = postEl.querySelectorAll('[aria-label]');
    for (const el of ariaEls) {
      if (el.closest('[role="article"]')) continue;
      const label = el.getAttribute('aria-label');
      if (
        label &&
        label.length < 80 &&
        /\d/.test(label) &&
        /hour|min|sec|day|week|month|year|ago|am|pm|january|february|march|april|may|june|july|august|september|october|november|december/i.test(
          label
        )
      ) {
        return label;
      }
    }
    return null;
  }

  /* ────────── "See more" expansion ────────── */

  /**
   * Localized patterns for "See more" buttons in Facebook.
   * Matches common languages: English, Spanish, French, Portuguese, German,
   * Italian, Indonesian, Vietnamese, Filipino, Thai, Arabic, Hindi, etc.
   * Also matches aria-label variants.
   */
  const SEE_MORE_PATTERNS = [
    /^see\s*more$/i,
    /^ver\s*m[aá]s$/i,
    /^voir\s*plus$/i,
    /^ver\s*mais$/i,
    /^mehr\s*ansehen$/i,
    /^vedi\s*altro$/i,
    /^lihat\s*selengkapnya$/i,
    /^xem\s*th[eê]m$/i,
    /^tingnan\s*ang\s*iba\s*pa$/i,
    /^ดูเพิ่มเติม$/,
    /^عرض المزيد$/,
    /^और\s*देखें$/,
    /^もっと見る$/,
    /^더\s*보기$/,
    /^查看更多$/,
    /^顯示更多$/,
  ];

  /**
   * Check if a text matches any known "See more" pattern.
   */
  function isSeeMoreText(text) {
    if (!text) return false;
    const trimmed = text.trim();
    return SEE_MORE_PATTERNS.some((re) => re.test(trimmed));
  }

  /**
   * Find "See more" buttons inside a post element.
   * Facebook renders these as <div role="button">, <span>, or <a> elements
   * with localized "See more" text or matching aria-label.
   */
  function findSeeMoreButtons(container) {
    const buttons = [];
    // role="button" elements and <a> tags are the most common wrappers
    const candidates = container.querySelectorAll(
      '[role="button"], a[href="#"], span[style*="cursor"]'
    );
    for (const el of candidates) {
      if (isInsideComment(el)) continue;
      // Check direct text content (avoid matching inside nested buttons)
      const text = el.textContent.trim();
      if (isSeeMoreText(text)) {
        buttons.push(el);
        continue;
      }
      // Check aria-label
      const ariaLabel = el.getAttribute('aria-label') || '';
      if (isSeeMoreText(ariaLabel)) {
        buttons.push(el);
      }
    }
    return buttons;
  }

  /**
   * Expand all collapsed "See more" text blocks inside a set of post elements.
   * Clicks each button and waits briefly for the DOM to update.
   * Idempotent: already-expanded posts won't have "See more" buttons visible.
   * Returns the number of buttons clicked.
   */
  async function expandSeeMoreInPosts(postElements) {
    let totalClicked = 0;
    for (const postEl of postElements) {
      const seeMoreBtns = findSeeMoreButtons(postEl);
      for (const btn of seeMoreBtns) {
        try {
          btn.click();
          totalClicked++;
        } catch {
          // Ignore click errors (e.g., element removed from DOM)
        }
      }
    }
    if (totalClicked > 0) {
      // Wait for DOM to update after clicking all buttons in this batch
      await sleep(600);
      extractionStats.see_more_expanded += totalClicked;
      log(`Expanded ${totalClicked} "See more" button(s).`);
    }
    return totalClicked;
  }

  /* ────────── text extraction ────────── */

  /**
   * Check if an element is inside a comment article (role="article" with
   * "Comment" aria-label) to avoid mixing comment text into post body.
   */
  function isInsideComment(el) {
    const article = el.closest('[role="article"]');
    if (!article) return false;
    const label = article.getAttribute('aria-label') || '';
    return label.startsWith('Comment');
  }

  /**
   * Extract post body text with a fallback chain:
   * 1. data-ad-preview="message" — standard text posts
   * 2. data-ad-comet-preview="message" — alternate attribute
   * 3. data-ad-rendering-role="story_message" — styled text posts (colored bg)
   * 4. div[dir="auto"] visible text blocks (>10 chars), excluding comments
   * 5. data-ad-rendering-role="title" — link-share titles as last resort
   */
  function extractText(postEl) {
    // 1–2. Standard message containers
    const msgEl =
      postEl.querySelector('[data-ad-preview="message"]') ||
      postEl.querySelector('[data-ad-comet-preview="message"]');
    if (msgEl && !isInsideComment(msgEl)) {
      const t = msgEl.innerText.trim();
      if (t) return t;
    }

    // 3. Styled text posts (data-ad-rendering-role="story_message")
    const storyMsgEl = postEl.querySelector('[data-ad-rendering-role="story_message"]');
    if (storyMsgEl && !isInsideComment(storyMsgEl)) {
      const t = storyMsgEl.innerText.trim();
      if (t) return t;
    }

    // 4. Fallback: div[dir="auto"] blocks not inside comments
    const candidates = postEl.querySelectorAll('div[dir="auto"]');
    const texts = [];
    for (const c of candidates) {
      if (isInsideComment(c)) continue;
      // Skip elements that are part of the author name / header area
      if (c.closest('h2, h3, h4')) continue;
      const t = c.innerText.trim();
      if (t.length > 10) texts.push(t);
    }
    if (texts.length > 0) return [...new Set(texts)].join('\n\n');

    // 5. Link-share title (e.g. shared article headline)
    const titleEl = postEl.querySelector('[data-ad-rendering-role="title"]');
    if (titleEl && !isInsideComment(titleEl)) {
      const t = titleEl.innerText.trim();
      if (t) return t;
    }

    return '';
  }

  /* ────────── photo URL extraction (robust) ────────── */

  function isFbCdnUrl(url) {
    return url && (url.includes('scontent') || url.includes('fbcdn'));
  }

  /**
   * Check if a URL path indicates a content photo (not avatar/profile).
   * Avatar paths contain segments like t39.30808-1, t1.6435-1 (suffix -1).
   * Content photos use -6 or -9 suffixes, or don't match the avatar pattern.
   */
  function isAvatarUrl(url) {
    if (!url) return false;
    // Profile/avatar images end with -1 in the type segment (e.g. t39.30808-1, t1.6435-1)
    if (/\/v\/t\d+\.\d+-1\//.test(url)) return true;
    // Default avatar placeholders
    if (url.includes('t1.30497-1')) return true;
    return false;
  }

  function isStaticAssetUrl(url) {
    if (!url) return false;
    return url.includes('static.xx.fbcdn.net/rsrc.php') || url.startsWith('data:');
  }

  /**
   * Upgrade a thumbnail URL to higher quality by stripping or replacing
   * the stp (size/transform) parameter.
   */
  function upgradeToHighRes(url) {
    if (!url) return url;
    try {
      const u = new URL(url);
      const stp = u.searchParams.get('stp');
      if (stp && /[ps]\d+x\d+|cp\d|fb\d+/.test(stp)) {
        // Remove the size constraint to get original resolution
        u.searchParams.delete('stp');
        return u.toString();
      }
      return url;
    } catch {
      return url;
    }
  }

  /**
   * Check if a URL is a Facebook styled-text-post background pattern
   * (decorative, not user content). These use type segment like t39.10873-6.
   */
  function isDecorativeBackground(url) {
    if (!url) return false;
    return /\/v\/t\d+\.10873-\d+\//.test(url);
  }

  /**
   * Extract high-quality photo URLs from a post element.
   *
   * Strategy:
   * 1. img[data-imgperflogname="feedImage"] — primary feed images
   * 2. Photo gallery anchors (href containing /photo/?fbid=...&set=gm.) → inner img
   * 3. All remaining <img> with scontent/fbcdn src, excluding avatars/icons
   * 4. srcset and data-src attributes (lazy-loaded images)
   * 5. Background images on elements (excluding decorative post backgrounds)
   *
   * Excludes: avatars (SVG <image>), profileCoverPhoto, reaction icons,
   *           static assets, tiny images (<=50px), comment images,
   *           decorative styled-text backgrounds.
   */
  function extractPhotos(postEl) {
    const seen = new Set();
    const urls = [];

    function add(url) {
      if (!url || !isFbCdnUrl(url)) return;
      if (isAvatarUrl(url) || isStaticAssetUrl(url)) return;
      if (isDecorativeBackground(url)) return;
      const upgraded = upgradeToHighRes(url);
      const key = urlPathKey(upgraded);
      if (seen.has(key)) return;
      seen.add(key);
      urls.push(upgraded);
    }

    // 1. Primary feed images — most reliable signal (skip if inside comments)
    const feedImgs = postEl.querySelectorAll('img[data-imgperflogname="feedImage"]');
    for (const img of feedImgs) {
      if (isInsideComment(img)) continue;
      add(img.src);
      // Also check srcset for higher-res versions
      const srcset = img.getAttribute('srcset');
      if (srcset) {
        const highRes = parseBestSrcset(srcset);
        if (highRes) add(highRes);
      }
    }

    // 2. Photo gallery links (multi-photo posts with thumbnails)
    const photoAnchors = postEl.querySelectorAll('a[href*="/photo/"]');
    for (const a of photoAnchors) {
      if (isInsideComment(a)) continue;
      const href = a.href || '';
      if (!href.includes('fbid=')) continue;
      const img = a.querySelector('img');
      if (img && img.src && isFbCdnUrl(img.src)) {
        add(img.src);
      }
    }

    // 3. Remaining <img> with CDN src — catch anything missed above
    const allImgs = postEl.querySelectorAll('img');
    for (const img of allImgs) {
      if (isInsideComment(img)) continue;

      const perfLog = img.getAttribute('data-imgperflogname') || '';
      if (perfLog === 'profileCoverPhoto') continue;
      if (img.getAttribute('draggable') === 'false') continue;
      if (img.getAttribute('role') === 'presentation') continue;

      const src = img.src || '';
      if (isStaticAssetUrl(src)) continue;
      if (!isFbCdnUrl(src)) continue;
      if (isAvatarUrl(src)) continue;

      const w = img.naturalWidth || parseInt(img.getAttribute('width'), 10) || 0;
      const h = img.naturalHeight || parseInt(img.getAttribute('height'), 10) || 0;
      if ((w > 0 && w <= 50) || (h > 0 && h <= 50)) continue;

      add(src);

      // 4. Check srcset and data-src for lazy-loaded higher-res
      const srcset = img.getAttribute('srcset');
      if (srcset) {
        const highRes = parseBestSrcset(srcset);
        if (highRes) add(highRes);
      }
      const dataSrc = img.getAttribute('data-src');
      if (dataSrc) add(dataSrc);
    }

    // 5. Background images (excluding decorative post style backgrounds)
    const bgEls = postEl.querySelectorAll('[style*="background-image"]');
    for (const el of bgEls) {
      if (isInsideComment(el)) continue;
      const style = el.getAttribute('style') || '';
      const match = style.match(
        /url\(["']?(https:\/\/[^"')]+(?:scontent|fbcdn)[^"')]+)["']?\)/
      );
      if (match && !isAvatarUrl(match[1]) && !isDecorativeBackground(match[1])) {
        add(match[1]);
      }
    }

    return urls;
  }

  /**
   * Parse a srcset attribute and return the highest-resolution CDN URL.
   */
  function parseBestSrcset(srcset) {
    if (!srcset) return null;
    let best = null;
    let bestW = 0;
    for (const entry of srcset.split(',')) {
      const parts = entry.trim().split(/\s+/);
      if (parts.length < 1) continue;
      const url = parts[0];
      if (!isFbCdnUrl(url)) continue;
      const wMatch = (parts[1] || '').match(/(\d+)w/);
      const w = wMatch ? parseInt(wMatch[1], 10) : 0;
      if (w > bestW || !best) {
        best = url;
        bestW = w;
      }
    }
    return best;
  }

  /* ────────── post discovery ────────── */

  /**
   * Find post containers on /groups/<gid>/user/<uid> pages.
   *
   * Facebook uses a virtualized feed where each post lives inside a
   * div[data-virtualized="false"] container. Posts that have been scrolled
   * out may be replaced with data-virtualized="true" empty skeletons.
   *
   * Fallback: role="article" elements that are NOT comments (for older
   * layouts or non-virtualized pages).
   */
  function findPostElements() {
    // Primary: virtualized feed containers (modern FB layout)
    const virtualized = document.querySelectorAll('[data-virtualized="false"]');
    if (virtualized.length > 0) {
      return [...virtualized];
    }

    // Fallback: role="article" minus comments and loading skeletons
    const articles = document.querySelectorAll('[role="article"]');
    const posts = [];
    for (const el of articles) {
      const label = el.getAttribute('aria-label') || '';
      if (label.startsWith('Comment')) continue;
      if (label.startsWith('Loading')) continue;
      // Skip articles nested inside another article (reply threads)
      if (el.parentElement && el.parentElement.closest('[role="article"]')) continue;
      posts.push(el);
    }
    return posts;
  }

  /* ────────── collection state ────────── */

  const collectedPosts = new Map();
  const extractionStats = {
    posts_found: 0,
    posts_with_text: 0,
    posts_with_images: 0,
    total_images: 0,
    posts_with_permalink: 0,
    posts_with_timestamp: 0,
    see_more_expanded: 0,
    discovery_method: 'unknown',
  };

  async function scanCurrentPosts() {
    const articles = findPostElements();
    extractionStats.discovery_method =
      articles.length > 0 && articles[0].hasAttribute('data-virtualized')
        ? 'data-virtualized'
        : 'role-article-fallback';

    // Expand collapsed "See more" text before extracting content
    await expandSeeMoreInPosts(articles);

    let newCount = 0;
    for (const article of articles) {
      const permalink = extractPermalink(article);
      const key = permalink || `no-link-${collectedPosts.size}-${Date.now()}`;
      if (collectedPosts.has(key)) continue;

      const text = extractText(article);
      const photos = extractPhotos(article);
      const timestamp = extractTimestamp(article);

      collectedPosts.set(key, {
        permalink: permalink || '(no permalink found)',
        timestamp: timestamp || '(no timestamp)',
        text,
        photos,
        image_urls: photos.length > 0 ? [...photos] : [],
        scraped_at: new Date().toISOString(),
      });
      newCount++;

      // Update stats
      extractionStats.posts_found = collectedPosts.size;
      if (text) extractionStats.posts_with_text++;
      if (photos.length > 0) extractionStats.posts_with_images++;
      extractionStats.total_images += photos.length;
      if (permalink) extractionStats.posts_with_permalink++;
      if (timestamp) extractionStats.posts_with_timestamp++;

      log(`Found post #${collectedPosts.size}: ${permalink || '(no link)'} [${photos.length} images, text=${text ? text.length + 'ch' : 'none'}]`);
    }
    return newCount;
  }

  /* ────────── scrolling with retry bursts ────────── */

  function sleep(ms) {
    return new Promise((r) => setTimeout(r, ms));
  }

  async function autoScroll(statusFn) {
    let attempts = 0;
    let idleCount = 0;
    let retryBudget = CONFIG.RETRY_BURSTS;
    let prevSize = collectedPosts.size;
    let prevHeight = document.documentElement.scrollHeight;

    while (attempts < CONFIG.MAX_SCROLL_ATTEMPTS) {
      attempts++;
      window.scrollBy(0, CONFIG.SCROLL_STEP_PX);
      await sleep(CONFIG.SCROLL_INTERVAL_MS);

      await scanCurrentPosts();

      const currHeight = document.documentElement.scrollHeight;
      const currSize = collectedPosts.size;
      const heightGrew = currHeight > prevHeight;
      const postsGrew = currSize > prevSize;

      if (!heightGrew && !postsGrew) {
        idleCount++;
      } else {
        idleCount = 0;
        prevHeight = currHeight;
        prevSize = currSize;
      }

      statusFn(
        `Scrolling… ${currSize} posts (scroll ${attempts}, idle ${idleCount})`
      );

      if (idleCount >= CONFIG.IDLE_THRESHOLD) {
        if (retryBudget <= 0) {
          log('Idle threshold reached with no retry budget left. Stopping.');
          break;
        }

        retryBudget--;
        const burstNum = CONFIG.RETRY_BURSTS - retryBudget;
        log(`Idle → retry burst ${burstNum}/${CONFIG.RETRY_BURSTS}…`);
        statusFn(
          `Retry ${burstNum}/${CONFIG.RETRY_BURSTS}… ${currSize} posts`
        );

        window.scrollTo(0, document.documentElement.scrollHeight);
        await sleep(CONFIG.RETRY_BURST_WAIT_MS);
        await scanCurrentPosts();

        const afterHeight = document.documentElement.scrollHeight;
        const afterSize = collectedPosts.size;

        if (afterHeight > prevHeight || afterSize > prevSize) {
          log('Retry burst found new content — resuming normal scroll.');
          idleCount = 0;
          prevHeight = afterHeight;
          prevSize = afterSize;
        } else {
          log('Retry burst found nothing new.');
          idleCount = 0;
        }
      }
    }

    log(
      `Scrolling complete. ${attempts} scrolls, ${collectedPosts.size} posts collected, retries left=${retryBudget}`
    );
  }

  /* ────────── JSZip loader ────────── */

  async function ensureJSZip() {
    if (typeof JSZip !== 'undefined') return JSZip;
    if (typeof unsafeWindow !== 'undefined' && unsafeWindow.JSZip) {
      return unsafeWindow.JSZip;
    }

    log('JSZip not pre-loaded, attempting dynamic CDN load…');
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = CONFIG.JSZIP_CDN;
      script.onload = () => {
        const ref =
          (typeof JSZip !== 'undefined' && JSZip) ||
          (typeof unsafeWindow !== 'undefined' && unsafeWindow.JSZip) ||
          null;
        if (ref) {
          log('JSZip loaded dynamically.');
          resolve(ref);
        } else {
          reject(new Error('JSZip script loaded but constructor not found'));
        }
      };
      script.onerror = () =>
        reject(new Error('Failed to load JSZip from CDN'));
      document.head.appendChild(script);
    });
  }

  /* ────────── image fetching ────────── */

  function fetchImageAsArrayBuffer(url) {
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method: 'GET',
        url: url,
        responseType: 'arraybuffer',
        timeout: CONFIG.PHOTO_FETCH_TIMEOUT_MS,
        onload: (resp) => {
          if (resp.status >= 200 && resp.status < 300) {
            resolve(resp.response);
          } else {
            reject(new Error(`HTTP ${resp.status}`));
          }
        },
        onerror: () => reject(new Error('Network error')),
        ontimeout: () => reject(new Error('Timeout')),
      });
    });
  }

  function guessExtension(url) {
    const match = url.match(/\.(jpe?g|png|webp|gif)/i);
    if (match) return match[1].toLowerCase().replace('jpeg', 'jpg');
    return 'jpg';
  }

  /* ────────── download helpers ────────── */

  function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }, 1000);
  }

  function downloadJSON(posts) {
    const output = {
      meta: {
        group_id: groupId,
        user_id: userId,
        exported_at: new Date().toISOString(),
        post_count: posts.length,
        extraction_stats: { ...extractionStats },
      },
      posts,
    };
    const blob = new Blob([JSON.stringify(output, null, 2)], {
      type: 'application/json',
    });
    downloadBlob(
      blob,
      `fb-group-${groupId}-user-${userId}-${Date.now()}.json`
    );
  }

  /* ────────── photo ZIP pipeline ────────── */

  async function buildPhotoZip(posts, statusFn) {
    let JSZipRef;
    try {
      JSZipRef = await ensureJSZip();
    } catch (e) {
      warn('Could not load JSZip:', e.message);
      return { zip: null, totalPhotos: 0, failures: [{ error: 'JSZip unavailable: ' + e.message }] };
    }

    const zip = new JSZipRef();
    const failures = [];
    let totalPhotos = 0;

    for (let i = 0; i < posts.length; i++) {
      const post = posts[i];
      if (!post.photos || post.photos.length === 0) continue;

      const postDir = `post-${String(i + 1).padStart(3, '0')}`;
      const photosToFetch = post.photos.slice(0, CONFIG.MAX_PHOTOS_PER_POST);

      for (let j = 0; j < photosToFetch.length; j++) {
        if (totalPhotos >= CONFIG.MAX_TOTAL_PHOTOS) {
          log(`Global photo cap (${CONFIG.MAX_TOTAL_PHOTOS}) reached.`);
          break;
        }

        const photoUrl = photosToFetch[j];
        const ext = guessExtension(photoUrl);
        const filename = `${postDir}/photo-${String(j + 1).padStart(2, '0')}.${ext}`;

        statusFn(
          `Downloading photos… ${totalPhotos + 1} (post ${i + 1}/${posts.length})`
        );

        try {
          const buf = await fetchImageAsArrayBuffer(photoUrl);
          zip.file(filename, buf);
          totalPhotos++;
        } catch (e) {
          failures.push({
            post_index: i + 1,
            photo_index: j + 1,
            url: photoUrl,
            error: e.message,
          });
          warn(`Failed to fetch photo: ${filename} — ${e.message}`);
        }
      }

      if (totalPhotos >= CONFIG.MAX_TOTAL_PHOTOS) break;
    }

    zip.file('manifest.json', JSON.stringify(posts, null, 2));
    if (failures.length > 0) {
      zip.file('photo-failures.json', JSON.stringify(failures, null, 2));
    }

    return { zip, totalPhotos, failures };
  }

  /* ────────── UI ────────── */

  let panelEl = null;
  let statusEl = null;

  function createPanel() {
    panelEl = document.createElement('div');
    panelEl.id = 'fb-export-panel';
    Object.assign(panelEl.style, {
      position: 'fixed',
      bottom: '20px',
      right: '20px',
      zIndex: '99999',
      background: '#1a1a2e',
      color: '#fff',
      padding: '14px 18px',
      borderRadius: '10px',
      fontFamily: 'Helvetica, Arial, sans-serif',
      fontSize: '13px',
      boxShadow: '0 4px 16px rgba(0,0,0,0.4)',
      userSelect: 'none',
      maxWidth: '340px',
      display: 'flex',
      flexDirection: 'column',
      gap: '8px',
    });

    // Title
    const title = document.createElement('div');
    title.textContent = `Export: group ${groupId} / user ${userId}`;
    Object.assign(title.style, {
      fontSize: '11px',
      opacity: '0.7',
      marginBottom: '2px',
    });
    panelEl.appendChild(title);

    // Full Scan + Export button
    const fullBtn = makeButton('Full Scan + Export', '#1877f2', handleFullScan);
    fullBtn.id = 'fb-export-full-btn';
    panelEl.appendChild(fullBtn);

    // Export Loaded Now button
    const nowBtn = makeButton('Export Loaded Now', '#42b72a', handleExportNow);
    nowBtn.id = 'fb-export-now-btn';
    panelEl.appendChild(nowBtn);

    // Status line
    statusEl = document.createElement('div');
    statusEl.id = 'fb-export-status';
    Object.assign(statusEl.style, {
      fontSize: '11px',
      opacity: '0.8',
      minHeight: '16px',
    });
    panelEl.appendChild(statusEl);

    document.body.appendChild(panelEl);
  }

  function makeButton(text, color, handler) {
    const btn = document.createElement('div');
    btn.textContent = text;
    Object.assign(btn.style, {
      background: color,
      color: '#fff',
      padding: '10px 16px',
      borderRadius: '6px',
      fontWeight: 'bold',
      fontSize: '13px',
      cursor: 'pointer',
      textAlign: 'center',
      transition: 'opacity 0.2s',
    });
    btn.addEventListener('mouseenter', () => { btn.style.opacity = '0.85'; });
    btn.addEventListener('mouseleave', () => { btn.style.opacity = '1'; });
    btn.addEventListener('click', handler);
    return btn;
  }

  function updateStatus(text) {
    if (statusEl) statusEl.textContent = text;
  }

  function setButtonsEnabled(enabled) {
    const btns = panelEl ? panelEl.querySelectorAll('#fb-export-full-btn, #fb-export-now-btn') : [];
    for (const btn of btns) {
      btn.style.opacity = enabled ? '1' : '0.5';
      btn.style.pointerEvents = enabled ? 'auto' : 'none';
    }
  }

  /* ────────── export pipeline ────────── */

  let running = false;

  async function runExport(posts) {
    const total = posts.length;

    if (CONFIG.DRY_RUN) {
      updateStatus(`DRY RUN: ${total} posts found.`);
      log('DRY_RUN — no files downloaded.');
      log('Posts:', posts.map((p) => p.permalink));
      return;
    }

    if (total === 0) {
      updateStatus('No posts found.');
      return;
    }

    updateStatus(`Exporting ${total} posts as JSON…`);
    downloadJSON(posts);

    if (CONFIG.DOWNLOAD_PHOTOS) {
      const totalPhotoUrls = posts.reduce(
        (n, p) => n + (p.photos ? p.photos.length : 0),
        0
      );
      if (totalPhotoUrls > 0) {
        updateStatus(`Building photo ZIP (${totalPhotoUrls} URLs found)…`);
        const result = await buildPhotoZip(posts, updateStatus);

        if (result.zip) {
          updateStatus('Generating ZIP file…');
          try {
            const content = await result.zip.generateAsync({ type: 'blob' });
            downloadBlob(
              content,
              `fb-photos-${groupId}-user-${userId}-${Date.now()}.zip`
            );
            const failMsg =
              result.failures.length > 0
                ? ` (${result.failures.length} failed)`
                : '';
            updateStatus(
              `Done! ${total} posts + ${result.totalPhotos} photos${failMsg}`
            );
          } catch (e) {
            warn('ZIP generation failed:', e);
            updateStatus(`Done! ${total} posts. ZIP failed: ${e.message}`);
          }
        } else {
          updateStatus(`Done! ${total} posts (photo URLs in JSON, ZIP unavailable).`);
        }
      } else {
        updateStatus(`Done! ${total} posts exported (no photos found).`);
      }
    } else {
      updateStatus(`Done! ${total} posts exported (JSON only).`);
    }
  }

  async function handleFullScan() {
    if (running) return;
    running = true;
    setButtonsEnabled(false);

    log('Full Scan + Export. Group:', groupId, 'User:', userId);
    updateStatus('Expanding & scanning visible posts…');

    await scanCurrentPosts();
    log(`After initial scan: ${collectedPosts.size} posts`);

    updateStatus(`Auto-scrolling… ${collectedPosts.size} posts so far`);
    await autoScroll(updateStatus);

    await scanCurrentPosts();
    const posts = [...collectedPosts.values()];
    log(`Done scrolling. Total posts: ${posts.length}`);

    await runExport(posts);

    running = false;
    setButtonsEnabled(true);
  }

  async function handleExportNow() {
    if (running) return;
    running = true;
    setButtonsEnabled(false);

    log('Export Loaded Now. Group:', groupId, 'User:', userId);
    updateStatus('Expanding & scanning loaded posts…');

    await scanCurrentPosts();
    const posts = [...collectedPosts.values()];
    log(`Found ${posts.length} loaded posts`);

    await runExport(posts);

    running = false;
    setButtonsEnabled(true);
  }

  /* ────────── init ────────── */

  log(`Detected group=${groupId}, user=${userId}. Injecting export panel.`);
  createPanel();
})();

```

## README

```markdown
# FB Group Posts Export by User — Tampermonkey Userscript

Exports posts from a Facebook group user page as a downloadable JSON file **plus a ZIP of all photos**. **Read-only** — no posting, liking, or write actions.

## Quick Start

1. Install [Tampermonkey](https://www.tampermonkey.net/) in your browser.
2. Open Tampermonkey dashboard → **Create a new script**.
3. Paste the contents of `export-group-posts-by-user.user.js` and save.
4. Navigate to a Facebook group user page:
   ```
   https://www.facebook.com/groups/<GROUP_ID>/user/<USER_ID>/
   ```
   For example: `https://www.facebook.com/groups/2584471791645518/user/557544241/`
5. A dark panel appears at the bottom-right with two buttons:
   - **Full Scan + Export** — auto-scrolls the entire feed, then exports all found posts.
   - **Export Loaded Now** — immediately exports only the posts currently visible on the page (no scrolling).
6. Click either button. When done, files download:
   - **JSON** — structured post data (text, timestamps, photo URLs, permalinks, `image_urls` list).
   - **ZIP** — all photos as actual image files, organised by post (if `DOWNLOAD_PHOTOS` is enabled).

## URL-Driven Design

The script **parses the group ID and user ID directly from the URL** — no hardcoded IDs needed. It only activates on pages matching:

```
https://www.facebook.com/groups/*/user/*
```

On these pages, Facebook already filters posts by the target user, so the script collects **all loaded posts** without any additional author matching.

## Two Export Modes

| Button | Behavior |
|--------|----------|
| **Full Scan + Export** | Scrolls the feed to load all posts, then exports everything. Best for complete exports. |
| **Export Loaded Now** | Exports only posts currently in the DOM. Useful when you've manually scrolled to the content you want, or for a quick snapshot. |

Both buttons are disabled while an export is in progress. A status line below the buttons shows real-time progress.

## Configuration

Edit the `CONFIG` block at the top of the script:

### Scrolling / Pagination

| Key | Default | Description |
|-----|---------|-------------|
| `SCROLL_INTERVAL_MS` | `1500` | Milliseconds between scroll steps |
| `SCROLL_STEP_PX` | `1200` | Pixels per scroll step |
| `MAX_SCROLL_ATTEMPTS` | `500` | Total scroll iteration cap |
| `IDLE_THRESHOLD` | `8` | Consecutive idle scrolls before triggering a retry burst |
| `RETRY_BURSTS` | `3` | Number of retry bursts after the feed appears exhausted |
| `RETRY_BURST_WAIT_MS` | `4000` | Extra wait time during each retry burst |

### Photo Download

| Key | Default | Description |
|-----|---------|-------------|
| `DOWNLOAD_PHOTOS` | `true` | `true` = download actual image files into a ZIP. `false` = JSON only (URLs listed but not downloaded) |
| `MAX_PHOTOS_PER_POST` | `50` | Max photos to download per individual post |
| `MAX_TOTAL_PHOTOS` | `500` | Global cap on total photos across all posts |
| `PHOTO_FETCH_TIMEOUT_MS` | `15000` | Per-image fetch timeout |

### Other

| Key | Default | Description |
|-----|---------|-------------|
| `DRY_RUN` | `false` | Set `true` to count posts without downloading anything |

## How Scrolling Works

1. **Height + post-count tracking** — after each scroll, it checks whether `scrollHeight` grew and whether new posts appeared.
2. **Idle counter** — if neither metric grew for `IDLE_THRESHOLD` consecutive scrolls, a **retry burst** fires: jump to page bottom + wait `RETRY_BURST_WAIT_MS`.
3. **Retry budget** — up to `RETRY_BURSTS` bursts. If a burst finds new content, normal scrolling resumes.
4. **Safety cap** — `MAX_SCROLL_ATTEMPTS` is the hard ceiling.

## How Post Discovery Works

The script uses a two-tier strategy to find posts:

1. **Primary: `data-virtualized="false"` containers** — Facebook's modern virtualized feed wraps each rendered post in these containers. Posts scrolled out of view become `data-virtualized="true"` empty skeletons.
2. **Fallback: `role="article"` elements** — for older FB layouts. Automatically excludes comments (`aria-label="Comment by …"`), loading skeletons, and nested reply articles.

## Automatic "See More" Expansion

Before extracting text, the script automatically clicks all visible "See more" buttons inside each post to reveal truncated content. This runs:

- **Before each scan pass** — both during initial scan and after each scroll step.
- **In both export modes** — "Export Loaded Now" and "Full Scan + Export".

The expansion is **idempotent**: already-expanded posts have no "See more" buttons to click. A 600ms delay after clicking allows Facebook's DOM to render the full text before extraction.

**Localization:** The script recognizes "See more" buttons in English, Spanish, French, Portuguese, German, Italian, Indonesian, Vietnamese, Filipino, Thai, Arabic, Hindi, Japanese, Korean, and Chinese (Simplified + Traditional). Additional languages can be added to the `SEE_MORE_PATTERNS` array.

**Limitations:**
- Some posts use nested "See more" links that require multiple expansions — the script clicks all visible buttons in a single pass but does not recurse into newly revealed "See more" links.
- If Facebook changes the button markup (e.g., removes `role="button"` or changes the text), expansion may silently fail and the text field will contain the truncated version.
- The `see_more_expanded` counter in `extraction_stats` tracks how many buttons were clicked across all scan passes.

## How Text Extraction Works

Post body text is extracted with a fallback chain:

1. **`data-ad-preview="message"`** — standard text posts (most common).
2. **`data-ad-comet-preview="message"`** — alternate attribute on the same element.
3. **`data-ad-rendering-role="story_message"`** — styled text posts with colored backgrounds.
4. **`div[dir="auto"]` visible text blocks** — sanitized fallback; skips comment text, author names, and short fragments.
5. **`data-ad-rendering-role="title"`** — link-share headline as a last resort.

All selectors exclude text inside comment articles to prevent mixing comment text into post body.

## How Image Detection Works

The script uses multiple strategies to find post photos reliably:

1. **`data-imgperflogname="feedImage"`** — Facebook's own attribute for feed content images (most reliable signal).
2. **Photo gallery anchors** — multi-photo posts render thumbnails inside `<a href="/photo/?fbid=...">` links; the script finds inner `<img>` elements.
3. **CDN URL fallback** — any remaining `<img>` with `scontent`/`fbcdn` src that passes exclusion filters.
4. **`srcset` / `data-src` attributes** — lazy-loaded or responsive images; the highest-resolution variant is selected.
5. **Background images** — elements with `background-image` pointing to CDN URLs (excluding decorative styled-text post backgrounds).

**Excluded automatically:**
- Avatars/profile pictures (SVG `<image>` elements, and URLs with avatar path patterns like `-1` type suffixes)
- Cover photos (`data-imgperflogname="profileCoverPhoto"`)
- Reaction icons, emoji sprites (`draggable="false"`, `role="presentation"`, `static.xx.fbcdn.net/rsrc.php/`)
- Tiny images (≤50px width or height)
- Decorative styled-text-post background patterns (`t39.10873-*`)
- Images inside comment sections

**Quality upgrade:** Thumbnail URLs (e.g., `p160x160`) are automatically upgraded by stripping the size transform parameter to request the original resolution.

## Output Files

### JSON (`fb-group-<gid>-user-<uid>-<timestamp>.json`)

```json
{
  "meta": {
    "group_id": "123456",
    "user_id": "789012",
    "exported_at": "2026-04-15T12:00:00.000Z",
    "post_count": 42,
    "extraction_stats": {
      "posts_found": 42,
      "posts_with_text": 38,
      "posts_with_images": 25,
      "total_images": 67,
      "posts_with_permalink": 42,
      "posts_with_timestamp": 40,
      "see_more_expanded": 12,
      "discovery_method": "data-virtualized"
    }
  },
  "posts": [
    {
      "permalink": "https://www.facebook.com/groups/123/posts/456/",
      "timestamp": "April 10 at 3:42 PM",
      "text": "Post body text here…",
      "photos": [
        "https://scontent-…/photo.jpg"
      ],
      "image_urls": [
        "https://scontent-…/photo.jpg"
      ],
      "scraped_at": "2026-04-15T12:00:00.000Z"
    }
  ]
}
```

The `image_urls` field contains the same URLs as `photos` — included explicitly as requested metadata for downstream processing.

The `extraction_stats` object provides debug counters for verifying extraction quality. If `posts_with_text` is much lower than `posts_found`, the DOM structure may have changed (see Troubleshooting below).

### ZIP (`fb-photos-<gid>-user-<uid>-<timestamp>.zip`)

```
post-001/
  photo-01.jpg
  photo-02.png
post-002/
  photo-01.jpg
manifest.json          ← same data as the JSON export
photo-failures.json    ← only present if some downloads failed
```

## Tampermonkey Grants

- `@grant GM_xmlhttpRequest` — cross-origin image fetching from Facebook's CDN.
- `@connect fbcdn.net` — permits requests to Facebook's image CDN.
- `@connect cdnjs.cloudflare.com` — permits dynamic JSZip loading.
- `@require` — pre-loads JSZip from Cloudflare CDN.

## Dry-Run / Testing

Set `DRY_RUN: true` in CONFIG, then click either button. The console logs how many posts were found and their permalinks, but no files are downloaded.

## Troubleshooting

### Posts found = 0

Open browser DevTools console and check `[FB-Export]` log messages.

- **"Not on a /groups/<gid>/user/<uid> page"** — the URL doesn't match the expected pattern. Make sure the URL has numeric IDs: `/groups/123456/user/789012/`.
- **No log output at all** — the userscript isn't running. Check Tampermonkey is enabled and the `@match` pattern covers the URL.
- **Posts visible but not found** — Facebook may have changed the feed container. Check if `document.querySelectorAll('[data-virtualized="false"]')` returns elements in DevTools. If not, inspect the feed and look for the new container attribute.

### Text is empty for posts that have visible text

Check `extraction_stats.posts_with_text` in the JSON output.

- **Styled text posts** (colored background): these use `data-ad-rendering-role="story_message"` instead of `data-ad-preview="message"`. The script handles both, but Facebook may introduce new attributes.
- **Link-share only posts**: if a post is just a shared link with no user-written text, the `text` field will contain the link title (from `data-ad-rendering-role="title"`), not full article content.
- **Fallback check**: open DevTools on a post, run `$0.querySelector('[data-ad-rendering-role="story_message"]')` after selecting the post container. If null, look for the actual text container and file an issue.

### Image URLs missing for image posts

Check `extraction_stats.posts_with_images` and `extraction_stats.total_images`.

- **Images lazy-loaded but not rendered**: scroll the post into view before exporting with "Export Loaded Now". The "Full Scan + Export" mode scrolls automatically, which triggers image loading.
- **New image container format**: if `img[data-imgperflogname="feedImage"]` no longer exists, inspect photo `<img>` elements for their current attributes and update the selector.
- **Photo gallery links changed**: if `/photo/?fbid=` anchors are gone, check how multi-photo posts render their thumbnails.

### `discovery_method` shows "role-article-fallback"

The primary `data-virtualized` selector didn't match. The script fell back to `role="article"`. This may work but is less reliable — comments could leak into post discovery. Check if Facebook changed the virtualized feed container attribute.

## Caveats

- **Facebook DOM changes frequently** — selectors may need updating if Facebook ships a new feed layout. Use `extraction_stats` in the JSON output to verify field coverage.
- **Private groups** — you must be a logged-in member. The script only reads what your browser can already see.
- **Large exports** — for groups with thousands of posts, increase `MAX_SCROLL_ATTEMPTS`. The scroll phase may take several minutes.
- **Photo CORS** — `GM_xmlhttpRequest` bypasses browser CORS, but Facebook may rate-limit image fetches.
- **Read-only** — the script never performs any write actions.

```
