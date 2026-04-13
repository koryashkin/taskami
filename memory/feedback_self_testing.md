---
name: Self-testing policy
description: User requires Claude to run tests and verify fixes in the simulator autonomously — never ask the user to test
type: feedback
---

Always verify UI changes yourself using the simulator and automated tests before reporting a fix as complete. Never ask the user to tap, reproduce, or verify anything manually.

**Why:** User explicitly requested this after being asked to test done/undone toggle multiple times.

**How to apply:**
1. After any UI change, run `build_run_sim` then `test_sim -only-testing TaskamiUITests`
2. If no test covers the scenario, write one first (confirm it fails), then fix, then confirm it passes
3. Only say a fix is done after tests pass
