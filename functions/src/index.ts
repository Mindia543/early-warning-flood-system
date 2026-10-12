import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, QueryDocumentSnapshot } from "firebase-admin/firestore";
import { getMessaging, MulticastMessage } from "firebase-admin/messaging";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import nodemailer from "nodemailer";

initializeApp();

const db = getFirestore();
const smtpUser = defineSecret("SMTP_USER");
const smtpPassword = defineSecret("SMTP_PASSWORD");
const emailFromName = defineString("EMAIL_FROM_NAME", { default: "FloodWatch" });

type WarningData = {
  title: string;
  description: string;
  severity: string;
  affectedArea: string;
  expiryTime?: { toDate: () => Date };
  source: string;
};

/**
 * Publishing remains an authenticated server operation. Firestore rules also
 * require the admin custom claim, so this function is an additional guard and
 * gives the Flutter app a single, auditable publish path.
 */
export const publishWarning = onCall(async (request) => {
  if (!request.auth?.token.admin) {
    throw new HttpsError("permission-denied", "Administrator access is required.");
  }

  const warningId = request.data?.warningId;
  if (typeof warningId !== "string" || warningId.trim() === "") {
    throw new HttpsError("invalid-argument", "warningId is required.");
  }

  const warningRef = db.collection("warnings").doc(warningId);
  const warning = await warningRef.get();
  if (!warning.exists) throw new HttpsError("not-found", "Warning not found.");
  if (warning.data()?.status !== "draft") {
    throw new HttpsError("failed-precondition", "Only draft warnings can be published.");
  }

  await warningRef.update({
    status: "published",
    issueTime: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { warningId };
});

/** Sends one push notification to every enabled device for users in the area. */
export const sendWarningNotifications = onDocumentUpdated(
  { document: "warnings/{warningId}", secrets: [smtpUser, smtpPassword] },
  async (event) => {
    const before = event.data?.before.data() as WarningData | undefined;
    const afterSnapshot = event.data?.after;
    const after = afterSnapshot?.data() as WarningData | undefined;
    if (!before || !after || before.status === "published" || after.status !== "published") {
      return;
    }

    const warningId = event.params.warningId;
    const users = await db
      .collection("users")
      .where("location", "==", after.affectedArea)
      .get();

    for (const user of users.docs) {
      await notifyUser(user, warningId, after);
    }
  },
);

async function notifyUser(
  user: QueryDocumentSnapshot,
  warningId: string,
  warning: WarningData,
): Promise<void> {
  await sendWarningEmail(user, warningId, warning);

  if (user.data().alertsEnabled !== true) {
    await writeLog(user.id, warningId, "skipped", 0, "Push alerts are disabled.", "push");
    return;
  }

  const devices = await user.ref.collection("devices").where("enabled", "==", true).get();
  const tokens = devices.docs
    .map((device) => device.data().token)
    .filter((token): token is string => typeof token === "string" && token.length > 0);

  if (tokens.length === 0) {
    await writeLog(user.id, warningId, "skipped", 0, "No enabled devices.");
    return;
  }

  const message: MulticastMessage = {
    tokens,
    notification: {
      title: `Flood warning: ${warning.severity}`,
      body: warning.title,
    },
    data: {
      warningId,
      affectedArea: warning.affectedArea,
      severity: warning.severity,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: { priority: "high", notification: { channelId: "flood_warnings" } },
    webpush: { fcmOptions: { link: "/alerts/" + warningId } },
  };

  try {
    const response = await getMessaging().sendEachForMulticast(message);
    await writeLog(
      user.id,
      warningId,
      response.failureCount === 0 ? "sent" : "partial_failure",
      response.successCount,
      response.failureCount === 0 ? null : `${response.failureCount} device(s) failed.`,
    );

    // Invalid tokens must not be retried forever. The next token refresh will
    // create a new device record when the user opens the app again.
    await Promise.all(
      response.responses.map(async (result, index) => {
        if (!result.success && isPermanentTokenError(result.error?.code)) {
          await devices.docs[index].ref.update({ enabled: false, lastError: result.error?.code });
        }
      }),
    );
  } catch (error) {
    await writeLog(user.id, warningId, "failed", 0, String(error));
    throw error;
  }
}

async function sendWarningEmail(
  user: QueryDocumentSnapshot,
  warningId: string,
  warning: WarningData,
): Promise<void> {
  const data = user.data();
  const recipient = data.email;
  if (data.emailAlertsEnabled === false) {
    await writeLog(user.id, warningId, "skipped", 0, "Email alerts are disabled.", "email");
    return;
  }
  if (typeof recipient !== "string" || !recipient.includes("@")) {
    await writeLog(user.id, warningId, "skipped", 0, "User has no valid email address.", "email");
    return;
  }

  const title = `Flood warning: ${warning.severity}`;
  const plainText = [
    warning.title,
    "",
    warning.description,
    "",
    `Affected area: ${warning.affectedArea}`,
    `Source: ${warning.source}`,
    `Warning ID: ${warningId}`,
  ].join("\\n");

  try {
    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      auth: { user: smtpUser.value(), pass: smtpPassword.value() },
    });
    await transporter.sendMail({
      from: `"${emailFromName.value()}" <${smtpUser.value()}>`,
      to: recipient,
      subject: title,
      text: plainText,
      html: `<h2>${escapeHtml(title)}</h2><p>${escapeHtml(warning.description)}</p><p><strong>Affected area:</strong> ${escapeHtml(warning.affectedArea)}<br><strong>Source:</strong> ${escapeHtml(warning.source)}</p><p>Open FloodWatch to view the complete warning.</p>`,
    });
    await writeLog(user.id, warningId, "sent", 1, null, "email");
  } catch (error) {
    await writeLog(user.id, warningId, "failed", 0, String(error), "email");
  }
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>\"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#039;",
  })[character] ?? character);
}

function isPermanentTokenError(code?: string): boolean {
  return code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token";
}

async function writeLog(
  userId: string,
  warningId: string,
  status: string,
  deliveredCount: number,
  error: string | null,
  channel = "push",
): Promise<void> {
  await db.collection("notification_logs").add({
    userId,
    warningId,
    status,
    deliveredCount,
    error,
    channel,
    createdAt: FieldValue.serverTimestamp(),
  });
}
