# ClippyManager — Product Guide

*Everything ClippyManager can do, from your point of view. No code, no jargon —
just what you can do and how it feels to use.*

> **One line:** Your Mac's clipboard now has a memory, a beautiful visual shelf,
> and an on-device AI that reshapes anything you copied — without anything ever
> leaving your computer.

---

## 1. What ClippyManager is

ClippyManager is a clipboard manager for macOS. Normally your Mac remembers only
the **last** thing you copied — copy something new and the old one is gone forever.
ClippyManager quietly keeps a history of everything you copy (text, links, code,
colors, images, files, screenshots) and gives you three beautiful ways to get any
of it back: a **notch shelf**, a **keyboard palette**, and a **full library**.

On top of that, it can **transform** what you copied with on-device AI —
summarize a paragraph, translate a message, fix grammar, explain code, turn text
into JSON — and you preview the result before it lands.

It lives in your **menu bar**. It never shows a Dock icon you don't want, never
nags, and works fully offline.

---

## 2. Capturing — it just remembers

You don't do anything special. Copy as you always do (⌘C) and ClippyManager saves
it automatically.

- **Everything is captured:** plain text, links, code snippets, color values,
  images, files, and screenshots.
- **Smart sorting:** each item is automatically recognized and tagged by type —
  Text, Links, Code, Colors, Images, Files, Screenshots.
- **Where it came from:** every item remembers which app you copied it from and
  shows that app's icon, plus a timestamp and its size.
- **Colors become swatches:** copy `#0080FF`, `rgb(...)`, or `hsl(...)` and you get
  a real color chip you can see.
- **Screenshots are recognized:** a full-screen or region grab is tagged as a
  Screenshot, not just a generic image.
- **Sensitive content is protected:** if something looks like a password, credit
  card, API key, or token, it's flagged and hidden behind a "sensitive" marker —
  and AI actions are switched off for it.

### Pause when you want privacy
One click **pauses capture** entirely (from the menu-bar icon or Settings). While
paused, nothing new is recorded. Resume with one click.

---

## 3. The notch shelf — your clips, at the top of the screen

A dark, elegant panel that drops down from the **notch** area, floating over
whatever app you're in. It shows your recent clips as a horizontal row of cards.

**Three ways to open it:**
1. **Hover** your mouse over the notch — the shelf peeks open by itself, and slides
   away when you move away. (Can be turned off in Settings.)
2. **Drag** something onto the notch — the shelf opens ready to receive it.
3. From the **menu-bar icon**.

**What you can do in the shelf:**
- **Click a card** to copy that item back to your clipboard.
- **Drag a card out** straight into another app (drop an image into a design tool,
  a file into an email…).
- **Drop something in** — drag an image, file, or text onto the shelf and it's saved
  as a new clip, even if you never copied it. (Drop-to-save.)
- **Filter by category** with the pill tabs along the top.
- **Pin favorites** so they always stay at hand.
- Jump to **Settings** or the **full Library**, or clear history.

The shelf is always in **dark mode** for a clean, focused look, regardless of your
system appearance.

---

## 4. The paste palette — keyboard-first, with AI

Press **⌃⌘V** (Control-Command-V) and a centered palette appears, search box
already focused. This is the fastest way to paste — and the home of AI actions.

**The basic flow:**
1. The palette lists your clips, most recent first.
2. **Type to search**, or use **↑ / ↓** to move through them.
3. Press **↩ (Return)** to paste the highlighted clip — exactly like a classic
   paste. If you never want AI, this is all you ever need; it never changes.

**The numbered shortcuts:**
- **⌃⌘0 … ⌃⌘9** paste one of your last ten clips instantly, without even opening
  the palette.

---

## 5. AI actions — reshape anything you copied (on-device)

This is what makes ClippyManager special. Every action works on a clip you already
have, runs **entirely on your Mac** via Apple Intelligence, and shows you the
result before it lands.

### How it works, step by step
1. Open the palette (**⌃⌘V**) and highlight a clip.
2. Under the clip, an **action bar** appears with the most useful actions for that
   clip — already ordered for what you're doing. The first one is the **suggested
   default**, highlighted.
3. Choose how to act:
   - **↩** → paste the **original** (AI untouched).
   - **⌘↩** → run the **suggested action** in one stroke.
   - **→** (right arrow) → open the **full action menu**, searchable.
   - **⌘1–9** → run the 1st–9th action chip directly.
4. The result **streams in live** in a preview, with your original alongside, and a
   badge: **"✨ On-device · nothing leaves your Mac."**
5. Decide:
   - **⌘↩** → paste the result.
   - **Edit it** inline first — it's just text.
   - **⌘R** → regenerate if you want a different take.
   - **Esc** → go back to the original, nothing lost.
   - **Then…** → run *another* action on the result (see Chaining).
6. After it lands, the transformed text is also **saved as a new clip** — your
   original is always preserved next to it.

### What the AI can do

**On any text:**
- **Summarize** — into a sentence, or key-point bullets.
- **Shorten** — say the same thing in fewer words.
- **Rewrite** — make it formal, or make it casual.
- **Fix grammar** — spelling, grammar, punctuation.
- **Simplify** — explain it plainly.
- **Translate** — into Italian, English, Spanish, French, German…
- **Extract action items** — pull tasks out of a wall of text.
- **Make a title** — turn a blob into one clean headline.

**On code:**
- **Explain** — what does this code do, in plain language.
- **Add comments** — annotated version of the snippet.
- **Explain a regex** — step by step.
- **→ JSON** — convert content into clean, valid JSON.

**On data:**
- **→ Table** — organize messy content into a tidy table.
- **→ Bullets** — turn prose into a clean list.

### It learns what you like
The suggested default isn't fixed. It adapts to **the kind of clip** and **the app
you're pasting into** — translate first for foreign text, summarize for long text
in Notes, explain for code in Xcode, shorten for chat apps. And the more you use a
particular action in a particular context, the higher it floats. You never
configure this; the right action is just there.

### Chaining
In the preview, hit **Then…** to feed the result through another action:
*Summarize → Translate to Italian → paste.* A breadcrumb shows the chain so you
always know what's been applied.

### Multi-clip batch
Copied five scattered things and want them as one? In the palette press **space**
to multi-select clips (checkmarks appear), then pick a batch action:
- **Merge & Summarize** — fuse them into one coherent summary.
- **Combine into list** — one clean, de-duplicated bullet list.
- **Deduplicate** — drop repeated lines across all of them.

### Custom prompts — your own actions
Save your own AI action in **Settings → Custom Prompts**, e.g. *"Rewrite this in my
warm, concise email tone."* It then appears in the palette's action menu like any
built-in action.

### Transform selection in place
You don't even need to copy first. Select text in **any** app, press **⌃⌘J**, pick
an action, and the result **replaces your selection** right there — no trip through
the history. (Requires granting Accessibility permission; if you don't, it simply
asks once.)

### Honest about limits
- AI actions always work **on something you copied** — there's no "ask me anything"
  box, because the on-device model is built for reshaping text, not answering
  trivia. This keeps every result fast and reliable.
- It won't write code from scratch or hunt complex bugs; it explains, comments,
  and converts code you already have.
- Very long text is summarized in honest chunks rather than silently cut.

---

## 6. If you don't have Apple Intelligence yet

ClippyManager never shows dead buttons. If Apple Intelligence isn't available, the
app stays a perfect clipboard manager — and the AI actions become a **preview you
can explore**:

- The action chips still appear, marked with a small lock.
- Tap one and you see **what it would do** ("Here's what you'd get"), the on-device
  privacy promise, and a guided button to turn it on.
- The app tells you honestly which of three things is the case and what to do:
  1. **Your macOS is too old** → it guides you to Software Update.
  2. **Your Mac isn't supported** → it says so plainly (no false hope).
  3. **Apple Intelligence is just off** (or still downloading) → a one-tap
     **"Enable Apple Intelligence…"** button takes you to the right place, with the
     steps written out.

The same status and guidance live in **Settings → AI Actions**, where you can also
turn AI actions off entirely if you prefer.

---

## 7. The Library — your full visual history

Open the Library window for the complete picture: a **grid of cards** of everything
you've saved.

- **Search** across all your clips.
- **Filter** by type (text/links/code/…) and by **source app** (everything from
  Safari, from Figma, from Slack…).
- **Grouped by day** — Today, Yesterday, and earlier dates.
- **Detail pane:** click a card to see a big preview plus its details — when, from
  which app, the original URL, the size — and a one-click **Copy** button.
- **Pin / favorite**, assign to categories, or delete from here too.

---

## 8. Categories — organize the way you think

Beyond the automatic type tags, you can create your own **categories** — colored,
named spaces with an icon, like *Prompts*, *Assets*, *Inspirations* (a few come
ready-made). File any clip into a category and filter by it in the shelf and
library. Great for projects, brand assets, templates, snippets you reuse.

---

## 9. Settings — everything in one place

Open from the menu-bar icon → **Settings** (or **⌘,**):

- **General** — Launch at login · Hover-the-notch-to-peek on/off.
- **Capture** — Pause clipboard capture · History limit (how many clips to keep).
- **AI Actions** — live status, what it does, guided enable, and an on/off switch.
- **Custom Prompts** — create and manage your own AI actions.
- **Shortcuts** — a reference of every keyboard shortcut.
- **Updates** — automatic update check (note: from the App Store, updates are
  automatic anyway).
- **License** — your trial/lifetime status and unlock.
- **Data** — clear all history.

---

## 10. Keyboard shortcuts at a glance

| Shortcut | What it does |
|---|---|
| **⌃⌘V** | Open the paste palette |
| **↩** | Paste the highlighted clip (original) |
| **⌘↩** | Run the suggested AI action / paste the AI result |
| **→** | Open the full action menu |
| **⌘1 – ⌘9** | Run the Nth action (or Nth batch action when multi-selecting) |
| **space** | Toggle multi-select on a clip |
| **⌘R** | Regenerate the AI result |
| **Esc** | Back / close |
| **⌃⌘J** | Transform the current selection in place (any app) |
| **⌃⌘0 – ⌃⌘9** | Paste one of your last 10 clips instantly |
| **Hover / drag the notch** | Open the shelf (peek / drop-to-save) |

---

## 11. Privacy — the whole point

- **Everything stays on your Mac.** No cloud sync, no servers, no accounts.
- **No tracking, no analytics, no data collection** — none.
- **AI runs on-device.** When you transform a clip, the text is processed by
  Apple's on-device model; it never leaves your computer. The "✨ on-device" badge
  is shown right when it happens.
- **Sensitive content** (passwords, cards, tokens) is auto-detected, masked, and
  excluded from AI actions.
- **Sandboxed** and built to Apple's App Store privacy standards.

---

## 12. Pricing

- A short **free trial**, then a **one-time lifetime purchase** — no subscription.
- **Promo codes** can unlock it instantly.
- All features included; all future updates included.

*(Pricing/licensing is currently being finalized for the App Store.)*

---

## 13. Requirements

- **macOS 14 (Sonoma) or later** for the clipboard manager.
- **macOS 26 + Apple Intelligence** for the on-device AI actions. Without it, every
  other feature works perfectly and the AI actions appear as an explorable preview
  with guidance to enable them.

---

*ClippyManager is open source. Inspired by the lovely [Supaste](https://www.supaste.com),
built independently from scratch.*
