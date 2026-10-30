# Security policy

Macchiato holds an OpenAI API key in the macOS Keychain, sends requests to `api.openai.com` with it, writes images to your home folder, changes your desktop wallpaper and starts at login. A flaw in how it handles the key, the network traffic or those files matters.

## Reporting a vulnerability

Please report it privately: open **Security > Report a vulnerability** on this repository, or go straight to <https://github.com/nervouna/macchiato/security/advisories/new>.

Include the steps to reproduce, your macOS version, and the release or commit you tested. You will get an answer within a week. Fixes land on the default branch and in the next release; older releases are not maintained.

## In scope

- Leaking or mishandling the API key (logs, files, process arguments, the Keychain item's access rules).
- Sending anything to a host other than `api.openai.com`.
- Reading or writing files outside `~/Library/Application Support/Macchiato/` and the wallpaper settings.
- Flaws in the release packaging or signing described in this repository.

## Out of scope

- Problems that need an attacker who already controls your account or your Mac.
- Weaknesses in macOS, the Keychain or OpenAI's service themselves; report those to Apple or OpenAI.
- Image content that you find unpleasant: use the issue tracker for that.
