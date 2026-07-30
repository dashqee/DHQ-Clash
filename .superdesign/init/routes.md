# Routes

The frontend is a single Vite/React application served at the cabinet URL. It uses stateful tab routing rather than React Router.

| Visible destination | Component | Shell |
| --- | --- | --- |
| Devices (default) | `webapp/src/screens/Dashboard.tsx` | `webapp/src/App.tsx` |
| Subscription | `webapp/src/screens/Buy.tsx` | `webapp/src/App.tsx` |
| Referrals (feature-flagged) | `webapp/src/screens/Referrals.tsx` | `webapp/src/App.tsx` |
| Installation | `webapp/src/screens/Guides.tsx` | `webapp/src/App.tsx` |
| Support | `webapp/src/screens/Help.tsx` | `webapp/src/App.tsx` |
| Admin (new target) | planned `webapp/src/screens/Admin.tsx` | `webapp/src/App.tsx`, visible only to DB-backed admins |

Authentication states:
- Telegram Mini App: Telegram initData is sent as `Authorization: tma …`.
- Web: Telegram Login Widget establishes an HTTP-only server session.
- Unauthenticated users render `WebLogin`; authenticated users must also have started the bot.

## Router/shell source

```tsx
import { useEffect, useState, type ReactNode } from "react";
import { Button, Spinner } from "@telegram-apps/telegram-ui";
import { Dashboard } from "./screens/Dashboard";
import { Buy } from "./screens/Buy";
import { Guides } from "./screens/Guides";
import { Help } from "./screens/Help";
import { Referrals } from "./screens/Referrals";
import { ErrorBoundary } from "./components/ErrorBoundary";
import { WebLogin } from "./components/WebLogin";
import { getConfig, getMe, getSession, postLogout, type SessionUser } from "./api";
import { isTelegramMiniApp, openExternal } from "./platform";
import { BrandMark } from "./components/BrandMark";
import { Icon, type IconName } from "./components/Icons";

const TABS = [
  { id: "devices", text: "Устройства", icon: "devices" },
  { id: "buy", text: "Подписка", icon: "buy" },
  { id: "referrals", text: "Рефералы", icon: "referrals" },
  { id: "guides", text: "Установка", icon: "guides" },
  { id: "help", text: "Поддержка", icon: "help" },
] as const;

type TabId = (typeof TABS)[number]["id"];

function Gate({ title, description, children }: {
  title: string;
  description: string;
  children?: ReactNode;
}) {
  return (
    <main className="gate">
      <section className="gate__card">
        <BrandMark className="gate__mark" />
        <div className="brand-name">DHQ <span>Clash</span></div>
        <h1>{title}</h1>
        <p>{description}</p>
        {children}
      </section>
    </main>
  );
}

export function App() {
  const [sessionChecked, setSessionChecked] = useState(false);
  const [authenticated, setAuthenticated] = useState(false);
  const [sessionUser, setSessionUser] = useState<SessionUser | null>(null);
  const [botStarted, setBotStarted] = useState<boolean | null>(null);
  const [botUsername, setBotUsername] = useState("");
  const [referralProgram, setReferralProgram] = useState(false);
  const [tab, setTab] = useState<TabId>("devices");
  // Bump to force Dashboard to remount + refetch after a purchase/trial provisions.
  const [rev, setRev] = useState(0);

  const onProvisioned = () => {
    setRev((r) => r + 1);
    setTab("devices");
  };

  const checkBot = () => {
    setBotStarted(null);
    getMe().then((me) => {
      setBotStarted(me.bot_started);
      setReferralProgram(me.referral_program);
    }).catch(() => setBotStarted(false));
  };

  useEffect(() => {
    Promise.all([
      getSession(),
      getConfig().catch(() => null),
    ]).then(([session, cfg]) => {
      setAuthenticated(session.authenticated);
      setSessionUser(session.user);
      if (cfg) setBotUsername(cfg.bot_username);
      setSessionChecked(true);
      if (session.authenticated) checkBot();
    }).catch(() => setSessionChecked(true));
  }, []);

  if (!sessionChecked) {
    return (
      <Gate title="Личный кабинет" description="Проверяем авторизацию…">
        <Spinner size="l" />
      </Gate>
    );
  }

  if (!authenticated) {
    return <WebLogin />;
  }

  if (botStarted === null) {
    return (
      <Gate title="Почти готово" description="Проверяем связь с ботом…">
        <Spinner size="l" />
      </Gate>
    );
  }

  if (!botStarted) {
    const openBot = () => {
      if (!botUsername) return;
      const url = `https://t.me/${botUsername}?start=miniapp`;
      openExternal(url);
    };
    return (
      <Gate title="Сначала запустите бота" description="Это нужно для служебных уведомлений, поддержки и файлов конфигурации роутера.">
        <div className="gate__actions">
          <Button size="m" mode="filled" stretched disabled={!botUsername} onClick={openBot}>Открыть бота и нажать Start</Button>
          <Button size="s" mode="bezeled" stretched onClick={checkBot}>Я нажал Start — продолжить</Button>
        </div>
      </Gate>
    );
  }

  const visibleTabs = TABS.filter((item) => item.id !== "referrals" || referralProgram);
  const activeTab = TABS.find((item) => item.id === tab)!;
  const userName = sessionUser?.first_name || (sessionUser?.username ? `@${sessionUser.username}` : "Telegram");
  const navigation = (className: string) => (
    <nav className={className} aria-label="Разделы кабинета">
      {visibleTabs.map((item) => (
        <button
          key={item.id}
          type="button"
          className={tab === item.id ? "nav-item nav-item--active" : "nav-item"}
          onClick={() => setTab(item.id)}
        >
          <Icon name={item.icon as IconName} />
          <span>{item.text}</span>
        </button>
      ))}
    </nav>
  );

  return (
    <div className={isTelegramMiniApp ? "app-shell app-shell--tma" : "app-shell app-shell--web"}>
      <header className="app-header">
        <div className="app-header__brand">
          <BrandMark className="app-header__mark" />
          <div>
            <strong>DHQ Clash</strong>
            <span>Личный кабинет</span>
          </div>
        </div>
        <div className="app-header__account">
          {sessionUser?.photo_url ? <img src={sessionUser.photo_url} alt="" /> : <span className="account-avatar">{userName.slice(0, 1)}</span>}
          <span className="account-name">{userName}</span>
          {!isTelegramMiniApp && (
            <button
              type="button"
              className="logout-button"
              title="Выйти"
              onClick={() => postLogout().finally(() => window.location.reload())}
            >
              <Icon name="logout" />
              <span>Выйти</span>
            </button>
          )}
        </div>
      </header>

      <div className="app-layout">
        <aside className="app-sidebar">
          <p className="app-sidebar__label">Навигация</p>
          {navigation("side-nav")}
          <div className="app-sidebar__note">
            <span className="status-dot" />
            Защищённое соединение
          </div>
        </aside>
        <main className="app-main">
          <header className="page-heading">
            <p>DHQ Clash</p>
            <h1>{activeTab.text}</h1>
          </header>
          <div className="app-content">
            <ErrorBoundary key={tab}>
              {tab === "devices" && <Dashboard key={rev} />}
              {tab === "buy" && <Buy onProvisioned={onProvisioned} />}
              {tab === "referrals" && <Referrals />}
              {tab === "guides" && <Guides />}
              {tab === "help" && <Help />}
            </ErrorBoundary>
          </div>
        </main>
      </div>
      {navigation("bottom-nav")}
    </div>
  );
}
```
