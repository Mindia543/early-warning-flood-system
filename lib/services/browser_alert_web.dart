import 'dart:html' as html;

Future<void> requestBrowserAlertPermission() async {
  if (!html.Notification.supported ||
      html.Notification.permission == 'granted') {
    return;
  }
  await html.Notification.requestPermission();
}

Future<void> showBrowserAlert({
  required String title,
  required String body,
}) async {
  if (!html.Notification.supported ||
      html.Notification.permission != 'granted') {
    return;
  }
  html.Notification(title, body: body, icon: 'icons/Icon-192.png');
}
