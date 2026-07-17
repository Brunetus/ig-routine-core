# ig-routine-core — shared STRUCTURAL source for all IG daily routines

This folder is the single source of truth for HOW Marcus's Instagram daily
routines work — for every account (currently: imabgold, bambi.map). Sessions
opened here discuss and edit STRUCTURE ONLY.

## Scope rules

- **Structural = this repo.** Launcher mechanics (run-daily-core.sh), the
  daily step skeleton and its mechanics (ROUTINE-CORE.md): logging, retries,
  resume-from-state, TEST-MODE, concurrency, API pre-flight, iCloud outbox,
  Photos staging mechanics, ledger conventions, QA process, notifications.
- **Content = the account folders.** Voice, face/privacy rules specific to a
  family member, formats, budgets, success criteria, material lanes live in
  each account's ROUTINE file + brand.md (`~/Claude Code/imabgold-ig/`,
  `~/Claude Code/bambi-highchair-ig/`). Never put account-specific content
  here; never edit structure in an account folder — move it here instead.
- Everything here must stay ACCOUNT-AGNOSTIC: parameterized by the wrapper
  variables (see run-daily-core.sh header), no hardcoded account names,
  albums, or budgets.

## How changes propagate

Each account's `routine/run-daily.sh` is a thin wrapper that sets variables
and `source`s `run-daily-core.sh`; each account's ROUTINE file tells the
agent to read `ROUTINE-CORE.md` FIRST. So an edit committed here is live for
EVERY account's next run — no per-account copying.

## After any change

1. `zsh -n run-daily-core.sh` (syntax).
2. TEST-MODE both accounts through launchd (never run the scripts directly —
   TCC context differs):
   `touch ~/Claude\ Code/imabgold-ig/routine/TEST-MODE && launchctl kickstart gui/501/com.marcus.imabgold-daily`
   `touch ~/Claude\ Code/bambi-highchair-ig/routine/TEST-MODE && launchctl kickstart gui/501/com.marcus.bambi-daily`
   then check each `routine/logs/<today>.log`.
3. Never kickstart a real run while the other account's routine is running
   mid-creation unless you intend the wait.
4. Commit here with a message saying WHAT structural rule changed and why.
5. Per Marcus's standing rule: independent adversarial audit before calling a
   structural change done.

## Schedule map (LaunchAgents, unchanged by this repo)

- com.marcus.viral-scan → Mon+Thu 8:00 AM → ig-routine-core/run-viral-scan.sh
  (viral clip bank scan per BANK.md; data in ~/Claude Code/viral-bank/; NOT
  an account wrapper — it must never source run-daily-core.sh. Test:
  `touch ~/Claude\ Code/viral-bank/TEST-MODE && launchctl kickstart gui/501/com.marcus.viral-scan`)
- com.marcus.imabgold-daily → 9:00 AM → imabgold-ig/routine/run-daily.sh
- com.marcus.bambi-daily → 9:30 AM → bambi-highchair-ig/routine/run-daily.sh
  (bambi additionally waits for imabgold via WAIT_FOR; imabgold never waits —
  this asymmetry is deliberate, it prevents deadlock on simultaneous wake)
- com.marcus.reel-worker → every 10 min → ig-routine-core/run-reel-worker.sh
  (reels.ibuildapp.ca customer jobs per JOBS.md; yields 08:30-10:30 and to
  any running daily/scan; data in reel-app/jobs/. Test:
  `touch ~/Claude\ Code/reel-app/jobs/TEST-MODE && launchctl kickstart gui/501/com.marcus.reel-worker`)
- (com.bambi.outreach-discovery + outreach-send are PAUSED as of 2026-07-17,
  renamed .plist.disabled — the Mon 8:00 slot now belongs to viral-scan)
