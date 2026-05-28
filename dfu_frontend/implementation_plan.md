# Reduce Dashboard Load Time to ≤10 Seconds

## Goal Description
The dashboard currently experiences noticeable lag on load, exceeding the target of 10 seconds. This plan outlines optimizations across data fetching, widget rendering, and UI performance to achieve responsive loading.

## User Review Required
- Confirm acceptance of pagination limits for recent scans (default 20 items).
- Approve removal of realtime `StreamBuilder` for static sections (stats, server status) in favor of one‑time `Future` loads.
- Approve any UI design changes (e.g., skeleton placeholders) that may affect visual appearance.

## Open Questions
- Desired maximum number of recent scan items displayed initially?
- Should we enable pull‑to‑refresh for manual data reload?
- Any specific device target (low‑end Android) that requires further simplifications?

## Proposed Changes
---
### Data Layer Optimizations
- **[MODIFY]** `lib/services/firestore_service.dart`:
  - Add methods `fetchUserReportsOnce()` and `fetchStatsOnce()` using `get()` instead of continuous streams for static data.
  - Implement pagination for `getAllReportsStream()` limiting to 20 items with `limit(20)` and order by timestamp descending.
- **[MODIFY]** `dashboard_screen.dart`:
  - Replace `StreamBuilder` for stats and critical queue with `FutureBuilder` calling the new one‑time fetch methods.
  - Use `StreamBuilder` only for the recent scans list with pagination.

### UI Rendering Optimizations
- **[MODIFY]** `glass_widgets.dart`:
  - Mark `GlassCard` constructor as `const` where possible.
  - Wrap heavy widgets (`_buildBackground`, `_buildStatsGrid`, `_buildServerRow`) in `RepaintBoundary` to isolate repaints.
- **[NEW]** Add skeleton placeholder widgets (`LoadingCard`) to show while data loads.
- **[MODIFY]** Introduce `LazyLoadImage` widget for any network images (currently none, future proofing).

### State Management
- **[MODIFY]** `auth_provider.dart`:
  - Cache the role after first fetch to avoid repeated Firestore reads.
- Use `Provider` to expose fetched data objects to dashboard widgets, reducing duplicate calls.

### Performance Profiling
- Add `devtools` instrumentation (e.g., `Timeline` widget) behind a debug flag to verify frame times during development.

## Verification Plan
### Automated Tests
- Run unit tests for new Firestore methods ensuring correct pagination.
- Execute widget tests verifying that `FutureBuilder` displays loading placeholders then data.

### Manual Verification
- Launch the app on a typical device (e.g., Pixel 5) and measure dashboard load time with Stopwatch.
- Confirm load ≤10 s and visual fidelity.
- Verify that scrolling remains smooth (≥60 fps) using Flutter DevTools.
