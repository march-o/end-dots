# Chrome Control

This is a small Chrome extension and local Unix-socket command tool for OpenCode.
It uses Chrome's `tabs`, `windows`, and `scripting` APIs. It does not use Playwright,
Chrome remote debugging, or the ChatGPT browser connector.

The bridge server listens on `127.0.0.1:49376` only for the extension and on
`~/.local/share/end-dots-martins/chrome-control.sock` for local commands. The generated token
is stored at `~/.local/share/end-dots-martins/chrome-control-token` and copied into the
extension's ignored `config.js`. The local socket and token are mode 0600.

The Arch install and update process installs the bridge, its user service,
`~/.local/bin/chrome-control`, and the `chrome-automation` and `hyprland-windows`
skills. To install only these pieces from the repository, run
`bash sdata/dist-arch/install-chrome-control.sh`.

The installer also permits OpenCode to access this installed tool directory
without prompting, while denying edits there.

The user service is:

```sh
systemctl --user enable --now chrome-control.service
```

In the **personal Chrome profile**, load the unpacked extension at
`~/.local/share/end-dots-martins/chrome-control/extension` through `chrome://extensions`
with Developer mode enabled. Chrome will ask for access to all sites, which is
needed for general browser tasks. Do not install it in the work profile unless
work-browser access is separately intended.

Use the CLI from OpenCode:

```sh
~/.local/bin/chrome-control '{"action":"status"}'
~/.local/bin/chrome-control '{"action":"list"}'
~/.local/bin/chrome-control '{"action":"open","url":"https://example.com"}'
~/.local/bin/chrome-control '{"action":"snapshot","tabId":123}'
```

Other commands are `navigate`, `click`, `fill`, and `close_tab`. `click` and
`fill` take a CSS `selector` from the current page. `fill` also takes `value`.
For sensitive values, pass JSON on standard input instead of a process argument.
Snapshots return the top frame by default; add `"allFrames":true` only when
content needed for a task is inside an iframe.

Chrome's branded builds ignore the `--load-extension` command-line flag, so the
unpacked extension has to be loaded once through Chrome's extension page.
