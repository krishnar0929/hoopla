# Testing Hoopla with test data

1. `node scripts/seed_test_data.mjs` creates 54 providers (3 per service type), 5 customers with
   parties, 21 reviews, 3 replies, a referral, a free trial and a feedback message.
2. Every test account's password: `HooplaTest2026!`
3. Remove it all later: `node scripts/seed_test_data.mjs --clean`

## Scenarios

| # | Sign in as | Do this | You should see |
|---|---|---|---|
| 1 | priya@hoopla-test.dev | Open Account | Customer · Pro plan (friend bonus until …) |
| 2 | priya | Nearby → Photographers | 3 studios with photo strips; Lens & Laughter ★ 4.7 (3 reviews) first in rating |
| 3 | priya | Tap Lens & Laughter | Cover photo, Find them on (Instagram, YouTube, TikTok, Website), Featured reels, reviews with "Reply from Lens & Laughter Studio" |
| 4 | priya | Tap a photo | Full-screen viewer, swipe, pinch to zoom |
| 5 | priya | Golden Hour Clicks → Write a review → 5★ | "Thanks!" toast; average updates; "Edit review" button |
| 6 | priya | Edit the same review → Delete my review | Review gone |
| 7 | priya | Account → Refer a friend | Code PRYA26, "1 friend joined", "Pro free until …" |
| 8 | sameer@hoopla-test.dev | Nearby | Locked; upgrade page has "Or get Pro free: invite a friend" |
| 9 | sameer | Refer a friend → enter PRYA26 | Balloons + "A week of Pro, on us!"; Nearby unlocks |
| 10 | sameer | Enter a code again | "You joined with code PRYA26" (only once per account) |
| 11 | anjali@hoopla-test.dev | Account | Pro plan (free trial) with end date and Cancel trial |
| 12 | meera@hoopla-test.dev (iPhone) | Plan → Checklist → turn Reminders on | iPhone asks permission; switch turns lime |
| 13 | meera (iPhone) | 🔔 on a task → set 2 minutes from now → lock phone | Notification arrives |
| 14 | meera (iPhone) | Tick the task before the time | No notification |
| 15 | any customer | Start new event → create | Balloons + "Party planned!", then "Never miss a thing" (first time on the phone) |
| 16 | pro-photographers-1@hoopla-test.dev | Open app | Provider home: Your work (6 photos), social links, 3 reviews |
| 17 | pro-photographers-1 | Reply on Anjali's review | Reply shows under her review (also for customers) |
| 18 | pro-photographers-1 | Edit photos & links → Add photos (iPhone) | Needs Firebase Storage turned on; upload spinner then photo |
| 19 | new account | Sign up as provider → Publish listing | Balloons + "You're live!" |
| 20 | any | Account → Help, feedback & rate Hoopla → Send feedback | "Thanks!"; shows in Firestore → feedback |
| 21 | any | Rate Hoopla → 2★ | Feedback form opens (not the App Store) |
| 22 | any (iPhone) | Party mode → finish 2 game timers | "Enjoying Hoopla? 🎉" once |
| 23 | guest (signed out) | Account → Refer a friend | "Sign in to get your code" |
| 24 | web: open https://hoopla-894ca.web.app/?ref=PRYA26 → sign up | | Code is pre-filled and applied after sign-up |

Notes:
- Test photos come from picsum.photos (random stock photos, not real event photos).
- Test Instagram/TikTok links point to made-up accounts, so they open an empty profile.
