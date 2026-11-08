// Arasaka corporate shell. Decorative only: no requests or Steam data access.
(() => {
  const mount = () => {
    const root = document.documentElement;
    if (!root.classList.contains('MillenniumWindow_MainSteamWindow') || document.getElementById('cp-logo')) return;
    const mark = '<svg viewBox="0 0 64 64" aria-hidden="true"><path d="M32 23v35M32 44 12 28m20 16 20-16"/><circle cx="32" cy="12" r="7"/><circle cx="10" cy="23" r="7"/><circle cx="54" cy="23" r="7"/></svg>';
    const add = (id, html) => {
      const el = document.createElement('div'); el.id = id;
      el.setAttribute('aria-hidden', 'true'); el.innerHTML = html;
      document.body.appendChild(el); return el;
    };
    add('cp-logo', `${mark}<span>ARASAKA<small>CORPORATE SYSTEMS</small></span>`);
    const hud = add('cp-hud', '<i></i><span>NETWORK <b>CONNECTED</b></span><span>LOCAL <b class="t"></b></span><span>SESSION <b class="u"></b></span>');
    const clock = hud.querySelector('.t'), uptime = hud.querySelector('.u');
    const began = Date.now(), pad = n => String(n).padStart(2, '0');
    const tick = () => {
      if (document.hidden) return;
      const d = new Date(), seconds = Math.floor((Date.now() - began) / 1000);
      clock.textContent = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
      uptime.textContent = `${pad(Math.floor(seconds / 3600))}:${pad(Math.floor(seconds / 60) % 60)}`;
    };
    tick(); const timer = setInterval(tick, 1000);
    const visibility = () => root.classList.toggle('cp-hidden', document.hidden);
    document.addEventListener('visibilitychange', visibility); visibility();
    let seen = false;
    try { seen = !!sessionStorage.getItem('arasaka-boot'); sessionStorage.setItem('arasaka-boot', '1'); } catch {}
    let wait, removal;
    if (!seen && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
      const from = Date.now();
      wait = setInterval(() => {
        if (!document.hidden && document.querySelector('.TopBar')) {
          clearInterval(wait);
          const boot = add('cp-boot', `<div class="as-boot-brand">${mark}<span>ARASAKA<small>CORPORATE SYSTEMS DIVISION</small></span></div><div class="as-boot-rule"></div><p>PERSONNEL TERMINAL <span>01 / ONLINE</span></p><h2>Welcome to the network.</h2><div class="bar"></div><pre>LOCAL CLIENT INITIALIZED\nCORPORATE INTERFACE READY</pre><footer>ARASAKA CORPORATION<span>SECURE. CONTROLLED. CONNECTED.</span></footer>`);
          removal = setTimeout(() => boot.remove(), 1900);
        } else if (Date.now() - from > 30000) clearInterval(wait);
      }, 100);
    }
    // Keep no repeating animation/timer running after this document is discarded.
    window.addEventListener('pagehide', () => {
      clearInterval(timer); clearInterval(wait); clearTimeout(removal);
      document.removeEventListener('visibilitychange', visibility);
    }, { once: true });
  };
  if (document.body) mount(); else document.addEventListener('DOMContentLoaded', mount, { once: true });
})();
