# COMPLETE AI DESIGN PROMPT — Merchant Data-to-Lending App (Ecuador)

> **How to use this prompt:** Paste the entire document into any AI design or coding tool (Claude, Cursor, v0, Bolt, Lovable, GPT). It contains the full spec, every screen, every flow, and built-in self-checks the AI must run before moving to the next screen. For Flutter code generation, paste into Cursor or Claude Code. For visual mockups, paste into v0 or Figma AI.

---

## CONTEXT — Read this first. Do not skip.

You are designing a mobile app for micro and small merchants in Ecuador. These merchants sell from tiendas (corner stores), market stalls, street carts, and small shops. Most do 60–80% of sales in cash. Many track informal credit ("fiado") in paper notebooks. They use Deuna (QR payments) and PayPhone (card payments) but no single app shows them their full business picture.

This app does three things:
1. **Unifies all sales data** — digital payments (Deuna, PayPhone) + cash + informal credit — into one dashboard
2. **Replaces the paper fiado notebook** with a digital tracker
3. **Uses 90+ days of that combined data to offer small business loans** ($300–$800) that repay automatically as a percentage of digital sales

The app is built in **Flutter** (cross-platform, offline-first). The primary market is Ecuador (Spanish-language, USD currency, spotty connectivity in smaller cities). Users have low-to-mid smartphone literacy — they can use WhatsApp and TikTok but have never used a "business app." The interface must be radically simple.

### The user is NOT a tech person. Design rules:
- No jargon. "Ventas del día" not "Daily Revenue Analytics"
- Maximum 2 actions per screen. If a screen asks the user to do 3 things, split it.
- Thumb-zone design — primary actions in the bottom 40% of the screen
- Large tap targets — minimum 48x48dp, preferably 56x56dp for primary actions
- High contrast text — WCAG AA minimum on all screens
- Offline-first — every screen except loan disbursement must work without internet
- The app must feel fast even on a $120 Android phone with 2GB RAM

---

## DESIGN SYSTEM

### Colors
```
Primary:        #1B6B4A  (deep green — trust, money, growth)
Primary Light:  #E8F5EE  (green tint for backgrounds)
Accent:         #D4924F  (warm copper — highlights, CTAs, money amounts)
Accent Light:   #FFF3E6  (copper tint)
Danger:         #C0392B  (overdue, warnings)
Danger Light:   #FDEDEB
Success:        #27AE60  (paid, confirmed)
Surface:        #FFFFFF  (card backgrounds)
Background:     #F7F6F3  (page background — warm, not clinical)
Text Primary:   #1A1D23
Text Secondary: #6B7280
Text Disabled:  #B0B5BD
Border:         #E5E7EB
```

### Dark Mode
```
Primary:        #3DBB7A
Primary Light:  rgba(61,187,122,0.12)
Accent:         #E8A85C
Accent Light:   rgba(232,168,92,0.10)
Surface:        #1E2128
Background:     #14171C
Text Primary:   #E8E6E0
Text Secondary: #9A9DA3
Border:         rgba(255,255,255,0.08)
```

### Typography
```
Display/Headers:  Google Sans or Inter — Bold, 20–28sp
Body:             Inter — Regular 16sp, line-height 1.5
Caption:          Inter — Medium 12sp, letter-spacing 0.04em, uppercase for labels
Money amounts:    JetBrains Mono or Space Mono — Medium, 24–40sp (tabular nums)
```

### Spacing Scale
```
4dp — micro gap
8dp — tight
12dp — compact
16dp — standard
24dp — section gap
32dp — major section
48dp — screen-level breathing room
```

### Component Rules
- Cards: 12dp radius, 1px border (no drop shadow — saves GPU on cheap phones)
- Buttons: 48dp height minimum, 12dp radius, full-width for primary actions
- Bottom Navigation: 56dp height, 5 tabs, icon + label always visible (label-only on active tab below 360dp width)
- Snackbars: appear at bottom, 3-second auto-dismiss, never block navigation
- Modals: use bottom sheets (not center modals) — they're easier to reach and dismiss
- **No emoji anywhere in the UI.** Every icon is a stroke SVG (1.7–1.9px, currentColor)
  from one sprite. Emoji render differently on every Android skin, break at small sizes,
  and read as unserious in a product that handles money.

---

## SCREEN INVENTORY — 14 Screens + 1 System Behavior

### SCREEN MAP
```
01 Onboarding (3 slides)
02 Setup / Create Account
        ↓
03 Home Dashboard  ─────────────────────────────────┐
    ├── 04 Cash Log                    ← "＋ Venta"  │
    ├── 08 Historial      ← sales card / "Ver todo" / tab
    ├── 13 Notifications  ← bell icon                │
    │                                                │
    ├── 05 Libreta (Fiado Tracker)      [tab]        │
    │      ├── 06 New Fiado Entry       ← FAB        │
    │      └── 07 Customer Detail       ← row tap    │
    │                                                │
    ├── 09/10/11 Mi Crédito             [tab]        │
    │      ├── 09 Pre-Qualification  (< 90 active days)
    │      ├── 10 Loan Offer         (qualified)     │
    │      └── 11 Active Loan Status (borrowed)      │
    │                                                │
    └── 12 Perfil                       [tab] ───────┘
           └── 14 Connected Accounts

+ Offline / Connectivity — system behavior, not a screen
```
Screens 09, 10 and 11 are three states of the same "Crédito" tab, never
reachable simultaneously.

### BOTTOM NAVIGATION (persistent on all main screens):
```
[ Inicio ]  [ Libreta ]  [ Historial ]  [ Crédito ]  [ Perfil ]
```
- 5 tabs. Active tab = primary green icon + label. Inactive = gray.
- The "Crédito" tab shows a subtle badge/dot after 90 days when a loan offer is available.
- On screens narrower than 360dp, labels are hidden and only icons show. Labels reappear on the active tab.

---

## SCREEN 01 — Onboarding (3 value-prop slides)

### Purpose
Get the merchant from install to first value in under 3 minutes. Collect only what's legally required (name, phone, business type). Do NOT ask for email — many merchants don't have one.

### Slide 1: Value Prop
- Illustration: a merchant looking at their phone with a simple bar chart
- Headline: "Todas tus ventas en un solo lugar"
- Subtext: "Efectivo, QR, tarjeta y fiado — todo junto."
- Button: "Empezar" (full-width, primary green)

### Slide 2: Value Prop
- Illustration: a paper notebook transforming into a phone screen
- Headline: "Tu libreta, pero digital"
- Subtext: "Lleva el fiado de tus clientes sin perder la cuenta."
- Button: "Siguiente"

### Slide 3: Value Prop
- Illustration: money/coins growing
- Headline: "Accede a crédito cuando lo necesites"
- Subtext: "Usa tus ventas como historial. Sin papeleo."
- Button: "Crear mi cuenta"

---

## SCREEN 02 — Setup / Create Account

### Purpose
Collect the minimum required to create a local profile. In v1 this is device-local only — see MVP note at the end of this document.

### Fields
- **Phone number input** (Ecuador +593 format, auto-formatted)
- **OTP verification** (6-digit code via SMS)
- **Business name** (text field, required, max 40 chars)
- **Your name** (text field, required)
- **Business type** picker: Tienda / Restaurante / Mercado / Servicios / Otro
- **City** picker: Quito / Guayaquil / Esmeraldas / Cuenca / Otro
- Button: "Listo" → goes to Dashboard

### What NOT to ask during onboarding:
- Email (optional, add later in Profile)
- Cédula / ID number (only needed for loan application, asked at that point)
- Business registration / RUC (not required for free tools)
- Bank account (only needed for loan disbursement)

### VERIFICATION CHECKPOINT 01–02:
```
□ Can a merchant complete onboarding in under 3 minutes?
□ Does the setup screen work offline? (It should NOT — OTP requires SMS. This is the ONE screen that needs connectivity. Show a clear "Necesitas internet para registrarte" message if offline.)
□ Is every field necessary? Remove any field that isn't needed for the free tools.
□ Are tap targets ≥48dp?
□ Is the phone input formatted for Ecuador (+593)?
□ Can the user go back to fix a previous slide without losing input?
□ Does the business type picker cover 95% of merchants? (Tienda covers corner stores, Mercado covers market stalls, Servicios covers barbers/mechanics/etc.)
```

---

## SCREEN 03 — Home Dashboard

### Purpose
Answer one question in 2 seconds: "How is my business doing today?" This is the screen merchants see every time they open the app. It must load instantly (cached local data) and feel alive.

### Layout (top to bottom):
1. **Greeting bar** (top, 48dp height)
   - "Hola, [Name]" — left-aligned
   - Notification bell icon — right-aligned (shows dot if unread). **Tapping the bell opens the Notifications screen (Screen 13).**
   - Current date: "Martes, 2 de septiembre"

2. **Today's Sales Card** (hero card, prominent)
   - Large number: "$127.50" (JetBrains Mono, 36sp, accent copper color)
   - Label above: "VENTAS DE HOY" (caption style, 12sp)
   - Breakdown row below the number (4 categories — all must be shown):
     - QR: $45.00 | Tarjeta: $32.50 | Efectivo: $35.00 | Cobros fiado: $15.00
   - The sum of all 4 categories MUST equal the hero number ($127.50). If any category is $0 today, still show it as "$0.00" so the breakdown is always complete.
   - Small trend indicator: "↑ 12% vs ayer" (green if up, red if down, gray if no yesterday data)
   - **Tapping the sales card opens Historial (Screen 08) filtered to today.**

3. **Weekly Mini Chart** (simple bar chart, 7 bars for last 7 days)
   - Today's bar is accent color, others are muted
   - Labels: L M M J V S D (Spanish day abbreviations)
   - Tapping a bar shows that day's total in a tooltip
   - If less than 7 days of data, show only available days + gray placeholder bars
   - "Ver todo →" link below chart → opens Historial (Screen 08) unfiltered

4. **Quick Actions Row** (2 large buttons, equal width, side by side)
   - "＋ Venta" (primary green) → opens Cash Log
   - "＋ Fiado" (outline style) → opens Libreta > New Entry

5. **Fiado Summary Card** (if merchant has active fiados)
   - "Te deben: $85.00" (accent color)
   - "[4 clientes] con deuda pendiente"
   - Tap → goes to Libreta

6. **Sync Status Bar** (bottom of scroll, subtle) — *Phase 2; omit in v1, data is device-local*
   - If synced: "Actualizado hace 5 min" (small gray text + green dot)
   - If unsynced: "3 ventas pendientes de sincronizar" (orange text + sync icon)
   - Tap → forces sync attempt

### VERIFICATION CHECKPOINT 03:
```
□ Does the dashboard load in <1 second from local cache?
□ Is the sales total accurate? It must sum: Deuna QR + PayPhone card + manually logged cash + fiado payments received today. ALL FOUR categories.
□ Does the breakdown row show ALL 4 categories? The 4 numbers in the breakdown MUST add up to the hero total. If a category is $0, show it as "$0.00" — never hide it.
□ CRITICAL — Fiado payment double-counting guard: When a customer pays a fiado in cash, the merchant records it ONLY via "Registrar pago" on the Customer Detail screen. This counts as "Cobros fiado" in the breakdown, NOT as "Efectivo." The Cash Log screen must show a warning if a payment amount + timing matches a recent fiado payment: "¿Ya registraste esto como pago de fiado?" to prevent logging it in both places.
□ What does the dashboard show on Day 1 with zero data? (It should show $0.00 with the quick action buttons prominent — NOT an empty state with "no data yet." The buttons ARE the content.)
□ Does the weekly chart handle missing days gracefully?
□ Is the "Te deben" fiado amount the sum of ALL outstanding fiados, not just today's?
□ Does the sync bar accurately reflect local vs synced state?
□ Can the merchant reach the Cash Log in ONE tap from here?
□ Can the merchant reach Historial in ONE tap? (Yes — tap the sales card, or tap "Ver todo" under the chart, or use the Historial tab in bottom nav.)
□ Does tapping the notification bell open the Notifications screen?
□ Are money amounts right-aligned and using tabular figures?
□ Does the trend percentage compare today-so-far to same-point-yesterday (not full-day yesterday)?
```

---

## SCREEN 04 — Cash Log

### Purpose
Log a cash sale in under 3 seconds. This replaces per-sale tracking with a quick-tap approach. The merchant can either tap preset amounts OR enter a custom amount. Also supports end-of-day reconciliation.

### Layout:
1. **Header**: "Registrar Venta en Efectivo" + back arrow

2. **Amount Display** (large, center)
   - Shows the amount being entered: "$0.00" → updates as tapped
   - JetBrains Mono, 40sp, centered

3. **Preset Amount Grid** (3 columns × 3 rows)
   ```
   [$0.50]  [$1.00]  [$2.00]
   [$5.00]  [$10.00] [$20.00]
   [$50.00] [$100]   [Otro]
   ```
   - Each button: 64dp height, 12dp radius, outlined style
   - Tapping ADDS that amount (so tapping $5 then $2 = $7.00 displayed)
   - "Otro" opens a numeric keypad for custom entry
   - Long-press on any preset → edit its value (merchant customizes their common amounts)

4. **Note field** (optional, collapsible)
   - "Agregar nota..." placeholder
   - Examples: "3 almuerzos", "pan + gaseosa"
   - Max 80 chars. Not required. (Same limit as fiado notes — this is a shared component.)

5. **Action Buttons** (bottom)
   - "Guardar" (primary, full-width) — saves the sale, shows snackbar "Venta guardada", returns to Dashboard
   - "Limpiar" (text button, below) — resets amount to $0.00

6. **Alternative Mode: End-of-Day Reconciliation**
   - Toggle at top: "Venta individual" | "Cierre del día"
   - In "Cierre del día" mode:
     - Single input: "¿Cuánto efectivo tienes en caja?"
     - App subtracts the morning float (set once in Profile, default $0)
     - Shows: "Ventas en efectivo hoy: $[calculated]"
     - "Guardar cierre" button
   - **CRITICAL — Interaction between modes:** If any individual cash sales were logged earlier today, "Cierre del día" shows a warning: "Ya registraste $[X] en ventas individuales hoy. El cierre del día REEMPLAZA esas ventas, no se suma." Saving the end-of-day reconciliation REPLACES all individual cash sales for that day with the single reconciliation total. This prevents double-counting. The replaced individual entries are kept in history as "Reemplazado por cierre del día" (grayed out, not deleted, for audit purposes).

### Offline behavior:
- Fully functional offline. Sales save to local SQLite with timestamp.
- Queued for sync with green checkmark locally, orange clock if unsynced.

### VERIFICATION CHECKPOINT 04:
```
□ Can a merchant log a $2.50 sale in under 3 seconds? (Tap $2.00, tap $0.50, tap Guardar = 3 taps, done.)
□ Does tapping preset amounts ADD to the running total (not replace)?
□ Is there a clear way to UNDO an accidental tap before saving? (The "Limpiar" button resets.)
□ Does the "Otro" custom entry use a numeric keypad (not a full keyboard)?
□ Does the end-of-day mode correctly calculate: cash in drawer − morning float = day's cash sales?
□ What happens if the merchant enters a cash amount of $0? (Block save, show "Ingresa un monto" hint.)
□ What happens if they enter $50,000? (Allow it — some merchants sell high-value goods. No artificial cap.)
□ Does the saved sale immediately appear in the Dashboard total?
□ Does the note field accept Spanish characters (ñ, á, é, í, ó, ú)?
□ Are the preset amounts customizable per merchant via long-press?
```

---

## SCREEN 05 — Libreta (Fiado Tracker) — Customer List

### Purpose
Show all customers who owe the merchant money, sorted by who owes the most. This replaces the paper notebook and is the primary retention hook of the app.

### Layout:
1. **Header**: "Mi Libreta" + search icon (right)

2. **Summary Bar** (sticky top)
   - "Total pendiente: $285.00" (large, accent copper)
   - "[12 clientes]" — count of customers with outstanding debt

3. **Customer List** (scrollable)
   Each row:
   ```
   [Avatar circle: first letter]  María González       $45.00
                                   Última compra: hace 2 días
   ```
   - Sorted by: highest debt first (default). Toggle to sort by most recent.
   - Avatar: first letter of name on a colored circle (color generated from name hash — deterministic, so same customer always gets same color)
   - Debt amount: right-aligned, accent copper if current, danger red if >30 days
   - Tap → goes to Customer Detail screen

4. **FAB (Floating Action Button)** — bottom right
   - "+" icon → opens "Add new fiado" flow
   - Primary green, 56dp, elevated

5. **Empty State** (if no fiados yet)
   - Illustration: a clean notebook
   - Text: "Tu libreta está limpia"
   - Subtext: "Toca + para registrar un fiado"

### VERIFICATION CHECKPOINT 05:
```
□ Does the total pendiente sum ALL outstanding debts across ALL customers?
□ Is sorting intuitive? Highest debt first makes sense — the merchant wants to see who owes the most.
□ Does the search work offline? (Yes — searches local database.)
□ What happens with 100+ customers? (Virtual scrolling / lazy loading from SQLite. No jank.)
□ Does the avatar color stay consistent for the same customer name?
□ Can the merchant distinguish between María González and María García? (Show last name, or if same last name, show amount + date as differentiator.)
□ Does the "última compra" date update when a new fiado is added for that customer?
□ Is the danger-red color for >30 days debts accessible (sufficient contrast)?
```

---

## SCREEN 06 — Libreta — New Fiado Entry

### Purpose
Log an informal credit in 4 taps: select customer → enter amount → optional note → save.

### Flow:
1. **Customer Selection**
   - Recent customers shown first (last 5)
   - Search bar for existing customers
   - "+ Nuevo cliente" button at top of list
   - New customer: name only (required). Phone optional. No address, no ID.

2. **Amount Entry**
   - Same numeric input as Cash Log (preset grid + custom)
   - Label: "¿Cuánto le fiaste?"

3. **Note** (optional)
   - "¿Qué le vendiste?" — e.g., "2 libras de arroz, aceite"
   - Max 80 chars

4. **Confirmation**
   - Summary card: "[Customer] te debe $[amount]"
   - "Guardar" button
   - Snackbar: "Fiado registrado"

### Navigation:
- **Back button** at each step returns to the previous step without losing input.
- **X (close) button** in the header cancels the entire flow. If any data has been entered, show confirmation: "¿Descartar este fiado?" with "Descartar" and "Seguir editando" options.
- After saving, returns to the Libreta Customer List.

### VERIFICATION CHECKPOINT 06:
```
□ Can a new fiado be logged in 4 taps or fewer for an existing customer?
□ Does creating a new customer require only a name? (Yes — phone is optional.)
□ If the customer already has a balance, does the new fiado ADD to it?
□ What if the merchant types a customer name that's similar to an existing one? (Show "¿Es esta persona?" suggestion with existing match before creating a duplicate.)
□ Does this work fully offline?
□ Is the amount input the same component as Cash Log? (Yes — reuse, don't rebuild.)
```

---

## SCREEN 07 — Libreta — Customer Detail

### Purpose
See everything about one customer's fiado history: what they owe, what they bought, when they paid. Let the merchant mark debts as paid.

### Layout:
1. **Customer Header**
   - Name, phone (if provided), avatar circle
   - Total owed: "$45.00" (large, accent)

2. **Transaction List** (chronological, newest first)
   Each entry:
   ```
   Fiado  $15.00 — "arroz y aceite"            Sep 1    saldo $45.00
   Pagó  −$10.00                                Ago 28   saldo $30.00
   Fiado  $25.00 — "gas"                        Ago 25   saldo $40.00
   Pagó  −$25.00                                Ago 20   saldo $15.00
   Fiado  $40.00 — "víveres de la semana"       Ago 15   saldo $40.00
   ```
   - Fiados: neutral text, muted color
   - Payments: green text, check icon
   - Running balance shown beside each entry

3. **Action Buttons** (sticky bottom)
   - "Registrar pago" (primary green, full-width) → amount input, defaults to total owed
   - "Nuevo fiado" (outline) → new fiado entry flow, customer pre-selected

4. **Partial Payment Support**
   - When tapping "Registrar pago", amount field pre-fills with total owed
   - Merchant can change to any amount ≤ total owed
   - If partial: "Pago parcial: $10.00. Queda: $35.00" confirmation

### VERIFICATION CHECKPOINT 07:
```
□ Does the running balance accurately reflect fiados minus payments?
□ Can the merchant record a partial payment? (Yes — they can change the pre-filled amount.)
□ What if total owed is $0 and merchant taps "Registrar pago"? (Disable the button, show "No hay deuda pendiente.")
□ Can the merchant delete a fiado entry they logged by mistake? (Yes — swipe left to delete, with confirmation: "¿Eliminar este registro?" This only works within 24 hours of logging.)
□ Does this screen load fast with 200+ entries for a long-term customer? (Paginate: show last 30 entries, "Ver más" button.)
□ Is the chronological order correct? Newest on top.
□ Does recording a payment update ALL THREE places that show debt totals? (1) This customer's balance on this screen, (2) the "Total pendiente" on the Libreta Customer List summary bar, and (3) the Dashboard's "Te deben" card. All three must update immediately from the same local database query.
□ Does a fiado payment also appear in the Dashboard's "Cobros fiado" breakdown and add to the day's total sales?
```

---

## SCREEN 08 — Transaction History (Historial)

### Purpose
Detailed chronological record of ALL transactions across all channels. Filterable. This is the "proof" screen — the merchant uses it to verify what happened.

### Layout:
1. **Header**: "Historial" + filter icon (right)

2. **Filter Bar** (horizontal scroll chips):
   ```
   [Todos] [Efectivo] [QR] [Tarjeta] [Fiado]
   ```
   - Active chip: filled primary green
   - Inactive: outline
   - Date range picker accessible via calendar icon

3. **Daily Groups** (list, grouped by day):
   ```
   ── Hoy, 2 de septiembre ──────── Total: $127.50
   
   15:10  QR Deuna      $25.00
   14:32  Efectivo      $22.50   "almuerzos y bebidas"
   13:10  QR Deuna      $20.00
   11:45  PayPhone      $32.50
   10:20  Efectivo      $12.50   "pan, huevos"
   09:05  Fiado dado    $15.00   → María González     [NO suma al total]
   08:30  Cobro fiado   $15.00   ← Juan Pérez         [SÍ suma al total]
   ```
   Sum check: $25.00 + $22.50 + $20.00 + $32.50 + $12.50 + $15.00 = $127.50 ✓
   Reconciles to Screen 03 breakdown: QR $45.00 · Tarjeta $32.50 · Efectivo $35.00 · Cobros fiado $15.00 ✓
   (New fiados issued are NOT income — they're money lent out. Only fiado payments RECEIVED are income.)
   
   - Each row: time, channel icon, amount, optional note/customer
   - Daily total shown in section header = cash sales + QR + card + fiado payments received. New fiados issued are listed for visibility but excluded from the total.
   - Fiado entries link to the customer detail
   - New fiados ("Fiado dado") shown in muted text color to visually distinguish from income rows

4. **Export** (subtle, in header overflow menu):
   - "Exportar CSV" — generates a CSV file of filtered transactions
   - "Compartir resumen" — generates a WhatsApp-shareable text summary

### VERIFICATION CHECKPOINT 08:
```
□ Are transactions sorted newest-first within each day?
□ Does filtering by channel instantly update the daily totals?
□ Does "Fiado" filter show BOTH new fiados AND fiado payments?
□ Can the merchant find a specific transaction from 2 months ago? (Scrolling + date range filter.)
□ What does the history show on Day 1? (Empty state: "Aún no hay transacciones. Registra tu primera venta." with arrow pointing to the + button.)
□ Does the CSV export include ALL fields: date, time, channel, amount, note, customer?
□ Is the WhatsApp summary formatted as plain text that renders well in a WhatsApp message?
□ Does the history include synced Deuna/PayPhone transactions alongside manually logged ones?
□ Are Deuna/PayPhone transactions clearly marked with their source?
□ Does this screen perform well with 10,000+ transactions? (Virtual scrolling, load 50 at a time.)
```

---

## SCREEN 09 — Mi Crédito (Loans) — Pre-Qualification

### Purpose
Before 90 days of data: explain that credit is coming and show progress toward qualification. After 90 days: show the loan offer.

### Pre-Qualification State:

**How the counter works:** The counter counts ACTIVE DAYS — days where the merchant logged at least one transaction (cash sale, fiado entry, fiado payment, or a synced Deuna/PayPhone transaction). Calendar days without activity don't count. First-time qualification requires 90 active days. Repeat borrowers (who fully repaid a previous loan) require only 30 active days.

1. **Progress Ring** (center, large)
   - Circular progress: "47 de 90 días activos"
   - Inside ring: "Tu historial se está construyendo"
   - The label says "días activos" (not "días"), making clear that these are activity-counted days.

2. **What We're Tracking** (3 mini cards):
   ```
   Ventas registradas: 312
   Días activos: 47
   Cobros de fiado: 89% (por monto en $)
   ```

3. **Explainer text:**
   "Mientras más registros tengas, mejor será tu oferta de crédito. Sigue usando la app normalmente — nosotros te avisamos cuando tengas una oferta."

4. **No CTA button.** Don't let them "apply" — the offer comes to them.

### Post-Decline State:
If the merchant declined a loan offer, this screen shows:
- "Tu oferta de crédito está disponible de nuevo en [X] días"
- Countdown to next offer (30 days from decline date)
- The same 3 tracking cards continue updating in the background
- When the countdown expires, the screen transitions to the Loan Offer (Screen 10) with a refreshed offer based on latest data

### Repeat Borrower State:
After fully repaying a loan, the merchant sees:
- "¡Felicidades! Tu crédito anterior está pagado."
- Progress ring restarts with 30 active days (not 90)
- "Tu siguiente oferta estará lista pronto"

### VERIFICATION CHECKPOINT 09A:
```
□ Does the counter count ACTIVE DAYS (days with ≥1 logged transaction), NOT calendar days?
□ Does the progress ring update on each day that has activity?
□ What if the merchant stops using the app for 2 weeks? (Counter pauses — no new active days added. Show: "Llevas 15 días sin registrar ventas. Tu progreso se pausó." Not punitive — informational.)
□ Is there any way to "game" the system by inflating cash sales? (Yes, cash is self-reported and unverifiable — assume some merchants will inflate it. The defense is structural, not detective: **loan size is capped by digital revenue, not by total reported revenue.** `max_loan = min(30% of 90-day total revenue, 8× average daily digital revenue)`. Repayment only ever happens via the 10% auto-deduction on Deuna/PayPhone transactions — cash can never be auto-deducted — so the second term is what actually protects the lender. A merchant with fabricated cash and near-zero real digital volume caps out near the $300 floor no matter what she claims, because that's roughly what a trickle of real digital sales could plausibly repay in 90 days. Full $800 offers are only reachable with real digital volume behind them, which is the one number in the system that isn't self-reported — it comes from the Deuna/PayPhone transaction APIs directly.)
□ Can the merchant game fiado? (Partially. A merchant could create fake customers and fake fiado entries. Mitigation: fiado-only data without ANY real payment channel data (Deuna/PayPhone/bank) carries the lowest credit weight, and is subject to the same digital-revenue cap above — fake fiado inflates the "revenue" term but not the "average daily digital revenue" term, so it cannot raise the loan ceiling on its own.)
□ Are there secondary fraud signals beyond the structural cap? (Three, all computable without a bank integration: (1) peer benchmarking — flag a merchant's reported cash-per-day against the median for her business type and city; (2) shape-of-data — real daily cash sales are noisy, fabricated entries tend to be round numbers or suspiciously low-variance across the 90-day window; (3) cross-checking cash claims against her own fiado and foot-traffic pattern, which should scale together. None of these are auto-decline triggers — they route a merchant to manual review before her first loan, not after.)
□ Does the "89%" fiado metric represent dollars? (Yes — sum of fiado payments received in $ ÷ sum of fiados issued in $. NOT a count of entries. A $5 fiado repaid and a $500 fiado defaulted = 1% by dollar value, not 50% by count.)
□ Does the post-decline state correctly show the 30-day countdown?
□ Does the repeat-borrower state correctly show 30 active days instead of 90?
□ What happens if a loan offer expires without action? (Offer auto-refreshes every 30 days with updated data. The offer amount may change. The merchant is never penalized for inaction — the offer just updates.)
```

---

## SCREEN 10 — Mi Crédito — Loan Offer

### Purpose
Present a clear loan offer the merchant can accept in one tap. No hidden fees. No fine print tricks.

### Layout:
1. **Celebration Header**
   - "¡Tienes una oferta de crédito!" (serif, large)
   - Subtle confetti animation on first view only (respects prefers-reduced-motion)

2. **Offer Card** (hero card, bordered in accent copper):
   ```
   MONTO DISPONIBLE
   $800.00
   
   Costo total del crédito:  $852.00
   Comisión fija:            $52.00 (6.5%)
   Plazo:                    90 días
   Pago:                     10% de tus ventas digitales diarias
   ```
   - All numbers in monospace, right-aligned
   - "Comisión fija" — NOT "interest rate." This is a flat fee, not compounding interest. Make this clear.

3. **Slider** (optional — lets merchant choose a smaller amount):
   - Range: $300 — $800 (based on their qualifier max)
   - Moving the slider recalculates the fee proportionally
   - Fee percentage stays constant (6.5%), absolute amount changes

4. **What You Need to Know** (expandable section):
   - "¿Cómo pago?" → "Se descuenta automáticamente el 10% de cada venta que recibas por Deuna o PayPhone. Si vendes $50 hoy, $5 van al pago."
   - "¿Qué pasa si tengo un día malo?" → "Pagas menos. Si no vendes nada un día, no pagas nada ese día."
   - "¿Hay penalidades?" → "No. Sin multas, sin intereses extra. El costo es $52 sin importar cuánto tardes."
   - "¿Puedo pagar antes?" → "Sí. El costo no cambia, pero quedas libre más rápido."

5. **Requirements Checklist** (must complete before accepting):
   ```
   [x] Número de cédula verificado
   [x] Cuenta bancaria conectada
   [ ] Aceptar términos del crédito
   ```
   - If cédula not yet provided: inline input field
   - If bank not connected: link to Connected Accounts screen
   - Terms: short, plain-Spanish document (not a 40-page legal PDF)

6. **CTA:**
   - "Solicitar $800.00" (primary green, full-width, 56dp height)
   - Below: "Recibirás el dinero en tu cuenta en 24 horas"

### VERIFICATION CHECKPOINT 10:
```
□ Is the total cost (amount + fee) shown BEFORE the CTA? (Yes — no surprises after tapping.)
□ Does the slider update ALL numbers in real time?
□ At the minimum loan amount ($300), is the fee still worth the merchant's time? ($300 × 6.5% = $19.50 fee. Merchant receives $300. Yes — $19.50 is nothing compared to chulco's 103% monthly.)
□ Is the repayment explanation crystal clear? A merchant who has never had a formal loan should understand it in one reading.
□ Does the cédula input validate Ecuadorian ID format? (10 digits. First 2 digits = province code 01–24. Digit 3 must be 0–5 for natural persons. Validation uses Ecuador's Módulo 10 algorithm — NOT Luhn. The check digit is the 10th digit. Implement: multiply digits 1–9 by alternating coefficients [2,1,2,1,2,1,2,1,2], subtract 9 from any product >9, sum all products, check digit = (next multiple of 10 − sum) mod 10.)
□ What happens if the merchant's score drops between offer generation and acceptance? (Re-evaluate at submission time. If still qualified, approve. If not, show updated offer or "Tu oferta ha cambiado" with new terms.)
□ Does the 10% auto-deduction happen ONLY on Deuna/PayPhone transactions, NOT on cash? (Yes — cash can't be auto-deducted. This is clearly stated.)
□ Can the merchant decline the offer? (Yes — "No, gracias" text link below the CTA. Offer reappears in 30 days.)
□ Is the confetti animation skippable and motion-reduced? (Respects prefers-reduced-motion.)
□ Is 6.5% flat fee within Ecuador's legal interest rate cap for microcredit? (Yes — the Central Bank cap is ~28.5% annual; 6.5% flat on 90 days is well under.)
```

---

## SCREEN 11 — Mi Crédito — Active Loan Status

### Purpose
Show the merchant exactly where they stand on repayment. No anxiety — clarity.

### Layout:
1. **Progress Bar** (horizontal, large):
   - Shows: paid vs total owed (amount + fee)
   - "$312 / $852 pagado" (left-aligned)
   - "37% completado" (right-aligned) — calculated as $312 ÷ $852 = 36.6%, rounded to 37%
   - The progress bar fills left-to-right. The filled portion represents what's been paid.

2. **Key Numbers Row** (3 metrics):
   ```
   Desembolsado:    $800.00
   Pagado hasta hoy: $312.00
   Restante:         $540.00
   ```

3. **Daily Deductions List** (last 7 days):
   ```
   Hoy:     $8.50 descontado de 3 ventas
   Ayer:    $12.20 descontado de 5 ventas
   Lun:     $0.00 (no hubo ventas digitales)
   Dom:     $3.00 descontado de 1 venta
   ```

4. **Projected Payoff:**
   "A este ritmo, terminas de pagar alrededor del 18 de noviembre"
   - Calculated from average daily deduction over last 14 days

5. **Make Extra Payment** (optional button):
   "Hacer pago adicional" → enter amount → deducted from bank account

### VERIFICATION CHECKPOINT 11:
```
□ Does the progress bar update in real time as deductions happen?
□ Is the "projected payoff" recalculated daily based on recent activity?
□ What happens when the loan is fully paid? (Celebration screen: "¡Felicidades! Tu crédito está pagado." + "Tu siguiente oferta estará disponible pronto." Returns to pre-qualification screen with a faster countdown — 30 days instead of 90 for repeat borrowers.)
□ What if the merchant has zero digital sales for 30 days straight? (Show: "Tu pago está pausado porque no has tenido ventas digitales. El costo de tu crédito no cambia." Don't threaten. Don't penalize.)
□ Does the extra payment deduct from the REMAINING balance (not create a new transaction)?
□ Are all money amounts consistent — same font, same alignment, same decimal formatting?
```

---

## SCREEN 12 — Profile (Perfil)

### Purpose
Settings, account info, and the few configurations that exist.

### Layout:
1. **Profile Header:**
   - Avatar (first letter of name, colored circle)
   - Business name, merchant name
   - "Miembro desde septiembre 2026"

2. **Settings List:**
   ```
   Cuentas conectadas        → Connected Accounts screen
   Fondo de caja (float)     → Set morning cash float ($0 default)
   Montos rápidos            → Customize Cash Log preset grid
   Notificaciones            → Toggle: loan offers, sync reminders, fiado reminders
   Sincronización            → Toggle: "Solo con WiFi" (default ON) / "WiFi y datos móviles"
   Idioma                    → Español (only option for MVP — English later)
   Modo oscuro               → Toggle (or follow system)
   ```

3. **Data & Privacy:**
   ```
   Exportar mis datos        → Downloads full CSV of all data
   Restaurar datos           → [Phase 2] Login with phone + OTP on new device → restores from server
   Política de privacidad    → In-app viewer (plain Spanish)
   Eliminar mi cuenta        → Confirmation flow (see rules below)
   ```

4. **App Info:**
   - Version number
   - "Hecho en Ecuador"

### Account Deletion Rules:
- **No active loan:** Standard deletion. Show: "Esto borrará todas tus ventas, fiados e historial. No se puede deshacer." Deletes all data on server AND local device.
- **Active loan with unpaid balance:** Deletion is BLOCKED. Show: "No puedes eliminar tu cuenta mientras tengas un crédito activo. Tu saldo pendiente es $[X]. Paga tu crédito primero." The merchant must fully repay before deleting. This is a legal and financial requirement — the loan contract persists regardless of account status.

### Connected Account Disconnection During Active Loan:
- If the merchant tries to disconnect Deuna or PayPhone while a loan is active, show a warning: "Desconectar [Deuna/PayPhone] pausará el pago automático de tu crédito. Tendrás que hacer pagos manuales." Allow the disconnection (don't block it — the merchant may have a legitimate reason) but immediately show the "Hacer pago manual" button prominently on the Active Loan Status screen.

### Data Transfer to New Device: *(Phase 2 — in v1 data is device-only and merchants must be told so)*
- All merchant data syncs to the server during WiFi sync. On a new device, the merchant logs in with their phone number + OTP, and all data (sales, fiados, loan status, connected accounts) restores from the server backup. Connected Deuna/PayPhone accounts require re-authentication on the new device.

### VERIFICATION CHECKPOINT 12:
```
□ Can the merchant change their business name? (Yes — editable.)
□ Can they change their phone number? (Yes — requires new OTP verification.)
□ Is account deletion blocked during an active loan? (Yes — with clear explanation of why.)
□ Does the Deuna/PayPhone disconnection warning appear during an active loan?
□ Does "Restaurar datos" work on a new device after login? (Yes — pulls from server.)
□ Does the CSV export include ALL data: sales, fiados, payments, connected account transactions?
□ Is the cash float setting used by the end-of-day reconciliation in Cash Log?
□ Does the WiFi sync toggle exist and default to WiFi-only?
□ Does dark mode toggle immediately, or require a restart? (Immediately.)
```

---

## SCREEN 13 — Notifications

### Purpose
Show actionable alerts only. No noise.

### Notification Types (exhaustive list):
```
Loan offer available       → "¡Tienes una oferta de crédito por $800!"
Loan fully repaid          → "¡Tu crédito está pagado!"
Fiado overdue (>30 days)   → "Lucía Romero te debe $28 hace 35 días"
Sync error                 → "No hemos podido sincronizar con Deuna. Reconectar."
Weekly summary             → "Esta semana vendiste $625 — 8% más que la anterior"
```

### What is NOT a notification:
- Every sale logged (too noisy)
- Every fiado payment (too noisy)
- Marketing messages (never)
- "You haven't opened the app in 3 days" (manipulative — don't do this)

### VERIFICATION CHECKPOINT 13:
```
□ Can the merchant disable all notifications? (Yes — in Profile settings.)
□ Are notifications stored locally and visible even if the push notification was dismissed?
□ Do notification taps deep-link to the relevant screen?
□ Is the notification list sorted newest-first?
□ Is there a maximum number of notifications stored? (100 — older ones auto-delete.)
```

---

## SCREEN 14 — Connected Accounts

### Purpose
Link Deuna and PayPhone accounts so digital transaction data flows into the dashboard automatically.

### Layout:
1. **Header**: "Cuentas conectadas"

2. **Account Cards** (one per service):

   **Deuna Card:**
   ```
   [Deuna logo]  Deuna
   Estado: Conectado  |  Última sincronización: hace 10 min
   [Desconectar]
   ```
   OR if not connected:
   ```
   [Deuna logo]  Deuna
   Conecta tu cuenta para ver tus ventas por QR
   [Conectar Deuna →]
   ```

   **PayPhone Card:**
   ```
   [PayPhone logo]  PayPhone
   Estado: Conectado  |  Última sincronización: hace 3 horas
   [Desconectar]
   ```
   OR not connected:
   ```
   [PayPhone logo]  PayPhone
   Conecta tu cuenta para ver tus ventas con tarjeta
   [Conectar PayPhone →]
   ```

3. **Connection Flow** (when tapping "Conectar"):
   - Opens a webview or in-app browser for OAuth login
   - Merchant logs in with their existing Deuna/PayPhone credentials
   - Success: shows "Cuenta conectada" snackbar, returns to this screen
   - Failure: shows "No se pudo conectar. Intenta de nuevo." with retry button

4. **Bank Account Card** (only shown after loan offer is available):
   ```
   [Bank]  Cuenta bancaria (para recibir préstamos)
   Banco Pichincha - ****4521
   [Cambiar]
   ```

### VERIFICATION CHECKPOINT 14:
```
□ Does this screen work if the merchant has neither Deuna nor PayPhone? (Yes — shows both as "not connected" with clear CTAs to connect. The app is still useful with cash-only logging.)
□ What happens if OAuth fails? (Clear error, retry button, no crash.)
□ What happens if Deuna/PayPhone revokes access later? (Show "Reconectar" with an orange warning on the card.)
□ Is the bank account section HIDDEN until the merchant qualifies for a loan? (Yes — don't show financial features before they're relevant.)
□ Does connecting an account trigger an immediate first sync of historical data? (Yes — pull last 90 days if available.)
□ Can the merchant disconnect and reconnect without losing historical data? (Yes — local data stays; only new syncing stops/restarts.)
```

---

## SYSTEM BEHAVIOR — Offline / Connectivity States

### Purpose
Not a screen — a system behavior that shows across all screens.

### Rules:
1. **No internet, app works normally:** Cash Log, Libreta, Dashboard (from cached data) all function. No banner needed if the merchant isn't trying to do something that requires internet.

2. **Trying to do something that needs internet:**
   - Connecting Deuna/PayPhone → "Necesitas internet para conectar tu cuenta"
   - Accepting a loan → "Necesitas internet para solicitar el crédito"
   - OTP verification → "Necesitas internet para verificarte"
   - Shown as a bottom sheet with a "Reintentar" button

3. **Background sync available:**
   - When WiFi detected, auto-sync queued transactions
   - Brief snackbar: "Sincronizando 12 ventas..." → "Listo"
   - No interruption to what the merchant is doing

4. **Sync conflict resolution:**
   - If the same fiado entry was edited on two devices (unlikely but possible): last-write-wins, with a "Registro actualizado" note in history

### VERIFICATION CHECKPOINT — SYSTEM:
```
□ Does the app launch without internet? (Yes — always.)
□ Does the app EVER show a full-screen "No internet" blocker? (NO. Never. Only contextual messages when a specific action requires it.)
□ Does background sync happen only on WiFi (to save mobile data)? (Default: yes. Toggle in settings to allow mobile sync.)
□ Is the total data per sync tiny? (~10-15KB/day of text records. Even on a 500MB prepaid plan, a month of syncing uses <0.5MB.)
□ What happens if the phone runs out of storage? (SQLite is efficient — 1 year of daily transactions for an active merchant is <5MB. This will never be the bottleneck.)
```

---

## MASTER FLOW VERIFICATION

Run this checklist against the complete design. Every answer must be YES.

### Flow Integrity
```
□ Can a merchant go from install → first cash sale logged in <4 minutes?
□ Can a merchant log a cash sale from the Dashboard in 2 taps? (Quick Action → Preset → Save)
□ Can a merchant log a fiado in 4 taps? (Quick Action → Customer → Amount → Save)
□ Can a merchant see their total sales (all channels) in 1 tap? (Open app → Dashboard. Zero taps beyond launch.)
□ Can a merchant record a fiado payment in 3 taps? (Libreta → Customer → Registrar pago)
□ Can the merchant reach Historial from the Dashboard? (Yes — 3 paths: tap sales card, tap "Ver todo", or tap Historial tab in bottom nav.)
□ Can the merchant reach Notifications? (Yes — tap bell icon on Dashboard.)
□ Does every screen have a clear back path to the Dashboard?
□ Can the merchant reach any feature in ≤3 taps from the Dashboard?
□ Does the New Fiado Entry flow have a cancel/close button at every step?
```

### Data Integrity
```
□ If a merchant logs a $50 cash sale on Cash Log, does the Dashboard total increase by $50 immediately?
□ If a merchant records a fiado payment, does the Dashboard's "Te deben" amount decrease AND the "Cobros fiado" in the breakdown increase by the same amount?
□ If a merchant records a fiado payment, does it update in ALL THREE places: Customer Detail balance, Libreta summary bar "Total pendiente", and Dashboard "Te deben" card?
□ If Deuna reports a $22 QR payment via API, does it appear in both Dashboard and Historial?
□ Are all money amounts across all screens calculated from the same local database?
□ Is there any screen where a stale cached value could show a wrong total? (There should not be.)
□ Does deleting a mistaken entry propagate to all screens that showed it?
□ DOUBLE-COUNTING GUARD: Can a merchant log a fiado payment AND a cash sale for the same amount without a warning? (No — if a fiado payment and a cash sale are logged within 5 minutes for the same or similar amount, show: "¿Ya registraste esto como pago de fiado?" to prevent counting it twice.)
□ END-OF-DAY GUARD: Does the end-of-day reconciliation REPLACE individual cash entries for the same day (not add to them)?
□ FIADO IN TOTAL: Are new fiados EXCLUDED from the daily sales total? (Yes — fiados issued are money lent, not income. Only fiado payments received count as income.)
```

### UX Integrity
```
□ Is every primary action button at least 48dp tall?
□ Is every tap target at least 48x48dp?
□ Does every screen work in dark mode with sufficient contrast?
□ Does every screen work on a 5-inch, 720p screen without cropping or overlap?
□ Is every piece of text in Spanish (no English labels, no untranslated placeholders)?
□ Are all money amounts formatted consistently ($X.XX, USD, decimal point not comma)?
□ Does every destructive action (delete, disconnect, remove) have a confirmation step?
□ Is there loading feedback for every action that takes >300ms?
□ Are error messages specific? ("No se pudo conectar con Deuna" NOT "Error.")
□ Does the app use system haptic feedback on successful save actions? (Subtle vibration on save — confirmation without looking at the screen.)
□ Does the bottom nav work correctly with 5 tabs on a 360dp-wide screen? (Labels hide on narrow screens, showing only on the active tab.)
```

### Business Logic Integrity
```
□ The Dashboard total = Deuna QR sales + PayPhone card sales + Cash Log total + Fiado payments received. Confirm this formula is implemented exactly. New fiados issued are NOT part of this total.
□ The breakdown row below the hero number shows ALL 4 categories and they sum exactly to the hero number.
□ The "Te deben" amount = Sum of all fiados issued − Sum of all fiado payments received, for all customers. Confirm.
□ The loan offer amount never exceeds `min(30% of average monthly *total* revenue, 8× average daily *digital* revenue)` over 90 active days — the digital-revenue term is the binding fraud defense; see Screen 09A checkpoint. Confirm both terms are computed and the lower one wins.
□ The loan fee is a flat percentage, not compounding interest. Confirm it does not change regardless of repayment speed.
□ Auto-deduction only applies to Deuna and PayPhone transactions, never to cash. Confirm.
□ The qualification counter counts ACTIVE DAYS (days with ≥1 logged transaction), not calendar days since signup. First-time: 90 active days. Repeat borrower: 30 active days. Confirm.
□ A merchant with ONLY cash sales (no Deuna, no PayPhone) can still qualify for a loan if they have 90 active days. Confirm — but the loan amount will be smaller because cash-only data has lower confidence.
□ The fiado repayment rate metric (Screen 09) is calculated BY DOLLAR AMOUNT, not by count of entries. Confirm.
□ End-of-day cash reconciliation REPLACES (not adds to) individual cash entries for the same day. Confirm.
□ Account deletion is BLOCKED while a loan is active. Confirm.
□ Disconnecting Deuna/PayPhone during an active loan shows a warning but is allowed. Confirm.
```

### Security & Privacy
```
□ [Phase 2] Merchant data is encrypted at rest on the device (SQLCipher)? In v1 the pilot runs unencrypted on 10 known devices; do not ship encryption-free past the pilot.
□ API keys/OAuth tokens for Deuna/PayPhone are stored in secure storage (Flutter secure_storage), not plain SharedPreferences?
□ The cédula number is stored only when the merchant begins a loan application, not during onboarding?
□ Cédula validation uses Ecuador's Módulo 10 algorithm (NOT Luhn). Province code (digits 1-2) must be 01–24. Digit 3 must be 0–5 for natural persons.
□ No transaction data leaves the device until the merchant explicitly syncs or the app syncs on WiFi (default: WiFi-only, configurable in settings)?
□ The privacy policy is written in plain Spanish that a non-lawyer can understand?
□ "Eliminar mi cuenta" performs a complete data deletion — server AND local — but is blocked during active loans?
□ Data restores to a new device via phone number + OTP login?
```

---

## TECH STACK REFERENCE (for code generation)

### v1 — device-local, no server. These only.
```
Framework:          Flutter (latest stable)
State Management:   Riverpod
Local Database:     SQLite via drift — typed, reactive
Charts:             fl_chart (lightweight, no web dependencies)
Formatting:         intl (es-EC currency + dates)
Architecture:       data / domain / presentation layers
Minimum Android:    API 21 (Android 5.0) — covers 99%+ of Ecuador devices
Target file size:   <25MB APK (critical for download on slow connections)
```

### Phase 2 — add only when a backend exists
```
Secure Storage:     flutter_secure_storage   (OAuth tokens)
HTTP Client:        dio (retry interceptor for flaky connections)
Offline Sync:       SQLite queue of pending ops, flushed on WiFi
Auth:               Firebase Auth (phone/OTP) or custom backend
Push Notifications: Firebase Cloud Messaging
Encryption at rest: SQLCipher
```
**Do not install the Phase 2 packages during v1.** With no server they carry no
weight and each one adds APK size, build time and surface area. See the build plan.

---

## WHAT TO BUILD FIRST (MVP Priority)

**v1 has no server.** No accounts, no login, no OTP, no sync, no Firebase.
Everything lives in local SQLite on the device. This is deliberate: it costs
nothing to run, works in a market stall with no signal, ships in weeks, and
keeps the product clearly outside the lending perimeter of Resolution
JPRF-F-2023-076 (which binds when you *lend*, not when you give away a
digital notebook).

### Build order

| # | Screen | Why here |
|---|--------|----------|
| 1 | **Libreta** (05) + New Fiado (06) + Customer Detail (07) | The wedge. Solves a present, painful problem — *"I forgot who owes me what."* Paper gets wet, gets lost, gets argued about. This is the reason she opens the app tomorrow. |
| 2 | **Dashboard** (03) | Now it has fiado data to show. An empty dashboard on day one teaches nothing. |
| 3 | **Cash Log** (04) | Logging cash is a chore — work today for a payoff later. It survives contact with reality only *after* the habit exists. |
| 4 | **Historial** (08) | Nearly free with a single-table ledger schema. It is one query. |
| 5 | **Profile** (12) | Cash float, editable quick amounts, CSV export. |

**This inverts the intuitive order deliberately.** Building the Dashboard and
Cash Log first is the build-dependency ordering; Libreta-first is the retention
ordering. Retention is the binding constraint — an app nobody reopens is not a
smaller version of the product, it is a different outcome entirely.

### Not in v1
Onboarding/Setup (01–02), Connected Accounts (14), all of Mi Crédito (09–11),
Notifications (13), and every sync behavior described in this document. Those
screens are fully specified here because they are the finished product — the
spec describes where this ends up, not what ships in week 6.

### The gate
Ship to **10 merchants** by hand-delivered APK. Play Store at ~20 stable
merchants. What you are measuring is day-7 and day-30 retention, not downloads.
Phase 2 begins when merchants demonstrably stay — not on a date.
