# Hoopla

Plan an event in a minute, find nearby helpers, and play games people remember.
One Flutter codebase for **iPhone, Android and the web**, with Firebase for saving.

## What's in it

| Tab | What it does |
| --- | --- |
| **Setup** | Occasion, who it's for, date, start time, length, indoor/outdoor, who's coming, guests, party energy |
| **Plan** | Timeline built for your event, a checklist with due dates, and a budget split |
| **Nearby** | 15 helper types (photographers, panthulu, decorators, cake makers, cleaners, transport, anchors, singers, dancers…). Opens the map search, keeps a shortlist with Call, WhatsApp and one-tap quote requests |
| **Games** | 20 party games filtered for your crowd, how-to videos, add/remove from the plan, and **save game reels** from Instagram so you never forget them |
| **Party** | Party-day mode: current game with a countdown timer, team scoreboard, what's up next, invite text, playlist, share plan, return-gift ideas, weather |

How the plan is made (`lib/services/plan_generator.dart`): it sets aside time for
welcome, the key moment (cake, pooja, blessings…), food and goodbyes, then fills
the rest with games that fit your guests, indoor/outdoor, who's coming and the
energy you picked. Kids parties get one icebreaker for the parents too.

## Project layout

```
lib/
  main.dart                 start-up, Firebase or on-device saving
  theme.dart                colors and fonts from the design
  models/event_details.dart the event and everything the user picks
  data/games.dart           game catalog
  data/helpers.dart         nearby helper categories
  services/plan_generator.dart  timeline, games, checklist, budget
  services/event_store.dart     Firestore + on-device storage
  state/app_state.dart      current event, saves every change
  screens/                  setup, plan, nearby, games, party, bottom nav
test/plan_generator_test.dart
firestore.rules, firebase.json
```

## Run it

```bash
flutter create --org com.northbitapps --project-name hoopla --platforms=android,ios,web .
flutter pub get
flutter test
flutter run -d chrome
```

Without Firebase the app saves events on the device. To sync to the cloud:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Then in the Firebase console turn on **Authentication → Anonymous** and create a
**Firestore** database, and deploy the rules:

```bash
firebase deploy --only firestore:rules
```

## Next ideas

- Real vendor listings with Google Places
- Share-sheet integration so a reel can be sent straight from Instagram to Hoopla
- AI-written plans and game ideas through a Cloud Function
- Sign in with Google/Apple so events follow you across devices
- Shared photo album for guests

## Search history (`search_logs`)

Every search and filter choice is saved to the Firestore collection `search_logs`:

| Field | Example |
| --- | --- |
| `type` | `nearby_search`, `nearby_category`, `games_filter`, `plan_created` |
| `query` | `birthday photographer` |
| `filters` | `{category: "Photographers"}` or `{occasion: "Birthday", guests: 40, indoor: true, …}` |
| `device` | `{platform: "ios", name: "iPhone", model: "iPhone16,2", osVersion: "18.1"}` |
| `appVersion` | `0.1.0+1` |
| `ip` | `203.0.113.7` (only when the `logSearch` function is deployed; otherwise `null`) |
| `uid` | the signed-in user's id |
| `createdAt` | server time |

The app can only add entries, never read them; view them in the Firebase console.
The IP comes from the `logSearch` Cloud Function (`functions/index.js`), which needs the Blaze plan:

```bash
cd functions && npm install && cd ..
firebase deploy --only functions,firestore:rules
```

IP address and device details are personal data: mention them in the privacy policy and in
App Store Connect → App Privacy before releasing.

## Accounts, providers and plans

| | Guest | Free account | Basic $3.99/mo | Pro $9.99/mo |
| --- | --- | --- | --- | --- |
| Plan + "Tell us about your event" | ✓ | ✓ | ✓ | ✓ |
| Timeline | first 3 steps | full | full | full |
| Games | 3 | all | all + saved reels | ✓ |
| Checklist | – | ✓ | ✓ | ✓ |
| Budget, Party mode, several events | – | – | ✓ | ✓ |
| Nearby professionals, compare, quotes | – | – | – | ✓ |
| Invites (contacts, SMS, email, WhatsApp, RSVP) | – | – | – | ✓ (coming soon) |

Yearly: $29.99 / $79.99. Prices and features live in `planOffers` in `lib/screens/upgrade_screen.dart`.

- **Give someone a plan:** Firestore → `users/{uid}` → add `plan` = `basic` or `pro` (string). Payments come later.
- **Free trial:** 3 days, one per account (`trialPlan`, `trialStartedAt`, `trialCancelled` on `users/{uid}`, protected by the rules). Cancel from Account. When payments go live, Apple's and Google's 3-day trials take over and renew automatically.
- **Saved reels (free):** in Instagram/TikTok/YouTube tap Share → Hoopla (iPhone share extension `ios/share_extension`, Android share target in `MainActivity.kt`), or paste a link in Games. Reels saved before an event exists join the next event.
- **Test plans locally:** debug builds show a "Developer: test a plan" picker at the bottom of the plans page.
- **Sign in:** Email (everywhere), Google (web), Apple (iPhone). Guests are linked to their new account, so their event comes along.
- **Roles:** customers plan events; providers publish a listing at `providers/{uid}` shown in Nearby.
- **Verified badge:** set `providers/{uid}.verified = true` in the console.
- **Events:** ⋯ menu on the plan → Start new event, My events, Cancel this event (restorable).
- **Delete account:** Account → Delete account (Apple requires this).

## Refer a friend, feedback and ratings

**Refer a friend** (Account → Refer a friend, also on the Plans page). Each signed-in person gets a
6-character invite code. When a friend signs up and enters it, you **both get 1 week of Pro free**.
Every extra friend adds another week on the end.

- `refCodes/{CODE}` says who owns a code. `users/{uid}.refCode` holds your own code.
- `referrals/{friendUid}` is written once per account when a friend joins with a code.
  Its `createdAt` is server time, so the free week can't be faked.
- Invite links look like `https://hoopla-894ca.web.app/?ref=CODE`. The web app keeps the code
  and applies it after sign-up. In the phone app, friends type the code on the sign-up screen.

**Help & feedback** (Account → Help, feedback & rate Hoopla):

- Email us opens mail to northbitapps@gmail.com.
- Send feedback / Report a problem saves type, star rating and comments to the `feedback`
  collection. Read it in the Firebase console (Firestore → feedback). The app can't read it back.
- Rate Hoopla: 4–5 stars opens Apple's review pop-up (or the App Store page), 1–3 stars opens the
  feedback form so you hear about problems first.
- After a couple of party-mode games finish, Hoopla asks "Enjoying Hoopla?" once.

Deploy the rules after pulling: `firebase deploy --only firestore:rules`.

## Provider photo gallery

Providers add up to 12 photos of their work (plus their Instagram and website) when they set up
or edit their listing. Customers see the photos on each provider in Nearby and on the provider's
full page, and can open them full screen.

Photos are stored in Firebase Storage at `providers/{uid}/gallery/`. One-time setup:

1. Firebase console → Build → Storage → Get started (needs the Blaze plan on new projects).
2. `firebase deploy --only storage`
3. For the web app to show photos: `gsutil cors set cors.json gs://BUCKET` (the bucket name is
   `storageBucket` in `lib/firebase_options.dart`).

## Social links and ratings & reviews

- Providers can add Instagram, Facebook, YouTube, TikTok, a link to their reviews elsewhere
  (Google, Yelp, WeddingWire) and a website, plus up to 6 featured reel/video links.
  Customers see them as buttons on the provider's page; each opens in its app.
- Customers rate providers 1–5 stars with a comment at `providers/{uid}/reviews/{reviewerUid}`
  (one review per customer per provider, editable). The average shows on every provider in Nearby.
  Providers can reply to reviews from their home screen.
- Instagram doesn't let other apps show someone's photos without that person connecting their
  account (Meta's Instagram API, needs app review), so the in-app gallery uses photos providers
  upload, and Instagram opens in the Instagram app.

## Reminders (free, phone app)

Scheduled on the phone with `flutter_local_notifications`: no server, works offline, shows even
when Hoopla is closed. The website shows a note instead.

- Each unchecked checklist task reminds at 9 AM (changeable) on its due day; same-day tasks are
  grouped. Overdue tasks get one catch-up reminder. Ticking a task off cancels it.
- Countdown: 1 week before, 6 PM the evening before, and the morning of the party.
- The bell on a task sets your own date and time for it (saved on the event as `taskReminders`).
- Hoopla asks "Want reminders?" once, right after the first party is planned. The switch above
  the checklist turns them on or off.
- Everything is recalculated whenever an event changes (`AppState.syncReminders`), keeping the
  soonest 60 (iOS allows 64). Rules live in `lib/services/reminder_plan.dart` (tested).
