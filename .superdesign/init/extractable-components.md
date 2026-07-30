# Extractable components

## AppShell
- Source: `webapp/src/App.tsx`
- Category: layout
- Description: Sticky header, account identity, desktop sidebar, mobile bottom navigation, and page content shell.
- Extractable props: activeItem, userName, photoUrl, isTelegramMiniApp
- Hardcoded: DHQ Clash logo, navigation visual treatment, shell CSS.

## BrandMark
- Source: `webapp/src/components/BrandMark.tsx`
- Category: basic
- Description: Gradient DHQ Clash brand glyph.
- Extractable props: className
- Hardcoded: SVG geometry and brand gradients.

## Icon
- Source: `webapp/src/components/Icons.tsx`
- Category: basic
- Description: Shared stroke icon renderer.
- Extractable props: name, size, className
- Hardcoded: SVG path map and stroke treatment.

## ContentCard
- Source: `webapp/src/index.css` + usages in `webapp/src/screens/*.tsx`
- Category: basic
- Description: Rounded bordered surface with eyebrow, title, optional icon and actions.
- Extractable props: eyebrow, title, icon, accent, children
- Hardcoded: surface, border, radius, shadow.

## ActionRow
- Source: `webapp/src/index.css` + usages in `webapp/src/screens/Help.tsx`
- Category: basic
- Description: Full-width navigational or command action row.
- Extractable props: icon, title, description, disabled
- Hardcoded: chevron/action layout and hover behavior.

## AdminMethodCard
- Source: new target
- Category: basic
- Description: Compact command card with icon, title, info tooltip, labeled parameters, submit action, and inline result.
- Extractable props: title, description, icon, danger, busy, result
- Hardcoded: design tokens and field spacing.

## ConfirmationDialog
- Source: new target
- Category: basic
- Description: Explicit confirmation for destructive or broadcast admin actions.
- Extractable props: title, consequence, confirmLabel, danger
- Hardcoded: modal structure and backdrop.
