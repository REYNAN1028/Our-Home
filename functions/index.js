// Push notifications for Our Home.
// Needs the Blaze plan (scheduled functions + outbound messaging).
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

async function nameOf(uid) {
  const snap = await db.collection("users").doc(uid).get();
  return (snap.data() && snap.data().name) || "Your partner";
}

async function push(uid, title, body, data = {}) {
  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  const tokens = (snap.data() && snap.data().fcmTokens) || [];
  if (tokens.length === 0) return;

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });

  // Drop tokens that are no longer valid.
  const dead = [];
  res.responses.forEach((r, i) => {
    const code = r.error && r.error.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      dead.push(tokens[i]);
    }
  });
  if (dead.length) {
    await userRef.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead) });
  }
}

// New chat message -> notify the other person.
exports.onMessageCreated = onDocumentCreated(
  "couples/{coupleId}/messages/{messageId}",
  async (event) => {
    const msg = event.data && event.data.data();
    if (!msg) return;
    const couple = await db.collection("couples").doc(event.params.coupleId).get();
    const members = (couple.data() && couple.data().members) || [];
    const toUid = members.find((m) => m !== msg.fromUid);
    if (!toUid) return;
    const sender = await nameOf(msg.fromUid);
    await push(toUid, sender, msg.text || "Sent you a photo", { type: "message" });
  }
);

// New letter that is already deliverable -> notify now.
exports.onLetterCreated = onDocumentCreated(
  "couples/{coupleId}/letters/{letterId}",
  async (event) => {
    const letter = event.data && event.data.data();
    if (!letter) return;
    if (letter.openAt.toMillis() > Date.now()) return; // scheduled: handled below
    const sender = await nameOf(letter.fromUid);
    await push(letter.toUid, `A letter from ${sender}`, letter.title, {
      type: "letter",
      letterId: event.params.letterId,
    });
    await event.data.ref.update({ notified: true });
  }
);

// Scheduled letters whose time has come.
exports.deliverScheduledLetters = onSchedule("every 15 minutes", async () => {
  const due = await db
    .collectionGroup("letters")
    .where("notified", "==", false)
    .where("openAt", "<=", admin.firestore.Timestamp.now())
    .get();

  for (const doc of due.docs) {
    const letter = doc.data();
    const sender = await nameOf(letter.fromUid);
    await push(letter.toUid, `A letter from ${sender} just opened`, letter.title, {
      type: "letter",
      letterId: doc.id,
    });
    await doc.ref.update({ notified: true });
  }
});
