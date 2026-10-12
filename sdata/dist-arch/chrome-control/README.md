# Chrome Control

This local extension and Unix-socket bridge controls Chrome through its `tabs`,
`windows`, and `scripting` APIs. It does not use remote debugging or Playwright.

The bridge serves personal and work independently. Personal uses
`~/.local/share/end-dots-martins/chrome-control.sock`; work uses
`~/.local/share/end-dots-martins/chrome-control-work.sock`. Both extensions
connect to `127.0.0.1:49376`. Tokens are generated separately at runtime in
`~/.local/share/end-dots-martins/` and never belong in source control. The
personal unpacked extension remains at
`~/.local/share/end-dots-martins/chrome-control/extension`; the generated work
extension is at `~/.local/share/end-dots-martins/work-extension`.

Chrome profile mapping is recorded in `profiles.json`: personal is `Profile 1`
and work is `Default`. The work directory is generated mapping data, not a
credential or a profile database. Install/update copies only the bridge, service
definition, and CLI; activation is handled separately. Installing never signs
into an account or restarts Chrome. Profile availability depends on Chrome
being open with that profile and its corresponding bridge extension connected.

Load the personal unpacked extension through `chrome://extensions` as usual.
For work, enable Developer mode in the work profile's `chrome://extensions`,
choose **Load unpacked**, and select
`~/.local/share/end-dots-martins/work-extension`. The two extension entries have
distinct names and independently generated tokens. Extension installation does
not sign into either account.

The legacy personal URL `/extension?token=…` still authenticates as personal.
Requests without a `profile` default to personal. Set `"profile":"work"` to
route through work; unknown or disconnected profiles fail closed.

```sh
~/.local/bin/chrome-control '{"action":"status"}'
~/.local/bin/chrome-control '{"action":"list"}'
~/.local/bin/chrome-control '{"action":"status","profile":"work"}'
~/.local/bin/chrome-control '{"action":"open","profile":"work","url":"https://example.com"}'
~/.local/bin/chrome-control '{"action":"snapshot","tabId":123}'
```

Other commands are `navigate`, `click`, `fill`, `press`, `reload`, and `close_tab`. `click`,
`fill`, and `press` take a CSS `selector`; `fill` also takes `value`. `press`
accepts only `Enter`, `Escape`, `ArrowUp`, `ArrowDown`, or `Space`, and
dispatches DOM keyboard events without activating a window or sending OS input.
Snapshots include unique selectors and accessible state, never input values.
They return the top frame by default; add `"allFrames":true` to include iframe
content. Mutation commands require an `expect` object to confirm success, for example
`"expect":{"selector":"#menu","state":"visible"}`. States are `visible`,
`hidden`, `checked`, and `unchecked`; the condition must change from false to
true. Without confirmation, the response is unsuccessful and marked uncertain:
inspect a fresh snapshot before deciding what to do next, rather than replaying
input automatically. `timeoutMs` defaults to 1500 (maximum 5000).
DOM events are synthetic; Tab traversal and implicit form submission are unsupported.
An explicit `inputMode:"pointer-sequence"` can be used for click; it is never
retried after another input method.

Use `npm test` for isolated WebSocket/Unix-socket and page-action tests. The live
browser test is opt-in: `CHROME_CONTROL_LIVE_TEST=1 CHROME_BIN=/path/to/chrome npm test`.
It uses a disposable profile; choose a build that supports loading unpacked extensions.
`reload` acknowledges first, then reloads only the Chrome Control extension;
its extension-owned `maintenance/reload.html` is the one-time bootstrap page for
an older already-loaded copy.
