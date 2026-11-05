// Cyberpunk theme: decorative overlays for the main Steam window. Makes no network requests.
(() => {
  const start = () => {
    const root = document.documentElement;
    if (!root.classList.contains('MillenniumWindow_MainSteamWindow') || document.getElementById('cp-scan')) return;

    const WORDMARK = 'CYBER<b>//</b>DECK';
    const add = (tag, id, html) => {
      const el = document.createElement(tag);
      el.id = id;
      if (html) el.innerHTML = html;
      document.body.appendChild(el);
      return el;
    };

    add('div', 'cp-scan');
    add('div', 'cp-logo', `<span>${WORDMARK}</span>`);

    // HUD: real clock and session uptime, once a second, skipped while hidden.
    const hud = add('div', 'cp-hud', '<u>&#9632;</u><span>SYS <b>ONLINE</b></span><span>T <b class="t"></b></span><span>UP <b class="u"></b></span>');
    const clock = hud.querySelector('.t'), uptime = hud.querySelector('.u');
    const began = Date.now();
    const pad = n => String(n).padStart(2, '0');
    const tickHud = () => {
      if (document.hidden) return;
      const d = new Date(), s = Math.floor((Date.now() - began) / 1000);
      clock.textContent = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
      uptime.textContent = `${pad(Math.floor(s / 3600))}:${pad(Math.floor(s / 60) % 60)}:${pad(s % 60)}`;
    };
    tickHud();
    setInterval(tickHud, 1000);

    // Signal tear: a few red and cyan bands for 0.2 s every 12 to 35 s.
    const tear = add('div', 'cp-tear');
    const bands = Array.from({ length: 3 }, () => tear.appendChild(document.createElement('i')));
    const fireTear = () => {
      if (!document.hidden && getComputedStyle(tear).display !== 'none') {
        bands.forEach((b, i) => {
          b.style.top = `${Math.random() * 92}%`;
          b.style.height = `${4 + Math.random() * 34}px`;
          b.style.background = ['rgba(255,0,60,.28)', 'rgba(0,240,255,.24)', 'rgba(252,238,10,.16)'][i];
        });
        tear.classList.remove('on');
        void tear.offsetWidth;
        tear.classList.add('on');
      }
      setTimeout(fireTear, 12000 + Math.random() * 23000);
    };
    setTimeout(fireTear, 9000);

    const vis = () => root.classList.toggle('cp-hidden', document.hidden);
    document.addEventListener('visibilitychange', vis);
    vis();

    // Boot sequence: once per client session, never blocks clicks.
    let seen = false;
    try { seen = !!sessionStorage.getItem('cp-boot'); sessionStorage.setItem('cp-boot', '1'); } catch {}
    const playBoot = () => {
      const boot = add('div', 'cp-boot', `<h1>${WORDMARK}</h1><div class="pct">0%</div><div class="bar"></div><pre></pre>`);
      const pct = boot.querySelector('.pct'), pre = boot.querySelector('pre');
      const text = '> NEURAL LINK SYNC ......... OK\n> ICE BYPASS ............... OK\n> DECK ONLINE // WELCOME, OPERATOR';
      // Based on elapsed time, so a throttled timer in an unfocused window cannot leave it unfinished.
      const t0 = Date.now();
      const run = setInterval(() => {
        const ms = Date.now() - t0;
        pct.textContent = `${Math.min(100, Math.floor(ms / 22))}%`;
        pre.textContent = text.slice(0, Math.floor(ms / 18));
        if (ms >= 2300) clearInterval(run);
      }, 30);
      setTimeout(() => boot.remove(), 2800);
    };
    if (!seen) {
      // Wait for the interface to be on screen, otherwise the sequence plays unseen. Gives up after 30 s.
      const waitFrom = Date.now();
      const wait = setInterval(() => {
        const ready = document.querySelector('.TopBar') && !document.hidden;
        if (ready) playBoot();
        if (ready || Date.now() - waitFrom > 30000) clearInterval(wait);
      }, 100);
    }
  };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);
})();
