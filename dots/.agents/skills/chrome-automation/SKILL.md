---
name: chrome-automation
description: Use Martins' existing Chrome profiles and browser tabs for web tasks. Use for Chrome navigation, page interaction, or choosing between personal and work sessions; use hyprland-windows for application window management.
---

# Chrome automation

For OpenCode browser tasks, use `~/.local/bin/chrome-control` once `{"action":"status"}` reports `connected: true`. The Arch installer in `end-dots-martins` installs this command, its service, and this skill together. It connects to a small extension in personal Chrome and supports `list`, `open`, `navigate`, `snapshot`, `click`, `fill`, and `close_tab`. See `~/.local/share/end-dots-martins/chrome-control/README.md` for command formats. The Playwright MCP connection is disabled; do not create its tab group or use ChatGPT's browser connector for OpenCode delegation tests.

Keep browser output focused. `list` includes every tab and can expose unrelated signed-in URLs, so filter it to the site in the task. For a read-only page check, print the top-frame text instead of the entire snapshot, which also contains hundreds of element descriptions:

```sh
~/.local/bin/chrome-control '{"action":"list"}' | jq --arg host 'example.com' '[.result[] | .tabs[] | select((.url // "") | contains($host)) | {id,title,url}]'
~/.local/bin/chrome-control '{"action":"snapshot","tabId":123}' | jq -r '.result[0].result.text'
```

Use the full snapshot when you need element selectors for interaction. The `open` action always creates a new personal Chrome window with `focused:false` and returns `windowId` and `tabId`. Verify the Hyprland placement after opening. If Chrome control cannot create the requested window, use a shell launch with the correct profile directory.

Keep the personal account (`march.mrom@gmail.com`) and work account (`martins.osmucnieks@aerones.com`) separate. Choose the profile from the task context and verify the connected browser's profile before using a logged-in page. The bridge is intended for the personal profile; report a missing work-profile bridge instead of silently using personal Chrome.

Do not launch Chrome through a shell merely to inspect a page. If a shell launch is actually needed, use the `hyprland-windows` skill to inspect existing windows first. Resolve the current profile directory from `~/.config/google-chrome/Local State` before passing `--profile-directory=...` to `google-chrome-stable`:

```sh
jq -r --arg email 'march.mrom@gmail.com' '.profile.info_cache | to_entries[] | select(.value.user_name == $email) | .key' ~/.config/google-chrome/'Local State'
```

Replace the email for work. Do not infer a Chrome window's profile from its Hyprland class alone. Prefer a tab in the existing profile over another browser window. Preserve the user's active window unless they ask to see Chrome.
