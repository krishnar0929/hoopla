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
- **Test plans locally:** debug builds show a "Developer: test a plan" picker at the bottom of the plans page.
- **Sign in:** Email (everywhere), Google (web), Apple (iPhone). Guests are linked to their new account, so their event comes along.
- **Roles:** customers plan events; providers publish a listing at `providers/{uid}` shown in Nearby.
- **Verified badge:** set `providers/{uid}.verified = true` in the console.
- **Events:** ⋯ menu on the plan → Start new event, My events, Cancel this event (restorable).
- **Delete account:** Account → Delete account (Apple requires this).
