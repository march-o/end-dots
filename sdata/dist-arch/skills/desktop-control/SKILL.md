---
name: desktop-control
description: Control Martins' local Hyprland desktop through deskctl. Use when asked to open, focus, inspect, or reuse a GUI application or window, including a personal, work, or recent Chrome profile. Do not use for web research that does not require manipulating the local desktop.
---

# Desktop Control

Use `deskctl` instead of starting supported GUI programs directly. It provides stable JSON output, avoids duplicate windows, and applies the user's focus and Chrome-profile preferences.

## Workflow

1. Run `deskctl capabilities` before the first desktop action in a session. Use only advertised apps, profiles, options, and commands.
2. Use `deskctl windows [APP]` or `deskctl active` when the request depends on current window state.
3. Choose the command from the user's intent:
   - Use `deskctl open APP` to ensure an app is open without changing the active window.
   - Use `deskctl focus APP` only when the user explicitly asks to focus, switch to, show, or bring forward an app. This command does not launch missing apps.
   - To both open and focus a missing app, run `deskctl open APP` and, after success, `deskctl focus APP`.
4. Check the returned JSON. Treat the action as successful only when `ok` is `true`, and accurately report whether it was already open, launched, focused, or given a URL.

## Chrome profiles

Use `deskctl open chrome --profile PROFILE` or `deskctl focus chrome --profile PROFILE`.

- No profile stated: `auto`
- Personal, private, or Martins' profile: `personal`
- Work or Aerones profile: `work`
- Last or most recently used profile: `recent`

Add `--url URL` only when the user supplied or requested that destination. Pass it as one quoted argument. Do not use `--url` with `focus`.

Examples:

```bash
deskctl open chrome --profile auto
deskctl open chrome --profile work --url 'https://example.com'
deskctl focus chrome --profile personal
deskctl open files
deskctl focus terminal
```

## Constraints

- Preserve focus by default. Do not replace `open` with `focus` merely to make the action visually obvious.
- Do not parse JSON with `eval`, interpolate it into shell commands, or pass untrusted values as shell code.
- On an unsupported app or command failure, report the structured error. Do not bypass `deskctl` by directly launching a supported app, because that can duplicate windows or select the wrong Chrome profile.
- Desktop actions affect the user's live session. Perform only actions within the user's request; inspection commands are read-only.
