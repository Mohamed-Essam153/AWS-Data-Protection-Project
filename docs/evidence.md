# Evidence rules

What we hand in has to stand up to "show me". These are the rules we follow.

1. **Prefer test output to screenshots.** `evidence/test-report-*.md` comes straight from the CLI and has every command's result. Screenshots are for things the CLI can't show nicely (console pages, alert emails).
2. **Screenshots go in [evidence/screenshots/](../evidence/screenshots/)** named `W<week>-<nn>-<what>.png`, e.g. `W2-03-kms-alarm-email.png`. The list of screenshots we take is in that folder's README.
3. **Region and resource name visible** in every screenshot.
4. **Redact before committing**: the 12-digit account ID, email addresses, any ARN with the account ID in it. The test runner does this for its report; for screenshots, blur them.
5. **Never** capture secret values, Cognito tokens, passwords or temporary credentials. Nothing in our scripts prints them.
6. **Every row of the compliance matrix** points at a test ID or a file in this repo.

Quick redaction for anything you paste from the terminal:

```bash
<command> | sed -E 's/[0-9]{12}/<ACCOUNT_ID>/g'
```

If something sensitive does get pushed, rotate it first and clean the history second. Deleting the commit doesn't un-leak it.
