/* LiteCord landing page behaviour.
   Three small independent pieces: scroll reveal, stat counters, and the
   request-trace demo. No framework, no build step. */

(function () {
  'use strict';

  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ── sticky nav border + scroll progress ───────────────────────── */
  var nav = document.getElementById('nav');
  var bar = document.getElementById('progress');

  function onScroll() {
    var y = window.scrollY;
    nav.classList.toggle('is-stuck', y > 8);

    if (bar) {
      var max = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.width = (max > 0 ? Math.min(y / max, 1) * 100 : 0) + '%';
    }
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll, { passive: true });
  onScroll();

  /* ── reveal on scroll ──────────────────────────────────────────── */
  var revealTargets = document.querySelectorAll(
    '.row, .mech, .spec__cell, .demo, .verify, .table, .ticks, .qa'
  );
  if (revealTargets.length) {
    if (reduced || !('IntersectionObserver' in window)) {
      for (var i = 0; i < revealTargets.length; i++) revealTargets[i].classList.add('in');
    } else {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting) {
            e.target.classList.add('in');
            io.unobserve(e.target);
          }
        });
      }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
      for (var j = 0; j < revealTargets.length; j++) {
        revealTargets[j].classList.add('reveal');
        io.observe(revealTargets[j]);
      }
    }
  }

  /* ── stat counters ─────────────────────────────────────────────── */
  var counters = document.querySelectorAll('[data-count]');
  function runCounter(el) {
    var target = parseInt(el.getAttribute('data-count'), 10) || 0;
    if (target === 0) { el.textContent = '0'; return; }
    if (reduced) { el.textContent = String(target); return; }

    var start = performance.now();
    var dur = 1100;
    (function step(now) {
      var p = Math.min((now - start) / dur, 1);
      // easeOutExpo, so the number settles rather than ticking linearly.
      var eased = p === 1 ? 1 : 1 - Math.pow(2, -10 * p);
      el.textContent = String(Math.round(target * eased));
      if (p < 1) requestAnimationFrame(step);
    })(start);
  }

  if (counters.length) {
    if (!('IntersectionObserver' in window)) {
      for (var c = 0; c < counters.length; c++) runCounter(counters[c]);
    } else {
      var cio = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting) { runCounter(e.target); cio.unobserve(e.target); }
        });
      }, { threshold: 0.5 });
      for (var k = 0; k < counters.length; k++) cio.observe(counters[k]);
    }
  }

  /* ── request-trace demo ────────────────────────────────────────── */
  var log = document.getElementById('demoLog');
  var badge = document.getElementById('demoBadge');
  if (!log || !badge) return;

  /* kind: 'ok' passes through, 'opt' passes through after being downgraded,
     'block' never reaches the network. These mirror the real rule set in
     RequestBlocker.kt. */
  var TRAFFIC = [
    { kind: 'ok',    u: 'discord.com/api/v9/users/@me',                          s: '200' },
    { kind: 'ok',    u: 'cdn.discordapp.com/avatars/6123/a91f.png?size=96',        s: '200' },
    { kind: 'block', u: 'sentry.io/api/1/envelope/?sentry_key=d38b',              s: 'DROP' },
    { kind: 'opt',   u: 'media.discordapp.net/attachments/881/42/pic.png?format=webp&quality=low', s: '200' },
    { kind: 'block', u: 'firebaseremoteconfig.googleapis.com/v1/projects/1',      s: 'DROP' },
    { kind: 'block', u: 'discord.com/api/v9/science',                            s: 'DROP' },
    { kind: 'opt',   u: 'cdn.discordapp.com/icons/9001/c44e.png?size=96',        s: '200' },
    { kind: 'block', u: 'google-analytics.com/collect?v=2&tid=G-9X2',             s: 'DROP' },
    { kind: 'ok',    u: 'discord.com/api/v9/channels/881/messages',               s: '200' },
    { kind: 'block', u: 'browser-intake-datadoghq.com/api/v2/sourcemap',          s: 'DROP' },
    { kind: 'ok',    u: 'cdn.discordapp.com/avatars/6123/b77c.png?size=96',        s: '200' },
    { kind: 'block', u: 'crashlyticsreports-pa.googleapis.com/v1/crashes',        s: 'DROP' },
    { kind: 'opt',   u: 'cdn.discordapp.com/splashes/9001/2f10.png?size=640',      s: '200' },
    { kind: 'block', u: 'fonts.gstatic.com/s/inter/v13/abc.woff2',                 s: 'DROP' },
    { kind: 'ok',    u: 'discord.com/api/v9/guilds/9001/widget.json',             s: '200' }
  ];

  var MAX_LINES = 9;
  var blocked = 0;
  var cursor = 0;

  function push(entry) {
    var li = document.createElement('li');
    li.className = entry.kind;

    var u = document.createElement('span');
    u.className = 'u';
    u.textContent = entry.u;

    var s = document.createElement('span');
    s.className = 's';
    s.textContent = entry.s;

    li.appendChild(u);
    li.appendChild(s);
    log.appendChild(li);

    while (log.children.length > MAX_LINES) log.removeChild(log.firstChild);

    if (entry.kind === 'block') {
      blocked++;
      badge.textContent = blocked + ' blocked';
    }
  }

  // A reduced-motion visitor gets the same information as a static list.
  if (reduced) {
    for (var t = 0; t < TRAFFIC.length; t++) push(TRAFFIC[t]);
  } else {
    (function tick() {
      push(TRAFFIC[cursor % TRAFFIC.length]);
      cursor++;
      window.setTimeout(tick, 620);
    })();
  }
})();
