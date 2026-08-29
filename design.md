---
name: rural-shopkeeper-ui
description: Research-grounded design system and UX rules for building screens in the dukaan/inventory-management Android app aimed at rural Indian small-business owners (40-50yo, Hindi-first, low English literacy, not tech-savvy, prefer WhatsApp/Facebook, prefer speaking over typing). Grounded in HCI4D/ICTD field research (Microsoft Research India, Tapan Parikh, Google Next Billion Users) and real competitor apps (Khatabook, OkCredit, Vyapar). Use this skill whenever building, editing, or reviewing ANY screen, component, or user-facing copy in this app — sign-in, business creation, invites, inventory list/edit, team management, or any future feature. Trigger on requests like "add a screen for X", "build the UI for Y", "how should this form look", or "write the copy for Z", even if the user doesn't explicitly mention design system or accessibility.
---

# Rural Shopkeeper Inventory App — UI Skill

This app's real user: a 40-50 year old shopkeeper in rural India. Native language Hindi, limited English reading/writing/speaking, not tech-savvy, most-used apps are WhatsApp and Facebook, strongly prefers speaking to typing. Every design and copy decision should be checked against this person, not against "modern app" conventions.

This skill is grounded in published HCI4D/ICTD field research on exactly this population (Microsoft Research India's work on text-free interfaces and emergent smartphone users; Tapan Parikh's rural financial-UI studies; Google's Next Billion Users research), and in how real competitor apps (Khatabook, OkCredit, Vyapar, and voice-billing apps like Dukaan AI) already solve adjacent problems for the same audience. Where research findings sharpened or corrected an earlier assumption, that's noted.

## Non-negotiable rules

1. **Voice is the primary input, not a bonus feature — but it must be verifiable, including for non-readers.** Any data-entry screen needs a mic button as the largest, most dominant control, with typing as fallback. Critically: after listening, confirm back what was heard **both visually (large text) and audibly (spoken read-back)** — field research on this exact population found users do verify voice input before proceeding, but non-literate users can't do that from text alone. A silent "confirmed" checkmark is not enough.

2. **Icons must be bold, colorful, and unambiguous — never thin minimalist line icons.** Research on low-literacy users found abstract/stylized glyphs are frequently misread, and recommends semi-realistic, concrete, high-contrast icon styles over sparse outline icons or literal photos. Every icon is paired with a short Hindi label — never icon-only, regardless of how "obvious" the icon seems to a literate designer.

3. **Sign-in and account setup is the single hardest screen in the app — design for a one-time assisted setup, not a self-serve flow.** Field research on emergent Indian smartphone users found many rely on a literate family member, child, or colleague to set up any account or ID for them, and that the concept of separate "accounts" on a shared device is often unfamiliar. Practical implications:
   - Minimize decisions during sign-in to the absolute fewest taps (this is cited as the reason WhatsApp itself was adopted so widely among low-literacy first-time users — automated, simplified registration, few choices).
   - Once signed in, stay signed in indefinitely. Never force a re-authentication flow the user has to repeat alone.
   - Assume someone else may be doing this step *for* the shopkeeper the first time — the screen should be easy for an intermediary to explain over a phone call or a WhatsApp voice note, not just easy for the end user alone.

4. **Always show a persistent, unmissable "who's using this right now" indicator.** Because phones are heavily shared within families and multi-account concepts aren't intuitive to this audience, don't rely on a small profile icon in a corner. The current user's name/avatar should be visible near the top of every screen where edits happen, not just tucked into a menu.

5. **No hidden navigation.** No hamburger menus, no swipe-to-reveal actions, no long-press menus, no nested settings pages. Bottom nav bar: max 3 icons, icon + Hindi label always both shown.

6. **One primary action per screen**, obvious and large. Secondary/rare actions can be smaller, but the thing the user came to do must be unmissable.

7. **Minimum touch target 48-56px**, minimum body text 16-18px, headings 20px+. This is a 40-50yo user on an older/budget Android phone — don't use compact/dense layouts anywhere.

8. **Meaning through color and icon, not just text.** Low stock, errors, and success states must be readable from color/icon alone, never text-only.

9. **Minimize scrolling and text entry wherever a tap, a voice input, or a stepper control can substitute.** Confirmed repeatedly across the research: reducing raw text entry is one of the highest-leverage things you can do for this audience.

10. **"Edited by" attribution** always shows as: colored initial avatar (first letter of first name) + short name format "पहला-नाम दूसरे-नाम-का-पहला-अक्षर." (e.g. "रमेश क."), consistent everywhere edits are shown.

11. **Errors and empty states speak plainly, never blame the user, in one short sentence + icon.** No jargon, no stack traces.

12. **Familiar mental models over novel ones.** Prefer patterns from WhatsApp (chat-bubble-like lists, share-to-invite, contact-style avatars) and the physical shop ledger/khata (big numbers, stepper +/-, rupee-first pricing) over generic app conventions.

## Copy rules (revised)

- **Write in the code-mixed Hindi this audience actually speaks — don't force pure/Sanskritized Hindi.** Field research found specific English words (network, hotspot, share, login, invoice, OTP) have simply become part of this population's everyday vocabulary, even for people who can't otherwise read English. Forcing an unfamiliar "purer" Hindi translation of a term people already know in English can work against comprehension, not for it. When in doubt, use whichever version (Hindi or the naturalized English/Hinglish term) is more likely to already be familiar from WhatsApp, UPI, or basic phone use — don't default to translating everything on principle.
- Every button label is a verb describing exactly what happens: "सामान जोड़ें" (add item), not "जमा करें" (submit) or "आगे" (next) alone.
- Keep sentences under ~8-10 words. If a screen needs an explanation, the flow is too complex — simplify the flow before writing longer copy.
- A voice confirmation should always be readable AND speakable back to the user — never rely on text alone to confirm what was heard.

## Design tokens

```
Background (ledger-paper):  #FAF6EF
Surface (cards/inputs):     #FFFFFF
Ink (primary text):         #2B2620
Ink soft (secondary text):  #6B6153
Primary (buttons/brand):    #0F6B5C   (khata-green — trust, money)
Primary dark (pressed):     #0B4F44
Primary soft (bg tint):     #E3F0EC
Accent (highlights):        #F2A93B  (marigold)
Accent soft:                #FCEBCB
Danger (low stock/errors):  #D64545
Danger soft:                #FBE4E4
Success:                    #2F9E44
Border:                     #E7DFD0
```

Fonts: **Noto Sans** + **Noto Sans Devanagari** (same superfamily, matching metrics across scripts).

Avatar colors: assign from a small fixed palette (`#0F6B5C, #B5533C, #3C6E9C, #8A5FB0, #B08900`) by hashing the person's name, so the same person always gets the same color.

**Icon style (revised):** bold, filled or semi-realistic/cartoon-style icons with high color contrast — not thin outline/stroke icon-font glyphs (e.g. avoid default Lucide/Feather-style line icons as the *only* visual cue; if using an icon library for development speed, pair every icon with a bold color fill or background chip and a label, never leave it as a bare thin outline).

## What competitor apps already validate

Khatabook, OkCredit, Vyapar, and voice-billing apps (e.g. Dukaan AI) serve this exact audience today and are worth checking before inventing a new pattern:
- **Voice billing/entry is already a flagship, proven feature** in this category — speaking items to create bills or update stock, working offline, in Indian languages.
- **Role-based staff accounts** are cited as a real differentiator between competing apps — worth deciding early whether every coworker can edit prices vs. just quantities.
- **WhatsApp is the trusted channel** for sharing invite codes, payment reminders, and business updates — lean on it rather than building custom sharing/notification flows.
- A too-busy interface is explicitly called out as a reason non-tech-comfortable users default back to paper records — simplicity isn't just nice-to-have, it's the difference between adoption and abandonment.

## Component reference

A working reference implementation (sign-in, create/join business, invite teammates, inventory list with low-stock states, voice-first add-item flow, team screen, bottom nav) lives in `dukaan-inventory-mockup.jsx` in this project's outputs. It predates some of the findings above (notably: it uses thin outline icons, and its sign-in/voice-confirmation flows don't yet reflect points 2, 3, and 4) — treat it as a layout/spacing/token reference, not a finished pattern, until it's revised.

## When reviewing existing screens

- [ ] Is there a mic-first way to do this, if it involves entering data — and is what was heard confirmed both visually and audibly?
- [ ] Are icons bold/concrete rather than thin abstract line glyphs, and always labeled?
- [ ] If this is a sign-in or account-setup screen, would this be easy for someone to do *for* the shopkeeper over a phone call?
- [ ] Is it obvious at a glance who is currently using the app?
- [ ] Is everything readable without relying on English, except terms this audience already knows from WhatsApp/UPI (network, share, OTP, etc.)?
- [ ] Can the user get here and back without a hidden menu or gesture?
- [ ] Are touch targets and text big enough for a 40-50yo user on a budget Android phone?
- [ ] Does color/icon alone tell the user what state something is in?
- [ ] Does "edited by" follow the standard avatar + short-name format?