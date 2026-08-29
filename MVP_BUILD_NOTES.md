# MVP Build Notes — Dependency Migration Strategy

## Current Status
- **Build succeeds** with a minimal set of deps (Flutter 3.x + Riverpod + SQLite + google_fonts).
- **Temporarily removed** (causing gradle/version conflicts):
  - `supabase_flutter` + `google_sign_in` — will integrate after core MVP screens are done
  - `speech_to_text`, `flutter_tts` — will add back after MVP core is stable
  - `connectivity_plus` — will add back for offline-detection features
  - `flutter_downloader`, `permission_handler`, `package_info_plus`, `share_plus` — will integrate for in-app updates & invites later

## Current Feature Set (Stubbed/Ready to Build)
1. ✅ Theme & design tokens (design.md colors, typography)
2. ✅ Models (User, Business, BusinessMember, InventoryItem)
3. ✅ Basic sign-in screen (single Google button, design.md rule 3)
4. 📝 Next: Business creation/join flow
5. 📝 Next: Inventory list screen (persistent user avatar, item list)
6. 📝 Next: Add/edit item screen (type-first, voice later)
7. 📝 Next: Team screen
8. 📝 Next: Bottom navigation

## Integration Roadmap
After core screens + navigation are done:
1. Add `sqflite` + local DB for offline cache
2. Re-add `supabase_flutter` + `google_sign_in` + proper auth flow
3. Add real-time sync to inventory/team screens
4. Add `connectivity_plus` for offline detection + write gating
5. Add `share_plus` for WhatsApp invite sharing
6. Add voice packages (`speech_to_text`, `flutter_tts`) + mic buttons
7. Add `flutter_downloader` + `package_info_plus` for in-app updates

## Notes
- Gradle/AGP 9+ issues will likely resolve once all packages are in sync
- Start MVP with Riverpod providers + in-memory state, swap to Supabase realtime later
- Placeholder auth: hard-coded test user for now, swap with Supabase auth flow
