# DHQClash Admin design system

## Product context
DHQClash is a Telegram-first VPN subscription product. The same responsive React/Vite application serves an ordinary web cabinet and a Telegram Mini App. The admin area is a privileged operational surface inside the existing cabinet, authenticated by Telegram and shown only when the server confirms a DB-backed admin record.

## Visual direction
Extend the current dark DHQ Clash UI without introducing a competing visual language. Use the existing midnight background, layered navy surfaces, violet/blue/cyan gradient, cyan status accents, lime focus ring, and coral danger color. Keep the native UI font stack. Admin density may be higher than the consumer pages, but cards and forms must remain touch-friendly.

## Admin information architecture
- Overview: signed-in admin identity, role badge (owner/admin), system status, quick actions.
- Clients: lookup/list, view client configuration, create client, bind Telegram, create claim/referral codes, notifications.
- Devices: add, enable router, delete, expire, set expiry, extend.
- Servers: health list and enable/disable actions.
- System: reload configuration and refresh traffic.
- Owner-only access management: list/add/deactivate admins by Telegram user ID in the database.

## Components and behavior
- Desktop: retain sticky header and left sidebar. Admin appears as a visually separated navigation item with a shield icon; page content uses a two-column command grid where space permits.
- Telegram/mobile: retain sticky header and bottom navigation. Admin replaces overflow with a concise shield tab for authorized admins; cards stack vertically.
- Each method card has a recognizable icon, short title, an adjacent circular info icon, and a concise explanatory tooltip/popover.
- Every parameter has a persistent visible label, example/placeholder, validation hint, and appropriate input type (number, text, select, textarea, searchable client/device selector).
- Primary actions use the brand gradient. Secondary actions use navy surfaces and violet borders.
- Destructive actions use the danger accent, require a confirmation dialog, and state the exact target.
- Broadcast and server state changes also require confirmation.
- Results appear inline with success/error status, human-readable summary, and collapsible technical output where relevant.
- Loading disables the current method only. Never freeze the whole page.
- Use accessible labels, keyboard focus, 44px minimum touch targets, and no information conveyed by color alone.

## Security cues
Do not imply that the UI itself grants authority. Role and permissions come from the API. Never expose bot tokens, server secrets, raw Telegram initData, or session cookies. Owner-only admin management is distinct from normal operational commands.

## Motion
Use the existing subtle 180–200ms transitions. Tooltips/popovers fade and translate by a few pixels. Confirmation dialogs/sheets enter with the existing bottom-sheet behavior on mobile and centered-dialog behavior on desktop.

## Hard constraints
Use ONLY the fonts, colors, spacing, and component styles defined in the existing design system and `webapp/src/index.css`. Do not introduce new fonts, colors, gradients, glassmorphism styles, or unrelated dashboard conventions.
