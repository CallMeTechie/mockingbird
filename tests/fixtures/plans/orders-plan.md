# Orders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show open orders and let the desk work through them.

**Architecture:** REST API plus a React table view.

**Tech Stack:** TypeScript, React, Express.

**Spec:** `docs/superpowers/specs/2026-09-03-orders-design.md`

**Design:** `docs/design/manifest.yaml` (rev 3) — Design-System: `docs/design/design-system.md` — Artboards: `docs/design/mockups/index.html`

**Design Scope:** UI-ORDERS, UI-SHELL (übernommen, nicht zu bauen: UI-SHELL-TOAST)

## Global Constraints

- Design-Quelle: `docs/design/manifest.yaml` (rev 3). Bei Konflikt zwischen Plan-Text und Manifest gilt das Manifest; melde den Konflikt, statt ihn still aufzulösen.
- Jedes gebaute UI-Element trägt seine Manifest-ID im Code: Web `data-ui-id="UI-…"`, andere Medien nach `adapters:` im Manifest. Ohne ID ist das Element nicht prüfbar.
- Design-Tokens ausschließlich aus `docs/design/mockups/tokens.css` bzw. `docs/design/design-system.md`. Keine neuen Farben, Abstände, Radien oder Schriftgrößen.
- Sichtbare Texte (Labels, Leer-, Lade- und Fehlerzustände) wörtlich aus dem Manifest (`label`, `states[].copy`). Keine eigenen Formulierungen.
- Jeder im Manifest deklarierte Zustand eines Elements wird gebaut, nicht nur `default`.

---

## File Structure

- Create: `src/api/orders.ts` — the orders endpoint
- Create: `src/components/OrdersTable.tsx` — the table view
- Modify: `src/db/schema.sql:40-52` — add the promised_delivery_at column

### Task 1: Orders API endpoint

**Files:**
- Create: `src/api/orders.ts`
- Test: `tests/api/orders.test.ts`

**Interfaces:**
- Produces: `GET /api/v1/orders?status=open -> { orders: Order[] }`

**Design:** kein UI-Anteil.

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Write minimal implementation**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

### Task 2: Orders table view

**Files:**
- Create: `src/components/OrdersTable.tsx`
- Test: `tests/components/OrdersTable.test.tsx`

**Interfaces:**
- Consumes: `GET /api/v1/orders?status=open -> { orders: Order[] }` from Task 1

**Design:**
- Screen: `UI-ORDERS` — Artboard `docs/design/mockups/ui-orders.html`
- Zu bauende Elemente (Werte wörtlich übernehmen):

| ID | Element | Fachlicher Anker | Zustände | Copy |
|----|---------|------------------|----------|------|
| UI-ORDERS-TABLE | Tabelle offener Bestellungen | Eine Zeile je Bestellung mit Status ungleich versendet. Nicht: invoice, shipment. | default, loading, empty, error | Spaltenköpfe: „Bestellung", „Kunde", „Lieferdatum", „Status" |
| UI-ORDERS-EMPTY | Leerzustand der Bestellliste | Bestätigung, dass nichts offen ist. | default | „Keine offenen Bestellungen." |

- Locator: jedes Element trägt `data-ui-id="<ID>"`.
- Tokens: `color.surface`, `color.text.muted`, `space.4`, `type.body`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Write minimal implementation**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

### Task 3: Order export (with a fenced code example inside the design table's neighbourhood)

**Files:**
- Create: `src/components/ExportButton.tsx`

**Interfaces:**
- Consumes: nothing new

**Design:** kein UI-Anteil.

Note for a human reader: here is a code sample of what a design table looks like elsewhere in this plan, deliberately fenced so it must NOT be picked up as this task's requirements and must NOT be mistaken for a task boundary by the extractor:

```markdown
### Task 99: not a real task heading, just documentation inside a fence
| UI-FAKE-ID | should never appear in any real brief |
```

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Write minimal implementation**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**
