// Enhance the compact menu; all navigation links remain visible without JavaScript.
(() => {
  const navbar = document.querySelector('.mupt-navbar');
  if (!navbar) return;

  const toggle = navbar.querySelector('.mupt-nav-toggle');
  const menu = navbar.querySelector('.mupt-nav-menu');
  const compact = window.matchMedia('(max-width: 767px)');

  function setOpen(open) {
    toggle.setAttribute('aria-expanded', String(open));
    menu.classList.toggle('is-open', open);
  }

  toggle.hidden = false;
  navbar.classList.add('is-enhanced');
  toggle.addEventListener('click', () => {
    setOpen(toggle.getAttribute('aria-expanded') !== 'true');
  });

  navbar.addEventListener('keydown', event => {
    if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
      setOpen(false);
      toggle.focus();
    }
  });

  document.addEventListener('click', event => {
    if (!navbar.contains(event.target)) setOpen(false);
  });

  menu.addEventListener('click', event => {
    if (event.target.closest('a')) setOpen(false);
  });

  compact.addEventListener('change', () => {
    if (compact.matches && menu.contains(document.activeElement)) toggle.focus();
    if (!compact.matches && document.activeElement === toggle) {
      menu.querySelector('a').focus();
    }
    setOpen(false);
  });
})();
