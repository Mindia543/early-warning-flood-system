/**
 * FloodWatch Gmail relay for Firebase Spark projects.
 *
 * This script runs outside Firebase Cloud Functions. It signs in as the
 * FloodWatch account configured in Apps Script properties, reads published
 * warnings through the secured Firestore REST API, and sends Gmail alerts.
 *
 * Never commit the Apps Script properties or the Firebase account password.
 */

const FLOODWATCH_PROJECT_ID = 'early-warning-flood-system';
const FIREBASE_AUTH_ENDPOINT =
  'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword';

/** Run once after entering the properties listed in README.md. */
function setupFloodWatchRelay() {
  const properties = PropertiesService.getScriptProperties();
  requiredProperty_(properties, 'FIREBASE_API_KEY');
  requiredProperty_(properties, 'FIREBASE_AUTH_EMAIL');
  requiredProperty_(properties, 'FIREBASE_AUTH_PASSWORD');
  requiredProperty_(properties, 'ALERT_RECIPIENT');

  ScriptApp.getProjectTriggers()
    .filter((trigger) => trigger.getHandlerFunction() === 'sendNewFloodWarnings')
    .forEach((trigger) => ScriptApp.deleteTrigger(trigger));

  ScriptApp.newTrigger('sendNewFloodWarnings')
    .timeBased()
    .everyMinutes(5)
    .create();

  Logger.log('FloodWatch Gmail relay is scheduled every 5 minutes.');
}

/** Sends a private test message to confirm Gmail authorization. */
function sendFloodWatchTestEmail() {
  const recipient = requiredProperty_(
    PropertiesService.getScriptProperties(),
    'ALERT_RECIPIENT',
  );
  MailApp.sendEmail({
    to: recipient,
    subject: 'FloodWatch Gmail relay test',
    body: 'The free FloodWatch Gmail relay is connected successfully.',
    htmlBody:
      '<h2>FloodWatch Gmail relay test</h2>' +
      '<p>The free Gmail relay is connected successfully.</p>',
    name: 'FloodWatch',
  });
  Logger.log('Test email sent to ' + recipient);
}

/**
 * Polls Firestore for new published warnings and sends matching email alerts.
 * Apps Script time triggers do not run continuously, so delivery may take up
 * to about five minutes.
 */
function sendNewFloodWarnings() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) return;

  try {
    const properties = PropertiesService.getScriptProperties();
    const auth = signIn_(properties);
    const profile = readUserProfile_(auth.idToken, auth.localId, properties);
    const warnings = readPublishedWarnings_(auth.idToken, properties);
    const sentIds = readSentIds_(properties);

    // Avoid sending every old alert on the first run after setup.
    if (properties.getProperty('RELAY_BOOTSTRAPPED') !== 'true') {
      warnings.forEach((warning) => sentIds.add(warning.id));
      writeSentIds_(properties, sentIds);
      properties.setProperty('RELAY_BOOTSTRAPPED', 'true');
      Logger.log('Relay initialized. Existing warnings were marked as seen.');
      return;
    }

    const recipient = properties.getProperty('ALERT_RECIPIENT') || profile.email;
    if (!recipient || !recipient.includes('@')) {
      throw new Error('ALERT_RECIPIENT is missing or invalid.');
    }
    if (profile.emailAlertsEnabled === false) {
      Logger.log('Email alerts are disabled in the FloodWatch profile.');
      return;
    }

    const configuredArea = (properties.getProperty('ALERT_AREA') || '').trim();
    const profileArea = profile.location.trim();
    const area = configuredArea || profileArea;
    if (!area) {
      throw new Error(
        'Set ALERT_AREA or save a monitored location in the FloodWatch profile.',
      );
    }

    warnings
      .filter((warning) => !sentIds.has(warning.id))
      .filter((warning) => warning.affectedArea === area)
      .sort((first, second) => first.issueTime - second.issueTime)
      .forEach((warning) => {
        sendWarningEmail_(recipient, warning);
        sentIds.add(warning.id);
      });

    writeSentIds_(properties, sentIds);
  } finally {
    lock.releaseLock();
  }
}

function signIn_(properties) {
  const apiKey = requiredProperty_(properties, 'FIREBASE_API_KEY');
  const response = UrlFetchApp.fetch(
    FIREBASE_AUTH_ENDPOINT + '?key=' + encodeURIComponent(apiKey),
    {
      method: 'post',
      contentType: 'application/json',
      muteHttpExceptions: true,
      payload: JSON.stringify({
        email: requiredProperty_(properties, 'FIREBASE_AUTH_EMAIL'),
        password: requiredProperty_(properties, 'FIREBASE_AUTH_PASSWORD'),
        returnSecureToken: true,
      }),
    },
  );
  const body = JSON.parse(response.getContentText());
  if (response.getResponseCode() !== 200 || !body.idToken) {
    throw new Error('Firebase sign-in failed: ' + JSON.stringify(body));
  }
  return { idToken: body.idToken, localId: body.localId };
}

function readUserProfile_(idToken, localId, properties) {
  const document = firestoreGet_(
    idToken,
    properties,
    'users/' + encodeURIComponent(localId),
  );
  const fields = document.fields || {};
  return {
    email: stringValue_(fields.email),
    location: stringValue_(fields.location),
    emailAlertsEnabled: booleanValue_(fields.emailAlertsEnabled, true),
  };
}

function readPublishedWarnings_(idToken, properties) {
  const projectId = requiredProjectId_(properties);
  const url =
    'https://firestore.googleapis.com/v1/projects/' +
    encodeURIComponent(projectId) +
    '/databases/(default)/documents:runQuery';
  const response = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + idToken },
    muteHttpExceptions: true,
    payload: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'warnings' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'status' },
            op: 'EQUAL',
            value: { stringValue: 'published' },
          },
        },
        limit: 100,
      },
    }),
  });
  const body = JSON.parse(response.getContentText());
  if (response.getResponseCode() !== 200) {
    throw new Error('Firestore warning query failed: ' + JSON.stringify(body));
  }

  return body
    .filter((row) => row.document)
    .map((row) => warningFromDocument_(row.document));
}

function firestoreGet_(idToken, properties, path) {
  const projectId = requiredProjectId_(properties);
  const url =
    'https://firestore.googleapis.com/v1/projects/' +
    encodeURIComponent(projectId) +
    '/databases/(default)/documents/' +
    path;
  const response = UrlFetchApp.fetch(url, {
    headers: { Authorization: 'Bearer ' + idToken },
    muteHttpExceptions: true,
  });
  const body = JSON.parse(response.getContentText());
  if (response.getResponseCode() !== 200) {
    throw new Error('Firestore profile read failed: ' + JSON.stringify(body));
  }
  return body;
}

function warningFromDocument_(document) {
  const fields = document.fields || {};
  const nameParts = document.name.split('/');
  return {
    id: nameParts[nameParts.length - 1],
    title: stringValue_(fields.title),
    description: stringValue_(fields.description),
    severity: stringValue_(fields.severity),
    affectedArea: stringValue_(fields.affectedArea),
    source: stringValue_(fields.source),
    issueTime: dateValue_(fields.issueTime),
  };
}

function sendWarningEmail_(recipient, warning) {
  const title = 'Flood warning: ' + warning.severity;
  const body = [
    warning.title,
    '',
    warning.description,
    '',
    'Affected area: ' + warning.affectedArea,
    'Source: ' + warning.source,
    'Warning ID: ' + warning.id,
    '',
    'Open FloodWatch to view the complete warning.',
  ].join('\n');

  MailApp.sendEmail({
    to: recipient,
    subject: title,
    body: body,
    htmlBody:
      '<h2>' + escapeHtml_(title) + '</h2>' +
      '<p>' + escapeHtml_(warning.description) + '</p>' +
      '<p><strong>Affected area:</strong> ' +
      escapeHtml_(warning.affectedArea) + '<br><strong>Source:</strong> ' +
      escapeHtml_(warning.source) + '</p>' +
      '<p>Open FloodWatch to view the complete warning.</p>',
    name: 'FloodWatch',
  });
  Logger.log('Sent warning ' + warning.id + ' to ' + recipient);
}

function requiredProperty_(properties, name) {
  const value = properties.getProperty(name);
  if (!value || !value.trim()) {
    throw new Error('Missing Apps Script property: ' + name);
  }
  return value.trim();
}

function requiredProjectId_(properties) {
  return properties.getProperty('FIREBASE_PROJECT_ID') || FLOODWATCH_PROJECT_ID;
}

function readSentIds_(properties) {
  const raw = properties.getProperty('SENT_WARNING_IDS');
  if (!raw) return new Set();
  try {
    return new Set(JSON.parse(raw));
  } catch (error) {
    return new Set();
  }
}

function writeSentIds_(properties, ids) {
  const values = Array.from(ids).slice(-1000);
  properties.setProperty('SENT_WARNING_IDS', JSON.stringify(values));
}

function stringValue_(field) {
  return field && field.stringValue ? String(field.stringValue) : '';
}

function booleanValue_(field, fallback) {
  return field && typeof field.booleanValue === 'boolean'
    ? field.booleanValue
    : fallback;
}

function dateValue_(field) {
  const value = field && field.timestampValue;
  return value ? new Date(value).getTime() : 0;
}

function escapeHtml_(value) {
  return String(value).replace(/[&<>\"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '\"': '&quot;',
    "'": '&#039;',
  })[character] || character);
}
