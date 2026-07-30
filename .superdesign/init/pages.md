# Page dependency trees

## App shell and authentication
Entry: `webapp/src/main.tsx`
- `webapp/src/App.tsx`
  - `webapp/src/components/BrandMark.tsx`
  - `webapp/src/components/Icons.tsx`
  - `webapp/src/components/ErrorBoundary.tsx`
  - `webapp/src/components/WebLogin.tsx`
    - `webapp/src/components/BrandMark.tsx`
    - `webapp/src/api.ts`
  - `webapp/src/api.ts`
  - `webapp/src/platform.ts`
  - all screen entries below
- `webapp/src/index.css`

## Devices
Entry: `webapp/src/screens/Dashboard.tsx`
- `webapp/src/api.ts`
- `webapp/src/format.ts`
- `webapp/src/components/BrandMark.tsx`
- `webapp/src/components/Icons.tsx`
- `webapp/src/platform.ts`

## Subscription
Entry: `webapp/src/screens/Buy.tsx`
- `webapp/src/api.ts`
- `webapp/src/format.ts`
- `webapp/src/components/Icons.tsx`
- `webapp/src/platform.ts`

## Referrals
Entry: `webapp/src/screens/Referrals.tsx`
- `webapp/src/api.ts`
- `webapp/src/components/Icons.tsx`

## Installation
Entry: `webapp/src/screens/Guides.tsx`
- `webapp/src/api.ts`
- `webapp/src/components/Icons.tsx`

## Support
Entry: `webapp/src/screens/Help.tsx`
- `webapp/src/api.ts`
- `webapp/src/components/Icons.tsx`
- `webapp/src/components/SupportButton.tsx`
- `webapp/src/platform.ts`

## Admin (new target)
Planned entry: `webapp/src/screens/Admin.tsx`
- `webapp/src/api.ts`
- `webapp/src/components/Icons.tsx`
- new reusable admin method card, labeled input, tooltip, confirmation dialog, result panel
- existing `webapp/src/App.tsx` shell and `webapp/src/index.css` tokens
