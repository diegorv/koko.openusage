# 03: Background Hub Account Sync

**What to build:** After launch, OpenUsage asks each enabled hub for its account list in the background and saves it as the cached list, so the next launch shows the hub's current accounts without anyone editing the config by hand.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] After launch, an `auth-files` call per enabled hub runs off the launch path and writes the cached `accounts` back to the config. The rest of the config, including the key, stays as it was.
- [ ] A failed sync keeps the old cache and is logged loudly ("The hub could not list accounts."). Cards keep working.
- [ ] Disabled hubs are skipped. Accounts disabled on the hub drop out of the cache.
- [ ] Tests cover a successful sync, a failure keeping the cache, and a write that preserves the other fields.
- [ ] Smoke test: empty the cache, relaunch twice, and see the cards appear on the second launch.
