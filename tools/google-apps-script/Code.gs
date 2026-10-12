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

/** Run once after entering the properties listed in README.md. */
function setupFloodWatchRelay() {
  const properties = PropertiesService.getScriptProperties();
  requiredProperty_(properties, 'FIREBASE_API_KEY');
  requiredProperty_(properties, 'ALERT_RECIPIENT');
  requiredProperty_(properties, 'ALERT_AREA');

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
    const warnings = readPublishedWarnings_(properties);
    const sentIds = readSentIds_(properties);

    // Avoid sending every old alert on the first run after setup.
    if (properties.getProperty('RELAY_BOOTSTRAPPED') !== 'true') {
      warnings.forEach((warning) => sentIds.add(warning.id));
      writeSentIds_(properties, sentIds);
      properties.setProperty('RELAY_BOOTSTRAPPED', 'true');
      Logger.log('Relay initialized. Existing warnings were marked as seen.');
      return;
    }

    const recipient = requiredProperty_(properties, 'ALERT_RECIPIENT');
    const area = requiredProperty_(properties, 'ALERT_AREA');

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

function readPublishedWarnings_(properties) {
  const projectId = requiredProjectId_(properties);
  const apiKey = requiredProperty_(properties, 'FIREBASE_API_KEY');
  const url =
    'https://firestore.googleapis.com/v1/projects/' +
    encodeURIComponent(projectId) +
    '/databases/(default)/documents:runQuery?key=' +
    encodeURIComponent(apiKey);
  const response = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
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
