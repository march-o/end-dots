# Local Desktop Automation

- This is a Hyprland desktop. Read `hyprland-windows` for application windows and `chrome-automation` for Chrome tabs, profiles, or pages.
- Inspect existing windows with `hyprctl clients -j` and reuse the requested app when it is already open.
- Use a connected browser tool for page interaction. Keep personal and work Chrome profiles separate.
- Preserve focus unless the user explicitly asks to bring an application forward.
- Keep browser automation in the background. Use hidden tabs or `visible: false` when the available browser supports them. Do not activate Chrome or a browser tab just to inspect a page.
