## Summary

<!-- 1-3 sentences: what does this PR change and why? -->

## Modes affected

<!-- Check what behavior this touches. -->
- [ ] Normal (Right-Option dictation)
- [ ] Friendly (built-in rewrite)
- [ ] Custom (user-defined rewrite)
- [ ] Settings / Onboarding
- [ ] Build / CI / Release pipeline

## Test plan

- [ ] `xcodegen generate && xcodebuild test` passes locally
- [ ] App builds and launches; menu bar icon appears with correct state
- [ ] Manual smoke test for affected modes (see `docs/manual-tests.md`)
- [ ] Pasteboard restoration verified after dictation/rewrite
- [ ] Permissions flow unaffected (or explicitly tested if changed)

## Risks

<!-- Anything reviewer should pay extra attention to (concurrency, force unwraps, IPC, signing/entitlements). -->

## Screenshots / recordings

<!-- For UI changes only. -->
