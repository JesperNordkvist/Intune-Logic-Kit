# Project Instructions

## GitHub Identity - CRITICAL

This repository belongs to **JesperNordkvist** (jesper.nordkvist@outlook.com). The user has multiple GitHub accounts and they must NEVER be linked.

Before ANY git push, PR creation, or GitHub interaction:

1. Run `gh auth status` and confirm **JesperNordkvist** is the active account
2. Run `git config user.name` and confirm it returns **JesperNordkvist**
3. Run `git config user.email` and confirm it returns **jesper.nordkvist@outlook.com**
4. If the credential helper is `manager` (Windows Credential Manager), it may push as the WRONG account even if `gh auth status` looks correct. Run `gh auth setup-git` first to ensure git uses the active `gh` account.

**NEVER push, create PRs, or interact with GitHub as LowkeyToq or any other account on this repo.**
