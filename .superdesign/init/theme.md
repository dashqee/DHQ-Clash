# Theme and design tokens

## Compact token summary

- Visual mode: dark-only product UI.
- Background: `#08091f`; surfaces: `#10112d`, `#151735`, hover `#1b1e42`.
- Text: `#f7f8ff`; muted: `#aeb5d3`.
- Brand accents: violet `#7437f5`, blue `#4877f4`, cyan `#42e5e8`, lime `#c7ff3d`; danger `#ff8d9b`.
- Main gradient: violet → blue → cyan at 125 degrees.
- Typeface: native UI stack, Segoe UI/Roboto/Inter fallback. Tight headings, uppercase 10–12px eyebrows.
- Radius: 12–14px controls, 19–24px cards, 28px modal/login surfaces.
- Shadows: broad low-opacity black surface shadow; blue brand glow on primary actions.
- Layout: mobile-first; sticky top header + bottom navigation; desktop switches to 220px sidebar and max-width content.
- Focus: 2px lime outline.
- Motion: subtle 180–200ms translate/scale feedback; bottom sheets animate upward.
- Breakpoints are declared in the CSS media queries below.

## Package/runtime

```json
{
  "name": "dhqclash-webapp",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "description": "Telegram Mini App (user dashboard) for the dhqclash VPN bot.",
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@telegram-apps/telegram-ui": "^2.1.8",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/react": "^18.3.12",
    "@types/react-dom": "^18.3.1",
    "@vitejs/plugin-react": "^4.3.4",
    "typescript": "^5.6.3",
    "vite": "^5.4.11"
  }
}
```

## Vite config

```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Served at the Mini App domain root (dhqclash.com) → base "/". The build stays
// origin-agnostic, so the legacy sslip.io domain serves the same bundle.
// `dev` proxies /api to the local FastAPI (miniapp.py) so `npm run dev` works end-to-end.
export default defineConfig({
  plugins: [react()],
  base: "/",
  build: { outDir: "dist", sourcemap: false },
  server: {
    proxy: {
      "/api": { target: "http://127.0.0.1:8090", changeOrigin: true },
      "/auth": { target: "http://127.0.0.1:8090", changeOrigin: true },
    },
  },
});
```

## Complete global stylesheet

```css
:root {
  color-scheme: dark;
  --dhq-bg: #08091f;
  --dhq-surface: #10112d;
  --dhq-surface-2: #151735;
  --dhq-surface-hover: #1b1e42;
  --dhq-text: #f7f8ff;
  --dhq-muted: #aeb5d3;
  --dhq-violet: #7437f5;
  --dhq-blue: #4877f4;
  --dhq-cyan: #42e5e8;
  --dhq-lime: #c7ff3d;
  --dhq-danger: #ff8d9b;
  --dhq-line: rgba(116, 104, 245, 0.22);
  --dhq-line-strong: rgba(66, 229, 232, 0.42);
  --dhq-gradient: linear-gradient(125deg, var(--dhq-violet), var(--dhq-blue) 54%, var(--dhq-cyan));
  --tgui--bg_color: var(--dhq-bg);
  --tgui--secondary_bg_color: var(--dhq-bg);
  --tgui--section_bg_color: var(--dhq-surface);
  --tgui--text_color: var(--dhq-text);
  --tgui--hint_color: var(--dhq-muted);
  --tgui--subtitle_text_color: var(--dhq-muted);
  --tgui--section_header_text_color: var(--dhq-muted);
  --tgui--link_color: var(--dhq-cyan);
  --tgui--button_color: var(--dhq-blue);
  --tgui--button_text_color: #fff;
  --tgui--destructive_text_color: var(--dhq-danger);
  --tgui--outline: var(--dhq-line);
}

* { box-sizing: border-box; }

html,
body,
#root {
  min-height: 100%;
  margin: 0;
  background: var(--dhq-bg);
}

body {
  min-height: 100vh;
  color: var(--dhq-text);
  background:
    radial-gradient(900px 540px at 8% -10%, rgba(116, 55, 245, 0.22), transparent 66%),
    radial-gradient(820px 520px at 96% 15%, rgba(66, 229, 232, 0.12), transparent 68%),
    var(--dhq-bg);
  font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Inter, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
}

button,
input { font: inherit; }

button:focus-visible,
a:focus-visible,
input:focus-visible {
  outline: 2px solid var(--dhq-lime);
  outline-offset: 2px;
}

button { -webkit-tap-highlight-color: transparent; }

.brand-name {
  color: var(--dhq-text);
  font-size: 19px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.brand-name span,
.web-login__brand span { color: var(--dhq-cyan); }

/* Authentication and loading states */
.gate,
.web-login {
  min-height: 100vh;
  padding: max(24px, env(safe-area-inset-top)) 24px max(24px, env(safe-area-inset-bottom));
  background:
    linear-gradient(rgba(255, 255, 255, 0.018) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.018) 1px, transparent 1px),
    radial-gradient(circle at 10% 0%, rgba(116, 55, 245, 0.22), transparent 42%),
    radial-gradient(circle at 90% 15%, rgba(66, 229, 232, 0.14), transparent 42%),
    var(--dhq-bg);
  background-size: 52px 52px, 52px 52px, auto, auto, auto;
}

.gate {
  display: grid;
  place-items: center;
}

.gate__card {
  display: grid;
  width: min(100%, 460px);
  justify-items: center;
  padding: 34px 28px;
  border: 1px solid var(--dhq-line);
  border-radius: 24px;
  background: rgba(16, 17, 45, 0.94);
  box-shadow: 0 28px 90px rgba(0, 0, 0, 0.35);
  text-align: center;
}

.gate__mark { width: 78px; height: 78px; margin-bottom: 16px; }
.gate__card h1 { margin: 20px 0 8px; font-size: 24px; }
.gate__card > p { max-width: 360px; margin: 0 0 24px; color: var(--dhq-muted); }
.gate__actions { display: grid; width: 100%; gap: 10px; }

.web-login {
  display: grid;
  align-items: center;
  gap: clamp(38px, 8vw, 100px);
}

.web-login__intro { display: none; }

.web-login__brand {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 44px;
  font-size: 22px;
  font-weight: 800;
}

.web-login__brand-mark { width: 52px; height: 52px; }
.web-login__eyebrow { color: var(--dhq-cyan); font-size: 12px; font-weight: 800; letter-spacing: 0.14em; text-transform: uppercase; }

.web-login__intro h1 {
  max-width: 640px;
  margin: 12px 0 22px;
  font-size: clamp(42px, 5.4vw, 72px);
  line-height: 1.02;
  letter-spacing: -0.055em;
}

.web-login__intro h1 span {
  color: transparent;
  background: var(--dhq-gradient);
  background-clip: text;
  -webkit-background-clip: text;
}

.web-login__lead { max-width: 620px; color: var(--dhq-muted); font-size: 18px; }
.web-login__benefits { display: grid; gap: 16px; margin: 34px 0 0; padding: 0; list-style: none; color: var(--dhq-muted); }
.web-login__benefits li { display: flex; align-items: center; gap: 14px; }
.web-login__benefits span { color: var(--dhq-lime); font-size: 11px; font-weight: 800; letter-spacing: 0.08em; }

.web-login__card {
  width: min(100%, 460px);
  justify-self: center;
  padding: 32px 26px;
  border: 1px solid var(--dhq-line);
  border-radius: 28px;
  background: rgba(16, 17, 45, 0.96);
  box-shadow: 0 30px 100px rgba(0, 0, 0, 0.38);
  text-align: center;
}

.web-login__card-mark { width: 76px; height: 76px; margin-bottom: 16px; }
.web-login__card h2 { margin: 7px 0 10px; font-size: 27px; letter-spacing: -0.03em; }
.web-login__description { margin: 0 auto 26px; color: var(--dhq-muted); line-height: 1.55; }
.web-login__widget-wrap { display: grid; min-height: 52px; place-items: center; }
.web-login__widget { display: grid; min-height: 44px; place-items: center; }
.web-login__error { margin: 14px 0; color: var(--dhq-danger); }
.web-login__note { margin: 22px auto 0; max-width: 360px; color: var(--dhq-muted); font-size: 12px; line-height: 1.55; }

/* Application shell */
.app-shell {
  min-height: 100vh;
  color: var(--dhq-text);
  background:
    radial-gradient(700px 430px at 12% 0%, rgba(116, 55, 245, 0.13), transparent 65%),
    var(--dhq-bg);
}

.app-header {
  position: sticky;
  z-index: 30;
  top: 0;
  display: flex;
  min-height: 68px;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  padding: max(10px, env(safe-area-inset-top)) 16px 10px;
  border-bottom: 1px solid var(--dhq-line);
  background: rgba(8, 9, 31, 0.86);
  backdrop-filter: blur(18px);
}

.app-header__brand,
.app-header__account { display: flex; align-items: center; }
.app-header__brand { gap: 11px; }
.app-header__mark { width: 39px; height: 39px; flex: 0 0 auto; }
.app-header__brand div { display: grid; }
.app-header__brand strong { font-size: 15px; letter-spacing: -0.02em; }
.app-header__brand span { color: var(--dhq-muted); font-size: 11px; }
.app-header__account { min-width: 0; gap: 9px; }
.app-header__account > img,
.account-avatar { width: 32px; height: 32px; border-radius: 11px; }
.app-header__account > img { object-fit: cover; }
.account-avatar { display: grid; place-items: center; color: var(--dhq-cyan); background: var(--dhq-surface-2); font-size: 13px; font-weight: 800; }
.account-name { display: none; overflow: hidden; max-width: 130px; color: var(--dhq-muted); font-size: 13px; text-overflow: ellipsis; white-space: nowrap; }

.logout-button {
  display: flex;
  min-width: 40px;
  min-height: 40px;
  align-items: center;
  justify-content: center;
  gap: 7px;
  border: 0;
  border-radius: 12px;
  color: var(--dhq-muted);
  background: transparent;
  cursor: pointer;
}

.logout-button:hover { color: var(--dhq-text); background: var(--dhq-surface-2); }
.logout-button span { display: none; }
.app-layout { width: 100%; }
.app-sidebar { display: none; }

.app-main {
  min-width: 0;
  padding: 20px 16px calc(96px + env(safe-area-inset-bottom));
}

.page-heading { margin: 0 0 18px; }
.page-heading p { margin: 0 0 2px; color: var(--dhq-cyan); font-size: 10px; font-weight: 800; letter-spacing: 0.13em; text-transform: uppercase; }
.page-heading h1 { margin: 0; font-size: 25px; letter-spacing: -0.04em; }
.app-content { min-width: 0; }

.side-nav,
.bottom-nav { gap: 6px; }
.side-nav { display: grid; }

.bottom-nav {
  position: fixed;
  z-index: 40;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;
  align-items: stretch;
  justify-content: space-around;
  padding: 6px 6px max(7px, env(safe-area-inset-bottom));
  border-top: 1px solid var(--dhq-line);
  background: rgba(16, 17, 45, 0.96);
  backdrop-filter: blur(18px);
}

.nav-item {
  display: flex;
  min-width: 0;
  min-height: 54px;
  align-items: center;
  justify-content: center;
  gap: 7px;
  border: 0;
  border-radius: 14px;
  color: rgba(247, 248, 255, 0.54);
  background: transparent;
  cursor: pointer;
  transition: color 0.18s ease, background 0.18s ease, transform 0.18s ease;
}

.bottom-nav .nav-item { flex: 1; flex-direction: column; gap: 3px; padding: 4px 2px; font-size: 10px; font-weight: 700; }
.nav-item:hover { color: var(--dhq-text); background: rgba(116, 55, 245, 0.1); }
.nav-item--active { color: var(--dhq-cyan); background: linear-gradient(125deg, rgba(116, 55, 245, 0.18), rgba(66, 229, 232, 0.1)); }
.side-nav .nav-item { justify-content: flex-start; padding: 0 14px; font-size: 14px; font-weight: 650; }

/* Branded dashboard */
.devices-view { display: grid; gap: 22px; }
.devices-summary {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 20px;
  overflow: hidden;
  border: 1px solid var(--dhq-line);
  border-radius: 22px;
  background:
    radial-gradient(circle at 100% 0%, rgba(66, 229, 232, 0.14), transparent 48%),
    linear-gradient(135deg, rgba(116, 55, 245, 0.14), transparent 60%),
    var(--dhq-surface);
}

.devices-summary p { margin: 0 0 4px; color: var(--dhq-muted); font-size: 12px; }
.devices-summary h2 { margin: 0; font-size: 23px; letter-spacing: -0.035em; }
.devices-summary__status { display: flex; align-items: center; gap: 7px; color: var(--dhq-muted); font-size: 12px; font-weight: 700; }
.devices-summary__status i,
.status-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--dhq-lime); box-shadow: 0 0 8px rgba(199, 255, 61, 0.5); }
.section-heading { display: flex; align-items: center; gap: 9px; padding: 0 2px; }
.section-heading h2 { margin: 0; font-size: 13px; letter-spacing: 0.08em; text-transform: uppercase; }
.section-heading > span { display: grid; min-width: 22px; height: 22px; place-items: center; border-radius: 8px; color: var(--dhq-cyan); background: rgba(66, 229, 232, 0.1); font-size: 11px; font-weight: 800; }
.device-list { display: grid; gap: 13px; }

.device-card {
  padding: 17px;
  border: 1px solid var(--dhq-line);
  border-radius: 21px;
  background: var(--dhq-surface);
  box-shadow: 0 14px 40px rgba(0, 0, 0, 0.12);
}

.device-card__header { display: flex; align-items: flex-start; gap: 12px; }
.device-icon { display: grid; width: 42px; height: 42px; flex: 0 0 auto; place-items: center; border-radius: 14px; color: var(--dhq-cyan); background: var(--dhq-surface-2); }
.device-icon--router { color: var(--dhq-violet); }
.device-card__identity { min-width: 0; flex: 1; }
.device-card__identity h3 { overflow: hidden; margin: 1px 0 2px; font-size: 15px; letter-spacing: -0.02em; text-overflow: ellipsis; white-space: nowrap; }
.device-card__identity p { margin: 0; color: var(--dhq-muted); font-size: 12px; }

.icon-action {
  display: grid;
  width: 40px;
  height: 40px;
  flex: 0 0 auto;
  place-items: center;
  border: 0;
  border-radius: 12px;
  color: var(--dhq-muted);
  background: transparent;
  cursor: pointer;
}

.icon-action:hover { color: var(--dhq-text); background: var(--dhq-surface-2); }
.device-card__footer { display: flex; align-items: flex-end; justify-content: space-between; gap: 14px; margin-top: 15px; padding-top: 14px; border-top: 1px solid rgba(116, 104, 245, 0.11); }
.device-expiry { display: grid; gap: 3px; }
.device-expiry span { color: rgba(174, 181, 211, 0.55); font-size: 10px; font-weight: 800; letter-spacing: 0.1em; text-transform: uppercase; }
.device-expiry strong { font-size: 13px; }

.primary-action,
.secondary-action,
.copy-config-action,
.text-action {
  min-height: 42px;
  border-radius: 13px;
  font-weight: 750;
  cursor: pointer;
}

.primary-action {
  min-width: 120px;
  padding: 0 21px;
  border: 0;
  color: #fff;
  background: var(--dhq-gradient);
  box-shadow: 0 10px 24px rgba(72, 119, 244, 0.2);
}

.primary-action:hover { transform: translateY(-1px); }
.primary-action:active { transform: scale(0.98); }
.primary-action:disabled,
.secondary-action:disabled { cursor: wait; opacity: 0.65; }
.secondary-action { display: flex; align-items: center; justify-content: center; gap: 7px; padding: 0 13px; border: 1px solid var(--dhq-line); color: var(--dhq-text); background: var(--dhq-surface-2); }
.text-action { padding: 0 16px; border: 0; color: var(--dhq-muted); background: transparent; }
.router-action { display: grid; justify-items: end; gap: 5px; }
.router-action > p { max-width: 220px; margin: 0; color: rgba(174, 181, 211, 0.62); font-size: 10px; text-align: right; }
.inline-error { color: var(--dhq-danger) !important; }

.rename-form { display: grid; gap: 10px; margin-top: 15px; padding-top: 14px; border-top: 1px solid rgba(116, 104, 245, 0.11); }
.rename-form label { display: grid; gap: 6px; }
.rename-form label > span { color: var(--dhq-muted); font-size: 11px; }
.rename-form input { width: 100%; min-height: 44px; padding: 0 13px; border: 1px solid var(--dhq-line); border-radius: 13px; color: var(--dhq-text); background: var(--dhq-surface-2); }
.rename-form > div { display: flex; justify-content: flex-end; gap: 7px; }

.state-card {
  display: grid;
  min-height: 260px;
  place-items: center;
  align-content: center;
  padding: 28px;
  border: 1px solid var(--dhq-line);
  border-radius: 22px;
  background: var(--dhq-surface);
  text-align: center;
}

.state-card__mark { width: 68px; height: 68px; margin-bottom: 10px; }
.state-card h2 { margin: 8px 0; font-size: 20px; }
.state-card p { max-width: 420px; margin: 0; color: var(--dhq-muted); }
.state-card--error { border-color: rgba(255, 141, 155, 0.26); }

/* Install platform bottom sheet / desktop dialog */
.install-modal { position: fixed; z-index: 100; inset: 0; display: flex; align-items: flex-end; justify-content: center; }
.install-modal__backdrop { position: absolute; inset: 0; width: 100%; border: 0; background: rgba(8, 9, 31, 0.82); backdrop-filter: blur(7px); cursor: default; }
.install-sheet {
  position: relative;
  width: 100%;
  max-height: min(90vh, 760px);
  overflow-y: auto;
  padding: 25px 22px max(30px, env(safe-area-inset-bottom));
  border: 1px solid rgba(116, 104, 245, 0.32);
  border-bottom: 0;
  border-radius: 28px 28px 0 0;
  background: var(--dhq-surface);
  box-shadow: 0 -28px 70px rgba(0, 0, 0, 0.48);
  text-align: center;
  animation: sheet-in 0.2s ease-out both;
}

.install-sheet__handle { width: 48px; height: 4px; margin: 0 auto 22px; border-radius: 99px; background: var(--dhq-surface-hover); }
.install-sheet__close { position: absolute; top: 18px; right: 17px; display: grid; width: 40px; height: 40px; place-items: center; border: 0; border-radius: 12px; color: var(--dhq-muted); background: var(--dhq-surface-2); cursor: pointer; }
.install-sheet__mark { width: 64px; height: 64px; }
.install-sheet h2 { margin: 12px 0 4px; font-size: 21px; letter-spacing: -0.03em; }
.install-sheet > p { margin: 0 auto; color: var(--dhq-muted); font-size: 13px; }
.install-sheet__loading { display: grid; min-height: 210px; place-items: center; }
.install-sheet__error { margin: 22px 0; }
.platform-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; margin: 25px 0 15px; }
.platform-card { display: flex; min-height: 106px; flex-direction: column; align-items: center; justify-content: center; gap: 8px; border: 1px solid rgba(116, 104, 245, 0.16); border-radius: 19px; color: var(--dhq-text); background: var(--dhq-surface-2); cursor: pointer; transition: background 0.18s ease, border-color 0.18s ease, transform 0.18s ease; }
.platform-card:hover { border-color: var(--dhq-line-strong); background: var(--dhq-surface-hover); transform: translateY(-1px); }
.platform-card span { font-size: 13px; font-weight: 800; }
.platform-card--android { color: var(--dhq-lime); }
.platform-card--windows { color: var(--dhq-blue); }
.platform-card--macos { color: var(--dhq-cyan); }
.copy-config-action { display: flex; width: 100%; align-items: center; justify-content: center; gap: 8px; padding: 0 15px; border: 1px solid var(--dhq-line); color: var(--dhq-text); background: var(--dhq-surface-hover); }
.install-sheet .install-sheet__footnote { margin-top: 14px; font-size: 11px; }

/* Branded content system shared by payments, guides, support, and referrals. */
.content-screen,
.content-stack,
.content-grid { display: grid; gap: 16px; }

.content-card {
  position: relative;
  min-width: 0;
  padding: 20px;
  overflow: hidden;
  border: 1px solid var(--dhq-line);
  border-radius: 22px;
  background: var(--dhq-surface);
  box-shadow: 0 14px 40px rgba(0, 0, 0, 0.12);
}

.content-card__header { display: flex; align-items: center; gap: 12px; margin-bottom: 17px; }
.content-card__header > div,
.content-card__title { min-width: 0; }
.content-card__header p,
.content-card__title p,
.offer-card__header p,
.trial-card > div > p,
.compact-card__copy p {
  margin: 0 0 2px;
  color: rgba(174, 181, 211, 0.58);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.11em;
  text-transform: uppercase;
}

.content-card__header h2,
.content-card__title h2,
.offer-card__header h2,
.trial-card h2,
.support-card h2 {
  margin: 0;
  font-size: 17px;
  line-height: 1.25;
  letter-spacing: -0.025em;
}

.content-card__title { margin-bottom: 16px; }
.content-card__title h2 span { display: inline-grid; min-width: 23px; height: 23px; margin-left: 5px; place-items: center; border-radius: 8px; color: var(--dhq-cyan); background: rgba(66, 229, 232, 0.1); font-size: 11px; vertical-align: 2px; }
.content-card__lead { margin: -4px 0 16px; color: var(--dhq-muted); font-size: 13px; line-height: 1.55; }
.content-card__icon,
.action-row__icon,
.history-row__icon,
.download-row__icon {
  display: grid;
  width: 42px;
  height: 42px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 14px;
  color: var(--dhq-violet);
  background: var(--dhq-surface-2);
}

.content-card__icon--cyan { color: var(--dhq-cyan); }
.content-card__icon--blue { color: var(--dhq-blue); }
.content-button,
.support-action {
  display: flex;
  width: 100%;
  min-height: 46px;
  align-items: center;
  justify-content: center;
  gap: 9px;
  padding: 0 16px;
  border-radius: 14px;
  font-size: 14px;
  font-weight: 780;
  cursor: pointer;
  transition: border-color 0.18s ease, background 0.18s ease, color 0.18s ease, transform 0.18s ease;
}

.content-button--primary,
.support-action--filled {
  border: 0;
  color: #fff;
  background: var(--dhq-gradient);
  box-shadow: 0 10px 24px rgba(72, 119, 244, 0.2);
}

.content-button--secondary,
.support-action--bezeled {
  border: 1px solid var(--dhq-line);
  color: var(--dhq-text);
  background: var(--dhq-surface-2);
}

.content-button--text,
.support-action--plain { border: 0; color: var(--dhq-muted); background: transparent; box-shadow: none; }
.content-button:hover,
.support-action:hover { transform: translateY(-1px); }
.content-button:active,
.support-action:active { transform: scale(0.985); }
.content-button:disabled,
.support-action:disabled { cursor: wait; opacity: 0.55; transform: none; }

.payment-state-enter { animation: payment-panel-in 0.22s cubic-bezier(0.2, 0.8, 0.2, 1) both; }
.payment-spinner {
  display: inline-block;
  width: 17px;
  height: 17px;
  flex: 0 0 auto;
  border: 2px solid rgba(174, 181, 211, 0.28);
  border-top-color: currentColor;
  border-radius: 50%;
  animation: payment-spinner 0.72s linear infinite;
}

.message-card {
  display: flex;
  align-items: flex-start;
  gap: 11px;
  padding: 15px;
  border: 1px solid var(--dhq-line);
  border-radius: 17px;
  color: var(--dhq-cyan);
  background: rgba(66, 229, 232, 0.05);
}

.message-card--error {
  border-color: rgba(255, 141, 155, 0.25);
  color: var(--dhq-danger);
  background: rgba(255, 141, 155, 0.06);
  animation:
    payment-panel-in 0.2s cubic-bezier(0.2, 0.8, 0.2, 1) both,
    payment-error-nudge 0.24s ease-out 0.05s both;
}
.message-card > svg { flex: 0 0 auto; margin-top: 1px; }
.message-card strong { color: var(--dhq-text); font-size: 13px; }
.message-card p { margin: 3px 0 0; color: var(--dhq-muted); font-size: 12px; }

.pending-card {
  border-left: 3px solid var(--dhq-blue);
  animation:
    payment-panel-in 0.22s cubic-bezier(0.2, 0.8, 0.2, 1) both,
    payment-pending-breathe 1.8s ease-in-out 0.22s infinite;
}
.pending-card__clock svg { animation: payment-clock 8s linear infinite; }
.pending-card .content-button + .content-button { margin-top: 4px; }
.trial-card {
  display: grid;
  justify-items: center;
  gap: 14px;
  padding: 25px;
  background:
    radial-gradient(circle at 50% 0%, rgba(66, 229, 232, 0.13), transparent 44%),
    linear-gradient(145deg, rgba(116, 55, 245, 0.17), transparent 62%),
    var(--dhq-surface);
  text-align: center;
}

.trial-card__badge { position: absolute; top: 14px; right: 14px; padding: 4px 8px; border-radius: 8px; color: var(--dhq-lime); background: rgba(199, 255, 61, 0.1); font-size: 9px; font-weight: 850; letter-spacing: 0.08em; text-transform: uppercase; }
.trial-card__icon { display: grid; width: 58px; height: 58px; place-items: center; border-radius: 20px; color: #fff; background: var(--dhq-gradient); box-shadow: 0 12px 28px rgba(72, 119, 244, 0.26); }
.trial-card > div > span { display: block; max-width: 340px; margin-top: 6px; color: var(--dhq-muted); font-size: 13px; }

.offer-card { padding: 0; }
.offer-card__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; padding: 20px 20px 16px; }
.offer-card__header > div { min-width: 0; }
.offer-card__header > div > span { display: block; margin-top: 5px; color: var(--dhq-muted); font-size: 12px; }
.offer-card__price { flex: 0 0 auto; padding: 5px 9px; border-radius: 9px; color: var(--dhq-cyan); background: rgba(66, 229, 232, 0.1); font-size: 11px; font-weight: 800; }
.offer-card > .content-stack { padding: 0 20px 14px; }
.payment-methods { display: grid; gap: 9px; padding: 0 20px 20px; }
.payment-method {
  display: flex;
  width: 100%;
  min-height: 62px;
  align-items: center;
  gap: 12px;
  padding: 8px 13px;
  border: 1px solid rgba(116, 104, 245, 0.16);
  border-radius: 16px;
  color: var(--dhq-text);
  background: var(--dhq-surface-2);
  cursor: pointer;
  text-align: left;
  transition: border-color 0.18s ease, background 0.18s ease, transform 0.18s ease;
}

.payment-method:hover { border-color: var(--dhq-line-strong); background: var(--dhq-surface-hover); transform: translateY(-1px); }
.payment-method:active { transform: scale(0.985); }
.payment-method:disabled { cursor: wait; opacity: 0.58; }
.payment-method--loading {
  border-color: rgba(66, 229, 232, 0.3);
  background: rgba(66, 229, 232, 0.07);
}
.payment-method--loading .payment-method__icon { color: var(--dhq-cyan); }
.payment-method--featured { border-color: rgba(72, 119, 244, 0.3); background: linear-gradient(125deg, rgba(116, 55, 245, 0.15), rgba(72, 119, 244, 0.09)); }
.payment-method__icon { display: grid; width: 39px; height: 39px; flex: 0 0 auto; place-items: center; border-radius: 12px; color: var(--dhq-blue); background: rgba(72, 119, 244, 0.1); }
.payment-method__icon--cyan { color: var(--dhq-cyan); background: rgba(66, 229, 232, 0.08); }
.payment-method__icon--lime { color: var(--dhq-lime); background: rgba(199, 255, 61, 0.08); }
.payment-method > span:nth-child(2) { display: grid; min-width: 0; flex: 1; }
.payment-method strong { font-size: 13px; }
.payment-method small { color: var(--dhq-muted); font-size: 10px; }
.payment-method b { flex: 0 0 auto; font-size: 13px; }
.legal-note { display: flex; align-items: flex-start; gap: 9px; padding: 14px 20px 17px; color: rgba(174, 181, 211, 0.72); background: rgba(0, 0, 0, 0.16); font-size: 11px; line-height: 1.6; }
.legal-note svg { flex: 0 0 auto; margin-top: 2px; color: var(--dhq-muted); }
.legal-note p { margin: 0; }

.content-field { display: flex; min-height: 49px; align-items: center; gap: 10px; padding: 0 13px; border: 1px solid var(--dhq-line); border-radius: 14px; color: var(--dhq-muted); background: var(--dhq-surface-2); }
.content-field:focus-within { border-color: var(--dhq-line-strong); box-shadow: 0 0 0 3px rgba(66, 229, 232, 0.05); }
.content-field--error { border-color: rgba(255, 141, 155, 0.35); }
.content-field input { width: 100%; min-width: 0; height: 46px; border: 0; outline: 0; color: var(--dhq-text); background: transparent; font-weight: 650; }
.content-field input::placeholder { color: rgba(174, 181, 211, 0.42); }
.content-field + .content-button { margin-top: 10px; }
.field-error { margin: 6px 1px 0; color: var(--dhq-danger); font-size: 11px; }

.detail-grid { display: grid; margin: 0; border: 1px solid rgba(116, 104, 245, 0.11); border-radius: 15px; overflow: hidden; }
.detail-grid > div,
.detail-grid__copy { display: flex; min-height: 54px; align-items: center; justify-content: space-between; gap: 12px; padding: 10px 13px; border: 0; border-bottom: 1px solid rgba(116, 104, 245, 0.1); color: var(--dhq-text); background: var(--dhq-surface-2); text-align: left; }
.detail-grid > :last-child { border-bottom: 0; }
.detail-grid dt,
.detail-grid small { color: var(--dhq-muted); font-size: 10px; }
.detail-grid dd { margin: 0; font-size: 12px; font-weight: 750; }
.detail-grid__copy { cursor: pointer; }
.detail-grid__copy span { display: grid; min-width: 0; }
.detail-grid__copy strong { overflow: hidden; max-width: 270px; font-size: 11px; text-overflow: ellipsis; white-space: nowrap; }
.content-note { margin: 13px 0 0; color: var(--dhq-muted); font-size: 11px; line-height: 1.55; }

.history-card { padding: 0; }
.history-card > .content-card__title { padding: 20px 20px 0; }
.history-list { display: grid; }
.history-row { display: flex; align-items: center; gap: 11px; padding: 14px 20px; border-bottom: 1px solid rgba(116, 104, 245, 0.1); }
.history-row__icon { width: 39px; height: 39px; color: var(--dhq-blue); }
.history-row__icon--crypto { color: var(--dhq-cyan); }
.history-row__icon--stars { color: var(--dhq-lime); }
.history-row__main { display: grid; min-width: 0; flex: 1; }
.history-row__main strong { overflow: hidden; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
.history-row__main span { color: var(--dhq-muted); font-size: 10px; }
.history-row__amount { display: grid; justify-items: end; gap: 3px; text-align: right; }
.history-row__amount strong { font-size: 12px; }
.status-badge { width: fit-content; padding: 3px 7px; border-radius: 7px; font-size: 8px; font-weight: 850; letter-spacing: 0.06em; text-transform: uppercase; }
.status-badge--success { color: var(--dhq-lime); background: rgba(199, 255, 61, 0.1); }
.status-badge--pending { color: var(--dhq-cyan); background: rgba(66, 229, 232, 0.1); }
.status-badge--muted { color: var(--dhq-muted); background: rgba(174, 181, 211, 0.08); }
.history-row .status-badge { animation: payment-badge-in 0.18s ease-out both; }
.history-card__more { margin: 5px 0; }

.payment-feedback {
  position: fixed;
  z-index: 90;
  top: max(82px, calc(env(safe-area-inset-top) + 66px));
  right: max(16px, calc((100vw - 1120px) / 2));
  display: flex;
  width: min(360px, calc(100vw - 32px));
  align-items: center;
  gap: 11px;
  padding: 13px 15px;
  border: 1px solid rgba(199, 255, 61, 0.28);
  border-radius: 17px;
  color: var(--dhq-lime);
  background: var(--dhq-surface);
  box-shadow: 0 18px 48px rgba(0, 0, 0, 0.34);
  backdrop-filter: blur(16px);
  animation:
    payment-success-in 0.28s cubic-bezier(0.18, 0.9, 0.24, 1.2) both,
    payment-success-glow 0.65s ease-out both;
}

.payment-feedback__icon {
  display: grid;
  width: 38px;
  height: 38px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 12px;
  background: rgba(199, 255, 61, 0.1);
}
.payment-feedback__icon path {
  stroke-dasharray: 28;
  stroke-dashoffset: 28;
  animation: payment-check-draw 0.32s ease-out 0.12s forwards;
}
.payment-feedback > span:last-child { display: grid; gap: 2px; }
.payment-feedback strong { color: var(--dhq-text); font-size: 13px; }
.payment-feedback small { color: var(--dhq-muted); font-size: 10px; }

.support-card { display: grid; grid-template-columns: auto minmax(0, 1fr); align-items: center; gap: 12px; }
.support-card p { margin: 4px 0 0; color: var(--dhq-muted); font-size: 12px; }
.support-card .support-action { grid-column: 1 / -1; }

.content-section-heading { display: flex; align-items: end; justify-content: space-between; gap: 12px; padding: 5px 2px 0; }
.content-section-heading p { margin: 0; color: var(--dhq-cyan); font-size: 9px; font-weight: 850; letter-spacing: 0.12em; text-transform: uppercase; }
.content-section-heading h2 { margin: 2px 0 0; font-size: 17px; }
.content-section-heading > span { display: grid; min-width: 25px; height: 25px; place-items: center; border-radius: 8px; color: var(--dhq-cyan); background: rgba(66, 229, 232, 0.1); font-size: 11px; font-weight: 850; }

.download-list,
.action-list,
.data-list { display: grid; margin: 0 -8px -8px; }
.download-row,
.action-row,
.data-row,
.copy-row {
  display: flex;
  width: 100%;
  min-height: 58px;
  align-items: center;
  gap: 11px;
  padding: 9px 10px;
  border: 0;
  border-bottom: 1px solid rgba(116, 104, 245, 0.09);
  color: var(--dhq-text);
  background: transparent;
  cursor: pointer;
  text-align: left;
}
.download-row:last-child,
.action-row:last-child,
.data-row:last-child { border-bottom: 0; }
.download-row:hover,
.action-row:hover,
.data-row:hover { background: rgba(116, 55, 245, 0.06); }
.download-row > span:nth-child(2),
.action-row > span:nth-child(2),
.data-row > span:first-child,
.copy-row > span { display: grid; min-width: 0; flex: 1; }
.download-row strong,
.action-row strong,
.data-row strong,
.copy-row strong { overflow: hidden; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
.download-row small,
.action-row small,
.data-row small,
.copy-row small { color: var(--dhq-muted); font-size: 10px; }
.download-row > svg,
.action-row > svg { flex: 0 0 auto; color: var(--dhq-muted); }
.download-row__icon { width: 39px; height: 39px; }
.download-row__icon--android { color: var(--dhq-lime); }
.download-row__icon--windows { color: var(--dhq-blue); }
.download-row__icon--macos,
.download-row__icon--ios { color: var(--dhq-cyan); }

.accordion-list { display: grid; gap: 11px; }
.accordion-card { padding: 0; }
.accordion-card__toggle { display: flex; width: 100%; min-height: 70px; align-items: center; gap: 11px; padding: 13px 15px; border: 0; color: var(--dhq-text); background: transparent; cursor: pointer; text-align: left; }
.accordion-card__toggle > span:nth-child(2) { display: grid; min-width: 0; flex: 1; }
.accordion-card__toggle small { color: var(--dhq-muted); font-size: 9px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; }
.accordion-card__toggle strong { font-size: 13px; }
.accordion-card__chevron { color: var(--dhq-muted); transition: transform 0.18s ease; }
.accordion-card--open .accordion-card__chevron { transform: rotate(90deg); }
.guide-body { display: grid; gap: 12px; padding: 2px 16px 18px; border-top: 1px solid rgba(116, 104, 245, 0.1); }
.guide-body img { width: 100%; margin-top: 14px; border: 1px solid var(--dhq-line); border-radius: 15px; }
.rich-text { padding: 15px; border: 1px solid rgba(116, 104, 245, 0.11); border-radius: 15px; color: var(--dhq-muted); background: var(--dhq-surface-2); font-size: 13px; line-height: 1.65; white-space: pre-wrap; }
.rich-text > :first-child { margin-top: 0; }
.rich-text > :last-child { margin-bottom: 0; }
.rich-text code { padding: 2px 5px; border-radius: 5px; color: var(--dhq-cyan); background: rgba(66, 229, 232, 0.08); }

.result-panel { display: grid; gap: 8px; margin-top: 14px; padding: 13px; border: 1px solid rgba(199, 255, 61, 0.15); border-radius: 15px; background: rgba(199, 255, 61, 0.04); }
.result-panel__title { display: flex; align-items: center; gap: 7px; color: var(--dhq-lime); font-size: 12px; }
.copy-row { min-height: 54px; padding: 9px 11px; border: 1px solid rgba(116, 104, 245, 0.13); border-radius: 12px; background: var(--dhq-surface-2); }
.copy-row > svg { flex: 0 0 auto; color: var(--dhq-cyan); }
.data-card { padding: 0; }
.data-card > .content-card__title { padding: 20px 20px 0; }
.data-card .data-list { margin: 0; }
.data-row { min-height: 62px; padding: 10px 20px; }
.data-row:disabled { cursor: default; opacity: 1; }
.data-row__action { display: flex; flex: 0 0 auto; align-items: center; gap: 5px; color: var(--dhq-cyan); font-size: 9px; font-weight: 800; }
.empty-row { margin: 0; padding: 20px; color: var(--dhq-muted); font-size: 12px; text-align: center; }
.pagination { display: flex; align-items: center; justify-content: space-between; gap: 9px; padding: 12px 20px 16px; border-top: 1px solid rgba(116, 104, 245, 0.1); }
.pagination button { min-width: 88px; min-height: 38px; border: 1px solid var(--dhq-line); border-radius: 11px; color: var(--dhq-text); background: var(--dhq-surface-2); font-size: 11px; font-weight: 750; }
.pagination button:disabled { opacity: 0.38; }
.pagination span { color: var(--dhq-muted); font-size: 10px; }

.compact-card { display: grid; gap: 14px; }
.compact-card__copy { display: flex; align-items: center; gap: 11px; }
.compact-card__copy > div { min-width: 0; }
.compact-card__copy strong { display: block; font-size: 12px; line-height: 1.4; }
.diagnostic-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1px; margin: 0 0 14px; overflow: hidden; border: 1px solid rgba(116, 104, 245, 0.1); border-radius: 14px; background: rgba(116, 104, 245, 0.1); }
.diagnostic-grid > div { display: grid; gap: 2px; padding: 10px; background: var(--dhq-surface-2); }
.diagnostic-grid > div:last-child { grid-column: 1 / -1; }
.diagnostic-grid dt { color: var(--dhq-muted); font-size: 9px; }
.diagnostic-grid dd { overflow: hidden; margin: 0; font-size: 11px; font-weight: 750; text-overflow: ellipsis; white-space: nowrap; }

/* Telegram UI screens inherit brand tokens. */
.app-content a { color: var(--dhq-cyan); }
.app-content img { max-width: 100%; }
.app-content section { border-color: var(--dhq-line); }

@keyframes sheet-in {
  from { opacity: 0; transform: translateY(34px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes payment-panel-in {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes payment-spinner {
  to { transform: rotate(360deg); }
}

@keyframes payment-error-nudge {
  0%, 100% { transform: translateX(0); }
  30% { transform: translateX(-4px); }
  65% { transform: translateX(4px); }
}

@keyframes payment-pending-breathe {
  0%, 100% { box-shadow: 0 14px 40px rgba(0, 0, 0, 0.12); }
  50% { box-shadow: 0 14px 44px rgba(72, 119, 244, 0.2), 0 0 0 1px rgba(72, 119, 244, 0.1); }
}

@keyframes payment-clock {
  to { transform: rotate(360deg); }
}

@keyframes payment-badge-in {
  from { opacity: 0.45; transform: scale(0.9); }
  to { opacity: 1; transform: scale(1); }
}

@keyframes payment-success-in {
  from { opacity: 0; transform: translateY(-8px) scale(0.96); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}

@keyframes payment-success-glow {
  0% { box-shadow: 0 0 0 0 rgba(199, 255, 61, 0.2), 0 18px 48px rgba(0, 0, 0, 0.34); }
  100% { box-shadow: 0 0 0 10px rgba(199, 255, 61, 0), 0 18px 48px rgba(0, 0, 0, 0.34); }
}

@keyframes payment-check-draw {
  to { stroke-dashoffset: 0; }
}

@media (min-width: 760px) {
  .web-login { grid-template-columns: minmax(0, 1.2fr) minmax(380px, 0.8fr); padding: 48px clamp(34px, 7vw, 110px); }
  .web-login__intro { display: block; }
  .account-name { display: inline; }
  .logout-button span { display: inline; }
  .logout-button { padding: 0 12px; }
  .install-modal { align-items: center; padding: 24px; }
  .install-sheet { width: min(100%, 500px); padding: 28px; border-bottom: 1px solid rgba(116, 104, 245, 0.32); border-radius: 28px; }
  .install-sheet__handle { display: none; }
  .payment-methods { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .payment-method--featured { grid-column: 1 / -1; }
  .content-grid--two { grid-template-columns: repeat(2, minmax(0, 1fr)); align-items: start; }
  .content-card { padding: 22px; }
  .offer-card,
  .history-card,
  .data-card,
  .accordion-card { padding: 0; }
}

@media (min-width: 900px) {
  .app-header { padding-right: max(28px, calc((100vw - 1120px) / 2)); padding-left: max(28px, calc((100vw - 1120px) / 2)); }
  .app-layout { display: grid; width: min(1120px, calc(100% - 48px)); margin: 0 auto; grid-template-columns: 230px minmax(0, 760px); justify-content: center; gap: 42px; }
  .app-sidebar { position: sticky; top: 92px; display: flex; height: calc(100vh - 118px); flex-direction: column; padding-top: 34px; }
  .app-sidebar__label { margin: 0 14px 12px; color: rgba(174, 181, 211, 0.5); font-size: 10px; font-weight: 800; letter-spacing: 0.12em; text-transform: uppercase; }
  .app-sidebar__note { display: flex; align-items: center; gap: 9px; margin-top: auto; padding: 14px; border: 1px solid var(--dhq-line); border-radius: 15px; color: var(--dhq-muted); background: var(--dhq-surface); font-size: 11px; }
  .app-main { padding: 34px 0 70px; }
  .page-heading { margin-bottom: 24px; }
  .page-heading h1 { font-size: 31px; }
  .bottom-nav { display: none; }
}

@media (max-width: 520px) {
  .app-header { gap: 10px; padding-right: 10px; padding-left: 12px; }
  .app-header__brand { min-width: 0; gap: 9px; }
  .app-header__mark { width: 36px; height: 36px; }
  .app-header__brand strong { white-space: nowrap; }
  .app-header__brand span { display: none; }
  .app-header__account { gap: 5px; }
  .account-avatar,
  .app-header__account > img { width: 30px; height: 30px; }
  .account-name { display: none; }
  .devices-summary h2 { font-size: 21px; white-space: nowrap; }
  .device-card__footer { align-items: stretch; flex-direction: column; }
  .device-card__footer > .primary-action { width: 100%; }
  .router-action { justify-items: stretch; }
  .router-action > p { max-width: none; text-align: left; }
  .secondary-action { width: 100%; padding-right: 12px; padding-left: 12px; font-size: 13px; }
  .content-card { padding: 17px; border-radius: 20px; }
  .offer-card,
  .history-card,
  .data-card,
  .accordion-card { padding: 0; }
  .offer-card__header { display: grid; padding: 18px 17px 14px; }
  .offer-card__price { width: fit-content; }
  .payment-methods { padding: 0 17px 17px; }
  .legal-note { padding: 13px 17px 15px; }
  .history-card > .content-card__title,
  .data-card > .content-card__title { padding: 18px 17px 0; }
  .history-row,
  .data-row { padding-right: 17px; padding-left: 17px; }
  .history-row__icon { display: none; }
  .history-row__amount strong { font-size: 11px; }
  .payment-feedback { right: 16px; left: 16px; width: auto; }
  .download-list,
  .action-list { margin-right: -5px; margin-left: -5px; }
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    scroll-behavior: auto !important;
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
  .pending-card__clock svg,
  .payment-spinner { transform: none !important; }
}
```
