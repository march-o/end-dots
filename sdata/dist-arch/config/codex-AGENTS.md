# Local Desktop Automation

- This is a Hyprland desktop. Before launching or focusing GUI applications, run `deskctl capabilities`.
- Use `deskctl open ...` rather than launching a second copy of an application directly.
- `deskctl open ...` does not steal focus; use `deskctl focus ...` only when the user explicitly wants the application brought forward.
- For Chrome, use `deskctl open chrome --profile auto|personal|work|recent [--url URL]`.
- `deskctl` returns JSON suitable for agent inspection. Run `deskctl help` for its contract.
