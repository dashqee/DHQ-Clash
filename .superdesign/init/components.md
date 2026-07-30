# Shared UI components

## `webapp/src/components/BrandMark.tsx`
DHQ Clash brand mark used in the app shell, login, gates, and empty states.

```tsx
export function BrandMark({ className = "" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 1024 1024" role="img" aria-label="DHQ Clash">
      <defs>
        <linearGradient id="dhq-bg" x1="128" y1="64" x2="896" y2="960" gradientUnits="userSpaceOnUse">
          <stop stopColor="#171347" />
          <stop offset="1" stopColor="#08091f" />
        </linearGradient>
        <linearGradient id="dhq-ring" x1="250" y1="730" x2="770" y2="250" gradientUnits="userSpaceOnUse">
          <stop stopColor="#7437f5" />
          <stop offset=".48" stopColor="#4877f4" />
          <stop offset="1" stopColor="#42e5e8" />
        </linearGradient>
        <linearGradient id="dhq-route" x1="250" y1="780" x2="812" y2="355" gradientUnits="userSpaceOnUse">
          <stop stopColor="#7028ef" />
          <stop offset=".55" stopColor="#4c79f5" />
          <stop offset="1" stopColor="#42e5e8" />
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="224" fill="url(#dhq-bg)" />
      <rect x="18" y="18" width="988" height="988" rx="210" fill="none" stroke="#35316e" strokeWidth="4" />
      <path d="M744 256A318 318 0 1 0 760 738" fill="none" stroke="url(#dhq-ring)" strokeWidth="112" strokeLinecap="round" />
      <path d="M249 488H492V564H249C264 540 264 512 249 488Z" fill="#5047d6" opacity=".72" />
      <path d="M250 780C351 766 441 670 536 548C625 434 704 387 786 366C687 428 610 510 526 616C430 738 333 808 250 780Z" fill="url(#dhq-route)" />
      <path d="M250 780C302 811 347 804 397 771C352 786 313 780 283 755Z" fill="#7a33f2" />
      <circle cx="812" cy="355" r="49" fill="#c7ff3d" />
    </svg>
  );
}
```

## `webapp/src/components/Icons.tsx`
Shared inline SVG icon system used by navigation and actions.

```tsx
import type { ReactNode } from "react";

export type IconName =
  | "devices" | "buy" | "referrals" | "guides" | "help"
  | "phone" | "router" | "copy" | "edit" | "send" | "close"
  | "android" | "apple" | "windows" | "logout"
  | "clock" | "gift" | "card" | "wallet" | "star" | "key"
  | "download" | "chevron" | "document" | "lock" | "check"
  | "info" | "alert" | "link" | "refresh";

const paths: Record<IconName, ReactNode> = {
  devices: <><rect x="4" y="4" width="6" height="6" rx="1" /><rect x="14" y="4" width="6" height="6" rx="1" /><rect x="4" y="14" width="6" height="6" rx="1" /><rect x="14" y="14" width="6" height="6" rx="1" /></>,
  buy: <><path d="m13 2-9 12h7l-1 8 9-12h-7l1-8Z" /></>,
  referrals: <><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" /></>,
  guides: <><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" /><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2Z" /><path d="M8 7h8M8 11h6" /></>,
  help: <><path d="M4 13a8 8 0 0 1 16 0" /><path d="M18 19h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3v5a4 4 0 0 1-4 4h-4" /><path d="M4 12h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-5Z" /></>,
  phone: <><rect x="7" y="2" width="10" height="20" rx="2" /><path d="M11 18h2" /></>,
  router: <><rect x="3" y="13" width="18" height="8" rx="2" /><path d="M7 17h.01M11 17h.01M17 13V5M14 8a4 4 0 0 1 6 0M12 5a7 7 0 0 1 10 0" /></>,
  copy: <><rect x="9" y="9" width="11" height="11" rx="2" /><path d="M15 9V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h3" /></>,
  edit: <><path d="M12 20h9" /><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4Z" /></>,
  send: <><path d="m22 2-7 20-4-9-9-4Z" /><path d="M22 2 11 13" /></>,
  close: <><path d="m18 6-12 12M6 6l12 12" /></>,
  android: <><path d="M7 8h10v9a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2V8ZM8 5 6.5 3M16 5l1.5-2M9.5 11h.01M14.5 11h.01M7 11H4v5h3M17 11h3v5h-3" /></>,
  apple: <><path d="M12 6c1-2 3-2 3-4-2 0-4 1-4 4M17 13c0-3 2-4 3-5-2-2-5-2-6-1-2 1-3 0-5 0-3 0-5 3-5 6 0 5 4 9 6 9 2 0 2-1 4-1s2 1 4 1c2 0 4-4 4-7-2-1-3-1-5-2Z" /></>,
  windows: <><path d="M3 5.5 10.5 4v7.3H3ZM12 3.7 21 2v9.3h-9ZM3 12.7h7.5V20L3 18.5ZM12 12.7h9V22l-9-1.7Z" /></>,
  logout: <><path d="M10 17l5-5-5-5M15 12H3M21 19V5a2 2 0 0 0-2-2h-6" /></>,
  clock: <><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></>,
  gift: <><rect x="3" y="8" width="18" height="13" rx="2" /><path d="M12 8v13M3 12h18M7.5 8C5 8 4 7 4 5.5S5 3 6.5 3C9 3 12 8 12 8M16.5 8C19 8 20 7 20 5.5S19 3 17.5 3C15 3 12 8 12 8" /></>,
  card: <><rect x="2" y="5" width="20" height="14" rx="3" /><path d="M2 10h20M6 15h3" /></>,
  wallet: <><path d="M4 5h14a2 2 0 0 1 2 2v12H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z" /><path d="M16 12h6v4h-6a2 2 0 0 1 0-4ZM5 5V3h12v2" /></>,
  star: <path d="m12 2 3 6 7 .9-5 4.8 1.3 6.8L12 17.2l-6.3 3.3L7 13.7 2 8.9 9 8Z" />,
  key: <><circle cx="8" cy="15" r="4" /><path d="m11 12 9-9M16 7l3 3M14 9l2 2" /></>,
  download: <><path d="M12 3v12M7 10l5 5 5-5" /><path d="M4 21h16" /></>,
  chevron: <path d="m9 18 6-6-6-6" />,
  document: <><path d="M6 2h8l4 4v16H6Z" /><path d="M14 2v5h5M9 13h6M9 17h6" /></>,
  lock: <><rect x="4" y="10" width="16" height="11" rx="2" /><path d="M8 10V7a4 4 0 0 1 8 0v3" /></>,
  check: <path d="m5 12 4 4L19 6" />,
  info: <><circle cx="12" cy="12" r="9" /><path d="M12 11v5M12 8h.01" /></>,
  alert: <><path d="M10.3 3.8 2.4 18a2 2 0 0 0 1.8 3h15.6a2 2 0 0 0 1.8-3L13.7 3.8a2 2 0 0 0-3.4 0Z" /><path d="M12 9v4M12 17h.01" /></>,
  link: <><path d="M10 13a5 5 0 0 0 7.5.5l2-2a5 5 0 0 0-7-7l-1.1 1.1" /><path d="M14 11a5 5 0 0 0-7.5-.5l-2 2a5 5 0 0 0 7 7l1.1-1.1" /></>,
  refresh: <><path d="M20 7v5h-5M4 17v-5h5" /><path d="M6.1 9A7 7 0 0 1 18 6l2 6M4 12l2 6a7 7 0 0 0 11.9-3" /></>,
};

export function Icon({ name, size = 20, className = "" }: { name: IconName; size?: number; className?: string }) {
  return (
    <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {paths[name]}
    </svg>
  );
}
```

## `webapp/src/components/SupportButton.tsx`
Reusable support CTA.

```tsx
import { useEffect, useState } from "react";
import { getConfig, type Config } from "../api";
import { isTelegramMiniApp, openExternal } from "../platform";
import { Icon } from "./Icons";

const tg = window.Telegram?.WebApp;

/** Opens the support contact. Hidden when neither a contact nor SUPPORT_URL is set. */
export function SupportButton({ mode = "bezeled" }: { mode?: "bezeled" | "plain" | "filled" }) {
  const [cfg, setCfg] = useState<Config | null>(null);
  useEffect(() => {
    getConfig()
      .then(setCfg)
      .catch(() => {});
  }, []);

  if (!cfg) return null;

  // Prefer the human operator. SUPPORT_URL points at *this* bot, and asking Telegram to
  // open the chat the Mini App is already running inside does nothing visible — the app
  // stays on top of it, so the tap looks broken. A different chat opens normally.
  const contactUrl = cfg.support_contact ? `https://t.me/${cfg.support_contact}` : "";
  const url = contactUrl || cfg.support_url;
  if (!url) return null;

  const open = () => {
    const go = () => {
      openExternal(url);
      // Falling back to this bot's own chat: close the app so the user actually lands
      // in it instead of staring at an unchanged screen.
      if (!contactUrl && isTelegramMiniApp) tg?.close();
    };
    if (tg?.showConfirm) {
      const who = contactUrl ? "оператором" : "ботом поддержки";
      tg.showConfirm(`Откроется чат с ${who}. Продолжить?`, (ok) => ok && go());
    } else {
      go();
    }
  };

  return (
    <button
      type="button"
      className={`support-action support-action--${mode}`}
      onClick={open}
    >
      <Icon name="help" />
      Написать в поддержку
    </button>
  );
}
```

## `webapp/src/components/ErrorBoundary.tsx`
Shared page-level error state.

```tsx
import { Component, type ErrorInfo, type ReactNode } from "react";

interface State {
  error: Error | null;
}

/** Catches render/runtime errors so a broken screen shows a readable message instead of
 * a blank/frozen app. Surfaces the message so users can report exactly what failed. */
export class ErrorBoundary extends Component<{ children: ReactNode }, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // Visible in Telegram Desktop devtools console for diagnosis.
    console.error("Mini App error:", error, info.componentStack);
  }

  render() {
    if (this.state.error) {
      return (
        <div style={{ padding: 24, textAlign: "center", color: "var(--tgui--text_color)" }}>
          <div style={{ fontSize: 48 }}>⚠️</div>
          <h3>Что-то пошло не так</h3>
          <p style={{ opacity: 0.7, wordBreak: "break-word" }}>{this.state.error.message}</p>
          <button
            style={{ marginTop: 12, padding: "8px 16px", borderRadius: 8, border: "none", cursor: "pointer" }}
            onClick={() => this.setState({ error: null })}
          >
            Повторить
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
```

## `webapp/src/components/WebLogin.tsx`
Telegram Login Widget gate for ordinary web browsers.

```tsx
import { useEffect, useRef, useState } from "react";
import { Button, Spinner } from "@telegram-apps/telegram-ui";
import { getConfig } from "../api";
import { BrandMark } from "./BrandMark";

export function WebLogin() {
  const container = useRef<HTMLDivElement>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let canceled = false;
    getConfig()
      .then((config) => {
        if (canceled || !container.current) return;
        if (!config.bot_username) throw new Error("Имя Telegram-бота не настроено");
        const script = document.createElement("script");
        script.async = true;
        script.src = "https://telegram.org/js/telegram-widget.js?22";
        script.dataset.telegramLogin = config.bot_username;
        script.dataset.size = "large";
        script.dataset.radius = "12";
        script.dataset.userpic = "true";
        script.dataset.requestAccess = "write";
        script.dataset.authUrl = `${window.location.origin}/auth/telegram/callback`;
        script.onload = () => !canceled && setLoading(false);
        script.onerror = () => {
          if (!canceled) {
            setLoading(false);
            setError("Не удалось загрузить кнопку Telegram. Проверьте соединение.");
          }
        };
        container.current.replaceChildren(script);
      })
      .catch((e) => {
        if (!canceled) {
          setLoading(false);
          setError(e instanceof Error ? e.message : String(e));
        }
      });
    return () => {
      canceled = true;
      container.current?.replaceChildren();
    };
  }, []);

  return (
    <div className="web-login">
      <section className="web-login__intro">
        <div className="web-login__brand">
          <BrandMark className="web-login__brand-mark" />
          <strong>DHQ <span>Clash</span></strong>
        </div>
        <p className="web-login__eyebrow">Один кабинет · все устройства</p>
        <h1>Управляйте доступом <span>в одном месте</span></h1>
        <p className="web-login__lead">
          Конфиги, установка профилей, подписка и оплата — в защищённом кабинете,
          который одинаково работает в Telegram и браузере.
        </p>
        <ul className="web-login__benefits">
          <li><span>01</span> Временные ссылки установки не попадают в чат</li>
          <li><span>02</span> Доступ только после подтверждения Telegram</li>
          <li><span>03</span> Поддержка всех ваших устройств</li>
        </ul>
      </section>

      <section className="web-login__card">
        <BrandMark className="web-login__card-mark" />
        <p className="web-login__eyebrow">Защищённый вход</p>
        <h2>Личный кабинет</h2>
        <p className="web-login__description">
          Подтвердите Telegram-аккаунт, чтобы открыть ваши устройства и подписку.
        </p>
        <div className="web-login__widget-wrap">
          <div ref={container} className="web-login__widget" aria-label="Войти через Telegram" />
          {loading && <Spinner size="m" />}
        </div>
        {error && <div className="web-login__error">{error}</div>}
        <p className="web-login__note">
          Мы получим только открытые данные профиля Telegram. Пароль и переписка недоступны.
        </p>
        {error && <Button size="s" mode="bezeled" onClick={() => window.location.reload()}>Повторить</Button>}
      </section>
    </div>
  );
}
```
