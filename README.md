# Our Home

A private shared space for two people in a long-distance relationship.
Flutter + Dart front end, Firebase back end (Auth, Firestore, Storage, Cloud Messaging, Cloud Functions).

Screens follow the `Our Home.pdf` design: **Home, Letters, Memories, Together, Chat**, plus sign-in, couple setup and settings.

## Features

| Screen | What it does |
|---|---|
| Home | Days together with progress to the next 100-day mark, next monthly and yearly milestone, partner presence ("Cooking dinner · online now") and mood, your own mood picker, today's question, a daily note |
| Letters | Received / Sent / Scheduled tabs. Write a letter with photos; deliver now or **seal it for a date**. A sealed letter's text is locked by security rules on the server until it opens. Unread letters get a "New" tag |
| Memories | Photo memories grouped by month, All / Saved moments filter, star to save, add with photo, title and date |
| Together | Daily question (your partner's answer unlocks only after you answer), streak, shared to-do list (swipe to delete), shared goals ("Goal reached" banner) |
| Chat | Real-time text and photos, day separators, Delivered / Read receipts, online status, unread badge |
| Settings | Name, "what are you up to?" status, together-since date, invite code, sign out |

## Setup

You need Flutter 3.22+ and the Firebase CLI.

```bash
# 1. Generate the android/ ios/ web/ folders (keeps lib/ and pubspec.yaml)
flutter create --platforms=android,ios,web --org com.ourhome --project-name our_home .

# 2. Connect a Firebase project (overwrites lib/firebase_options.dart)
firebase login
dart pub global activate flutterfire_cli
flutterfire configure

# 3. In the Firebase console enable:
#    Authentication -> Email/Password, Firestore Database, Storage

# 4. Deploy security rules and indexes
firebase deploy --only firestore:rules,firestore:indexes,storage

# 5. (Optional) push notifications - needs the Blaze plan
cd functions && npm install && cd ..
firebase deploy --only functions

# 6. Run
flutter pub get
flutter run
```

Platform notes:
- **iOS** `ios/Runner/Info.plist`: add `NSPhotoLibraryUsageDescription` (photo picker). For push, enable the Push Notifications capability and upload an APNs key in Firebase.
- **Android** `android/app/build.gradle`: set `minSdkVersion 23` (Firebase). Android 13+ asks for the notification permission at runtime (handled).
- **Web**: push needs a VAPID key; without one the app simply skips notifications.

## How two people connect

1. Person A signs up and taps **Create our space** (picks the day you got together). They get a 6-character invite code (shown on Home and in Settings).
2. Person B signs up and enters the code under **Join your partner**.
3. A space holds exactly two members; the rules reject a third.

## Project layout

```
lib/
  main.dart, app.dart, firebase_options.dart
  providers.dart            Riverpod providers (auth, couple, partner, streams)
  core/                     theme, router (go_router), utils, daily prompts
  models/models.dart        AppUser, Couple, Letter, Memory, TodoItem, Goal, ChatMessage
  data/                     one repository per feature (Firestore + Storage)
  features/                 auth, home, letters, memories, together, chat, settings, shell
  widgets/common.dart       shared cards, avatars, dashed box, image helpers
firestore.rules, storage.rules, firestore.indexes.json, firebase.json
functions/                  Cloud Functions (push notifications)
test/utils_test.dart        milestone / date maths
```

## Firestore data model

```
users/{uid}                  name, email, coupleId, mood, status, lastSeen, fcmTokens
invites/{code}               coupleId, createdBy
couples/{coupleId}           members[2], startDate, inviteCode, streak, lastStreakDate, tzOffsetMinutes
  letters/{id}               fromUid, toUid, title, preview, sealNote, photoCount, createdAt, openAt, readAt, notified
    content/body             body, photoUrls            <- locked until openAt
  memories/{id}              title, photoUrl, date, addedBy, saved
  todos/{id}                 text, done, createdBy, createdAt
  goals/{id}                 title, reachedAt, createdBy, createdAt
  answered/{date}_{uid}      uid, dateKey               <- public "who answered" marker
  answers/{date}_{uid}       uid, dateKey, text         <- partner's is locked until you answered
  messages/{id}              fromUid, text, imageUrl, createdAt, deliveredAt, readAt
Storage: couples/{coupleId}/{letters|memories|chat}/...   (members only, images only, 15 MB max)
```

Design choices worth knowing:
- **Sealed letters are sealed server-side**, not just hidden in the UI: the text lives in `content/body`, and the rules only let the recipient read it once `openAt <= request.time`.
- **Daily question unlock** is enforced by rules too (`answers` read rule checks that you have answered).
- **Shared "couple day"**: you may live in different time zones, so today's question and the streak use the time zone of whoever created the space (`tzOffsetMinutes`), keeping you on the same question.
- **Presence** is a `lastSeen` heartbeat every 60 s; "online" means seen within the last 150 s.
- Membership is always checked against `couples/{id}.members`, never against the user-editable `users/{uid}.coupleId`.

## Status

The code was written against the design PDF but **has not been compiled or run yet**: the build environment could not download the Dart SDK. Expect to fix a few small analyzer issues on the first `flutter analyze`. Please also test the security rules with the Firebase emulator before real use.

The mock-up shows "2 years in 319 days" on 10 Oct 2026; the correct figure is 318 (24 Aug 2027), which is what the app and `test/utils_test.dart` use.
