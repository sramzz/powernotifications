# PowerNotifications v1

## Product promise

PowerNotifications is an English-language iPhone app for writing personal
prompts and receiving them through repeating local notifications. All data
stays on the device.

A first-time user completes a welcome step, creates a prompt, chooses a daily
count plus wake and bedtime, and explicitly enables notifications. The app then
shows and delivers a fixed daily pattern of 1–20 notifications. Users can
reshuffle that pattern at any time.

## User experience

The main app has three tabs:

- **Prompts** lists prompts and supports create, detail, edit, and delete.
- **Schedule** owns the delivery switch, daily count, wake time, bedtime, full
  generated pattern, retry, and reshuffle controls.
- **Settings** shows notification authorization, recovery through iOS Settings,
  app version, and an About summary.

Prompt text is trimmed, required, multiline-capable, and limited to 280
characters. Duplicate text is allowed. Tapping a notification opens its prompt
detail. If that prompt was later deleted, the delivered text remains available
in a read-only fallback detail.

The last prompt cannot be deleted while delivery is enabled. Turning delivery
off cancels scheduled app notifications without deleting prompts or schedule
settings. Denied or revoked authorization leaves delivery off and exposes an
Open Settings action.

## Scheduling contract

- The active window begins at wake time and ends at the next occurrence of
  bedtime, including windows that cross midnight. Equal times are invalid.
- The count is limited to `1...min(20, active-window whole minutes)`.
- The window's minute offsets are divided into equal contiguous segments. One
  minute is selected randomly from each segment, guaranteeing distinct,
  ordered, distributed delivery times.
- Prompts are shuffled and used once before another shuffled cycle begins.
  Repetition occurs only when the count exceeds the prompt count.
- Each slot becomes a repeating calendar notification titled
  “PowerNotifications,” containing the prompt as its body and using the default
  sound. The request payload includes the prompt identifier and a text snapshot.
- The pattern remains fixed until a prompt or schedule change is saved, or the
  user explicitly reshuffles it. Any such action rebuilds all app-owned pending
  requests.
- Pending notification requests are the generated-pattern source of truth and
  are shown in wake-to-bed order on Schedule.
- Foreground delivery uses the normal banner and sound.
- A failed replacement removes the incomplete pattern, marks delivery inactive,
  preserves user data, and offers Retry.
- On foreground activation, authorization and pending requests are reconciled;
  an enabled but inconsistent schedule is rebuilt.

## Data and architecture

- Prompts use SwiftData with UUID, text, creation date, and modification date.
- Onboarding completion, delivery state, count, wake time, and bedtime use
  app-specific preferences.
- Feature-MVVM remains the organizing pattern. Random generation and User
  Notifications are isolated behind testable interfaces.
- Logs cover lifecycle, permission state, scheduling, reconciliation, and
  failures without recording prompt text.
- Defaults are three notifications, 08:00 wake time, and 22:00 bedtime.

## Exclusions

V1 has no accounts, backend, cloud sync, import/export, curated packs, history,
analytics, completion tracking, notification actions, widgets, per-weekday
schedules, or newly randomized patterns every day. Uninstalling the app removes
its data.
