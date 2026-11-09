# Samppan Sarees — keep working until live (scheduled task prompt, every 3 hours)

You are continuing the owner's (Akshay Nahata, B.B Synthetics) Samppan Sarees retail app project. Work silently and finish what is unfinished. Reply to the owner in English, as a few short bullets, ONLY about what changed or what he must do.

FIRST read the memory file C:\Users\4001C\.claude\projects\C--Users-4001C-OneDrive-CLE\memory\sappan_sarees_app.md (full project facts and rules). Hard rules: NEVER change the B.B Synthetics app (bb-repo) or its cloud; never write "Surat"; no WhatsApp/call/share; nothing in the app may show the B.B logo or reveal it is B.B; never publish a modelling photo nobody checked by eye; ₹0 tools only; no multi-agent workflows.

Project: C:\Users\4001C\sappan-repo (GitHub aknzone-afk/sappan-sarees-app, public). Store helpers in tools\store_api: asc.js (App Store Connect API), play.js (Google Play; `node play.js` prints tracks), play_upload.js, asc_shots.js, play_shots.js. Keys stay in C:\BotSecrets. ASC app id 6826903241, version id 1c2ff4dc-ff65-4f3d-8d78-2f4f44da9d25, review detail 56f39edf-cdc9-42a5-b75e-81d526b95e90. Play package com.sappansarees.retailapp.

EACH RUN, in order:
1. App Store: read the version state and latest reviewSubmissions.
   - WAITING_FOR_REVIEW / IN_REVIEW: nothing to do.
   - REJECTED / UNRESOLVED_ISSUES: read Apple's message (App Store Connect › App Review in the built-in browser; if not signed in, ask the owner to sign in and stop). Fix the real cause, answer in the App Review notes (truthfully — the review video is from the iPhone simulator), build a new build if code changed (bump app/pubspec.yaml build number, run GitHub workflow "iOS TestFlight", wait for VALID, attach it), then submit a new reviewSubmission.
   - PENDING_DEVELOPER_RELEASE: release it. READY_FOR_SALE: App Store done — tell the owner once.
2. Google Play: `node play.js`. Keep the closed (alpha) release completed. Production needs a closed test with ≥12 testers for 14 days — if not set up, remind the owner at most once a day (Play Console › Testing › Closed testing › add 12 Gmail ids). When eligible, promote the latest versionCode to production.
3. Modelling photos: look at every photo in tools\model_clean\review\ not yet on approved.txt / blocklist.txt (contact sheet of the top half). Approve only with no B.B logo/monogram/"Synthetics"/"Designing your dreams"/design number/©/™ trace and no smudge on the model, saree or inset photos. Then `python sync.py` (no --push) must keep the known set "unchanged" and the published-design count must not drop; only then `python sync.py --push`. If the count would drop, stop and restore from git.
4. Windows task "Samppan model photos": if its last run is older than 26 h or failed, start it and check tools\model_clean\sync.log.
5. Update the memory file with new facts (short, dated).

When BOTH stores are live and the review folder is empty: tell the owner "Samppan Sarees is live on both stores" and disable this scheduled task.
