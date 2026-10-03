// gramX website. No tracking, no cookies; the only request it makes on its
// own is to GitHub, to find the latest release.
(function () {
  'use strict';

  var root = document.documentElement;
  var platform = root.getAttribute('data-platform') || 'desktop';
  var $ = function (sel, ctx) { return (ctx || document).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); };

  function store(kind, key, value) {
    try {
      var s = window[kind];
      if (value === undefined) return s.getItem(key);
      s.setItem(key, value);
    } catch (e) {}
    return null;
  }

  // The address to hand to other people: this page when it is served, the
  // canonical address when it is opened from disk.
  function pageUrl(hash) {
    var base = /^https?:$/.test(location.protocol)
      ? location.origin + location.pathname.replace(/index\.html$/, '')
      : ($('link[rel="canonical"]') || {}).href || '';
    return base + (hash || '');
  }

  // ── Theme ──────────────────────────────────────────────────────────────

  var THEMES = ['light', 'dim', 'dark'];
  var THEME_NAMES = { light: 'Light', dim: 'Dim', dark: 'Lights out' };
  var THEME_BG = { light: '#f9f9f9', dim: '#15202b', dark: '#000000' };

  function applyTheme(theme, remember) {
    root.setAttribute('data-theme', theme);
    if (remember) store('localStorage', 'gramx-theme', theme);
    var meta = $('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', THEME_BG[theme]);
    $$('[data-theme-pick]').forEach(function (tile) {
      tile.setAttribute('aria-checked', String(tile.getAttribute('data-theme-pick') === theme));
    });
    var next = THEMES[(THEMES.indexOf(theme) + 1) % THEMES.length];
    $$('[data-theme-cycle]').forEach(function (btn) {
      btn.setAttribute('aria-label', 'Theme: ' + THEME_NAMES[theme] + '. Switch to ' + THEME_NAMES[next]);
    });
  }

  applyTheme(root.getAttribute('data-theme') || 'dark', false);

  $$('[data-theme-cycle]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var i = THEMES.indexOf(root.getAttribute('data-theme'));
      applyTheme(THEMES[(i + 1) % THEMES.length], true);
    });
  });
  $$('[data-theme-pick]').forEach(function (tile) {
    tile.addEventListener('click', function () {
      applyTheme(tile.getAttribute('data-theme-pick'), true);
    });
  });
  if (window.matchMedia) {
    var light = matchMedia('(prefers-color-scheme: light)');
    var follow = function (e) {
      if (!store('localStorage', 'gramx-theme')) applyTheme(e.matches ? 'light' : 'dark', false);
    };
    if (light.addEventListener) light.addEventListener('change', follow);
    else if (light.addListener) light.addListener(follow);
  }

  // ── Header ─────────────────────────────────────────────────────────────

  var nav = $('[data-nav]');
  if (nav) {
    var onScroll = function () { nav.classList.toggle('scrolled', window.scrollY > 8); };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  $$('[data-year]').forEach(function (el) { el.textContent = String(new Date().getFullYear()); });

  // ── Release ────────────────────────────────────────────────────────────
  // The latest release is looked up from GitHub, so a new version needs no
  // edit here. GitHub allows 60 lookups an hour per address, and visitors who
  // share one (a mobile carrier, an office) can run out; they get the release
  // below, so bump FALLBACK_VERSION when publishing.

  var REPO = 'daveragos/gramx';
  var FALLBACK_VERSION = '1.0.0';

  function fallbackFile(abi, size) {
    var name = 'gramx-' + FALLBACK_VERSION + '-' + abi + '.apk';
    return { name: name, url: DL + name, size: size };
  }
  var DL = 'https://github.com/' + REPO + '/releases/download/v' + FALLBACK_VERSION + '/';
  var release = {
    version: FALLBACK_VERSION,
    url: 'https://github.com/' + REPO + '/releases/tag/v' + FALLBACK_VERSION,
    files: {
      arm64: fallbackFile('arm64-v8a', 52565955),
      v7a: fallbackFile('armeabi-v7a', 44441437),
      x86: fallbackFile('x86_64', 56178584),
      sums: { name: 'SHA256SUMS.txt', url: DL + 'SHA256SUMS.txt', size: 0 }
    }
  };
  var PATTERNS = {
    arm64: /arm64-v8a\.apk$/i,
    v7a: /armeabi-v7a\.apk$/i,
    x86: /x86_64\.apk$/i,
    sums: /sha256sums/i
  };

  function megabytes(bytes) { return Math.round(bytes / 1e6) + ' MB'; }

  function applyRelease() {
    $$('[data-dl]').forEach(function (a) {
      var f = release.files[a.getAttribute('data-dl')];
      if (f) a.href = f.url;
    });
    $$('[data-size]').forEach(function (el) {
      var f = release.files[el.getAttribute('data-size')];
      if (f && f.size) el.textContent = megabytes(f.size);
    });
    $$('[data-filename]').forEach(function (el) {
      var f = release.files[el.getAttribute('data-filename')];
      if (f) el.textContent = f.name;
    });
    $$('[data-version]').forEach(function (el) { el.textContent = release.version; });
    $$('[data-release-link]').forEach(function (a) { a.href = release.url; });
  }

  function readRelease(data) {
    if (!data || !data.tag_name || !data.assets) return null;
    var files = {};
    data.assets.forEach(function (asset) {
      Object.keys(PATTERNS).forEach(function (key) {
        if (!files[key] && PATTERNS[key].test(asset.name)) {
          files[key] = { name: asset.name, url: asset.browser_download_url, size: asset.size };
        }
      });
    });
    if (!files.arm64) return null;
    return { version: data.tag_name.replace(/^v/, ''), url: data.html_url, files: files };
  }

  function useRelease(found) {
    if (!found) return;
    Object.keys(release.files).forEach(function (key) {
      if (!found.files[key]) found.files[key] = release.files[key];
    });
    release = found;
    applyRelease();
  }

  applyRelease();

  (function lookUpRelease() {
    var cached = null;
    try { cached = JSON.parse(store('sessionStorage', 'gramx-release') || 'null'); } catch (e) {}
    if (cached && Date.now() - cached.at < 10 * 60 * 1000) {
      useRelease(cached.release);
      return;
    }
    if (!window.fetch) return;
    var ctrl = window.AbortController ? new AbortController() : null;
    var timer = setTimeout(function () { if (ctrl) ctrl.abort(); }, 6000);
    fetch('https://api.github.com/repos/' + REPO + '/releases/latest', {
      headers: { Accept: 'application/vnd.github+json' },
      signal: ctrl ? ctrl.signal : undefined
    })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (data) {
        var found = readRelease(data);
        if (found) {
          store('sessionStorage', 'gramx-release', JSON.stringify({ at: Date.now(), release: found }));
          useRelease(found);
        }
      })
      .catch(function () {})
      .then(function () { clearTimeout(timer); });
  })();

  // ── QR codes ───────────────────────────────────────────────────────────

  var qrLoading = null;
  function loadQr() {
    if (window.qrcode) return Promise.resolve();
    if (!qrLoading) {
      qrLoading = new Promise(function (resolve, reject) {
        var s = document.createElement('script');
        s.src = 'vendor/qrcode.js';
        s.onload = resolve;
        s.onerror = reject;
        document.head.appendChild(s);
      });
    }
    return qrLoading;
  }

  function drawQrCodes() {
    var url = pageUrl('#install');
    if (!url) return;
    loadQr().then(function () {
      $$('[data-qr]').forEach(function (el) {
        if (el.firstChild) return;
        var q = window.qrcode(0, 'M');
        q.addData(url);
        q.make();
        el.innerHTML = q.createSvgTag({ cellSize: 4, margin: 0, scalable: true });
      });
    }).catch(function () {});
  }

  if (platform === 'desktop' && $('[data-qr]')) drawQrCodes();

  // ── Download sheet ─────────────────────────────────────────────────────

  var sheet = $('#download-sheet');

  function openSheet(key) {
    if (!sheet || typeof sheet.showModal !== 'function') return;
    var f = release.files[key] || release.files.arm64;
    sheet.setAttribute('data-mode', platform);
    $('[data-sheet-title]', sheet).textContent = platform === 'ios'
      ? 'gramX is for Android'
      : platform === 'desktop'
        ? 'Downloading to this computer'
        : 'Your download has started';
    $('[data-sheet-file]', sheet).textContent = f.name;
    $('[data-sheet-size]', sheet).textContent = megabytes(f.size);
    $('[data-sheet-again]', sheet).href = f.url;
    if (platform === 'desktop') drawQrCodes();
    if (!sheet.open) sheet.showModal();
  }

  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a[data-download]');
    if (!a) return;
    var key = a.getAttribute('data-dl');
    // An APK is no use on an iPhone, so explain instead of downloading.
    if (platform === 'ios') {
      e.preventDefault();
      openSheet(key);
      return;
    }
    // Let the download start before the sheet takes focus.
    setTimeout(function () { openSheet(key); }, 250);
  });

  if (sheet) {
    $$('[data-close]', sheet).forEach(function (btn) {
      btn.addEventListener('click', function () { sheet.close(); });
    });
    sheet.addEventListener('click', function (e) {
      if (e.target !== sheet) return;
      var r = sheet.getBoundingClientRect();
      var inside = e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom;
      if (!inside) sheet.close();
    });
  }

  // ── Sharing ────────────────────────────────────────────────────────────

  var SHARE_TEXT = 'gramX turns the Telegram channels you follow into one timeline. Free for Android:';

  $$('[data-share-x]').forEach(function (a) {
    a.href = 'https://x.com/intent/post?text=' + encodeURIComponent(SHARE_TEXT) +
      '&url=' + encodeURIComponent(pageUrl());
  });

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      var t = document.createElement('textarea');
      t.value = text;
      t.setAttribute('readonly', '');
      t.style.position = 'fixed';
      t.style.opacity = '0';
      document.body.appendChild(t);
      t.select();
      try { document.execCommand('copy') ? resolve() : reject(); } catch (err) { reject(err); }
      document.body.removeChild(t);
    });
  }

  $$('[data-copy-link]').forEach(function (btn) {
    var label = $('span', btn);
    btn.addEventListener('click', function () {
      copyText(pageUrl()).then(function () {
        label.textContent = 'Link copied';
        setTimeout(function () { label.textContent = 'Copy link'; }, 2000);
      }, function () {
        window.prompt('Copy this link:', pageUrl());
      });
    });
  });

  // ── The phone preview ──────────────────────────────────────────────────

  var app = $('[data-app]');
  if (app) {
    var feed = $('[data-feed]', app);

    function compact(n) {
      if (n < 1000) return String(n);
      if (n < 10000) return (Math.floor(n / 100) / 10).toString().replace(/\.0$/, '') + 'K';
      if (n < 1e6) return Math.floor(n / 1000) + 'K';
      return (Math.floor(n / 1e5) / 10).toString().replace(/\.0$/, '') + 'M';
    }

    // Folder tabs filter the feed, as in the app.
    var tabs = $$('[data-tab]', app);
    function showFolder(folder) {
      tabs.forEach(function (t) {
        t.setAttribute('aria-selected', String(t.getAttribute('data-tab') === folder));
      });
      $$('.post', feed).forEach(function (post) {
        post.hidden = folder !== 'all' && post.getAttribute('data-folder') !== folder;
      });
      feed.scrollTop = 0;
    }
    tabs.forEach(function (t) {
      t.addEventListener('click', function () { showFolder(t.getAttribute('data-tab')); });
    });

    // Tapping the heart reacts.
    feed.addEventListener('click', function (e) {
      var btn = e.target.closest && e.target.closest('.like');
      if (!btn) return;
      var on = btn.getAttribute('aria-pressed') !== 'true';
      var n = Number(btn.getAttribute('data-count')) + (on ? 1 : -1);
      btn.setAttribute('aria-pressed', String(on));
      btn.setAttribute('data-count', String(n));
      $('span', btn).textContent = compact(n);
    });

    // A new post arrives a few seconds in.
    var pill = $('[data-new-pill]', app);
    var incoming = $('template[data-incoming]', feed);
    var arrived = false;
    function deliver() {
      if (arrived || !incoming) return;
      arrived = true;
      pill.classList.remove('show');
      var post = incoming.content.firstElementChild.cloneNode(true);
      post.classList.add('enter');
      var selected = $('[data-tab][aria-selected="true"]', app);
      var folder = selected ? selected.getAttribute('data-tab') : 'all';
      post.hidden = folder !== 'all' && post.getAttribute('data-folder') !== folder;
      feed.insertBefore(post, $('.post', feed));
      feed.scrollTop = 0;
    }
    if (pill) {
      pill.addEventListener('click', deliver);
      var started = false;
      var start = function () {
        if (started) return;
        started = true;
        setTimeout(function () {
          if (arrived) return;
          pill.classList.add('show');
          setTimeout(deliver, 3500);
        }, 2500);
      };
      if ('IntersectionObserver' in window) {
        var seen = new IntersectionObserver(function (entries) {
          if (entries[0].isIntersecting) { start(); seen.disconnect(); }
        }, { threshold: 0.4 });
        seen.observe(app);
      } else {
        start();
      }
    }
  }

  // ── Reveal on scroll ───────────────────────────────────────────────────

  var reveals = $$('.reveal');
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('in');
        io.unobserve(entry.target);
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    reveals.forEach(function (el) {
      var siblings = Array.prototype.indexOf.call(el.parentNode.children, el);
      el.style.transitionDelay = (siblings % 3) * 70 + 'ms';
      io.observe(el);
    });
  } else {
    reveals.forEach(function (el) { el.classList.add('in'); });
  }
})();
