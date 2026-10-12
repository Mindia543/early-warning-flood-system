import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/flood_warning.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';

const _navy = Color(0xff071827);
const _navy2 = Color(0xff0b2232);
const _cyan = Color(0xff32d5ff);
const _green = Color(0xff2ee68b);
const _text = Color(0xffe9f1f4);
const _muted = Color(0xff96aab4);

class FloodWatchApp extends StatefulWidget {
  const FloodWatchApp({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  State<FloodWatchApp> createState() => _FloodWatchAppState();
}

class _FloodWatchAppState extends State<FloodWatchApp> {
  bool _darkMode = true;

  ThemeData _theme({required bool dark}) {
    final foreground = dark ? _text : const Color(0xff10252d);
    final muted = dark ? _muted : const Color(0xff63757d);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _cyan,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: dark ? _navy : const Color(0xfff4f8f8),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? _navy2 : Colors.white,
        labelStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: dark ? const Color(0xff27404e) : const Color(0xffd6e1e3),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xff142a39) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xff06111f) : Colors.white,
        foregroundColor: foreground,
        elevation: 0,
      ),
      textTheme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
      ).textTheme.apply(bodyColor: foreground, displayColor: foreground),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FloodWatch',
    debugShowCheckedModeBanner: false,
    theme: _theme(dark: false),
    darkTheme: _theme(dark: true),
    themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
    home: widget.firebaseReady
        ? AuthGate(onToggleTheme: () => setState(() => _darkMode = !_darkMode))
        : const FirebaseSetupPage(),
  );
}

class FirebaseSetupPage extends StatelessWidget {
  const FirebaseSetupPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FloodWatch')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Firebase is not connected',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The app is safe to run, but online accounts, Firestore data, and cross-device push notifications are disabled until this project is configured.',
                ),
                const SizedBox(height: 16),
                const Text('Run from the project root:'),
                const SelectableText('flutterfire configure'),
                const SizedBox(height: 12),
                const Text(
                  'Then enable Email/Password sign-in, create Firestore, deploy the rules and notification functions, and rebuild.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;
  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null
            ? AuthPage(auth: auth, onToggleTheme: onToggleTheme)
            : FloodDashboard(
                user: snapshot.data!,
                auth: auth,
                onToggleTheme: onToggleTheme,
              );
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.auth, this.onToggleTheme});
  final AuthService auth;
  final VoidCallback? onToggleTheme;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await widget.auth.register(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
      } else {
        await widget.auth.signIn(email: _email.text, password: _password.text);
      }
    } on FirebaseAuthException catch (error) {
      setState(() => _error = error.message ?? 'Authentication failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.water_drop,
                    size: 52,
                    color: Color(0xff087f8c),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'FloodWatch',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _register
                        ? 'Create your alert account'
                        : 'Sign in to monitor flood risk',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_register) ...[
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const CircularProgressIndicator()
                        : Text(_register ? 'Create account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _register = !_register),
                    child: Text(
                      _register
                          ? 'Already have an account? Sign in'
                          : 'New user? Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FloodDashboard extends StatefulWidget {
  const FloodDashboard({
    super.key,
    required this.user,
    required this.auth,
    required this.onToggleTheme,
  });
  final User user;
  final AuthService auth;
  final VoidCallback onToggleTheme;
  @override
  State<FloodDashboard> createState() => _FloodDashboardState();
}

class _FloodDashboardState extends State<FloodDashboard> {
  late final DatabaseService _database;
  late final NotificationService _notifications;
  late Stream<List<FloodWarning>> _warningStream;
  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();
    _database = DatabaseService();
    _notifications = NotificationService(database: _database);
    _warningStream = _database.watchActiveWarnings();
    _ensureProfile();
    _notifications.initialize();
  }

  Future<void> _ensureProfile() async {
    try {
      final profile = await _database.watchCurrentUserProfile().first;
      if (profile != null) return;
      await _database.createOrUpdateUserProfile(
        displayName: widget.user.displayName ?? '',
        location: '',
        alertsEnabled: true,
        emailAlertsEnabled: true,
      );
    } catch (error) {
      debugPrint('Could not initialize user profile: $error');
    }
  }

  @override
  void dispose() {
    _notifications.dispose();
    super.dispose();
  }

  Future<void> _editProfile() async {
    final profile = await _database.watchCurrentUserProfile().first;
    if (!mounted) return;
    final locationController = TextEditingController(
      text: profile?.location ?? '',
    );
    var alertsEnabled = profile?.alertsEnabled ?? true;
    var emailAlertsEnabled = profile?.emailAlertsEnabled ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Alert preferences'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location / area'),
              ),
              SwitchListTile(
                title: const Text('Receive flood alerts'),
                value: alertsEnabled,
                onChanged: (value) =>
                    setDialogState(() => alertsEnabled = value),
              ),
              SwitchListTile(
                title: const Text('Receive email alerts'),
                value: emailAlertsEnabled,
                onChanged: (value) =>
                    setDialogState(() => emailAlertsEnabled = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _database.createOrUpdateUserProfile(
        displayName: widget.user.displayName ?? '',
        location: locationController.text,
        alertsEnabled: alertsEnabled,
        emailAlertsEnabled: emailAlertsEnabled,
      );
    }
    locationController.dispose();
  }

  String get _initials {
    final name = widget.user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      return parts.take(2).map((part) => part[0].toUpperCase()).join();
    }
    final email = widget.user.email ?? 'FW';
    return email.substring(0, 1).toUpperCase();
  }

  void _refreshWarnings() {
    setState(() => _warningStream = _database.watchActiveWarnings());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 22,
      title: Row(
        children: [
          const Icon(Icons.shield_rounded, color: _cyan, size: 30),
          const SizedBox(width: 10),
          Text(
            'FloodWatch',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: _green.withValues(alpha: .65)),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: _green, size: 10),
                SizedBox(width: 8),
                Text(
                  'System online',
                  style: TextStyle(color: _green, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          tooltip: 'Switch theme',
          onPressed: widget.onToggleTheme,
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Refresh alerts',
          onPressed: _refreshWarnings,
        ),
        PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (value) {
            if (value == 'preferences') _editProfile();
            if (value == 'logout') widget.auth.signOut();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'preferences',
              child: Text('Alert preferences'),
            ),
            PopupMenuItem(value: 'logout', child: Text('Sign out')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(
              backgroundColor: const Color(0xff1f3c4c),
              child: Text(
                _initials,
                style: const TextStyle(
                  color: _cyan,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    body: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashboardRail(
          selected: _selectedNav,
          onSelected: (value) => setState(() => _selectedNav = value),
        ),
        Expanded(
          child: StreamBuilder<List<FloodWarning>>(
            stream: _warningStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(30),
                  children: [
                    _DashboardHeading(user: widget.user),
                    const SizedBox(height: 24),
                    _StatusPanel(
                      icon: Icons.cloud_off_rounded,
                      title: 'Live flood status unavailable',
                      message:
                          'Your dashboard is ready, but we could not reach the latest warning feed.',
                      actionLabel: 'Try again',
                      onAction: _refreshWarnings,
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return ListView(
                  padding: const EdgeInsets.all(30),
                  children: [
                    _DashboardHeading(user: widget.user),
                    const SizedBox(height: 24),
                    const _MetricStrip(loading: true),
                    const SizedBox(height: 20),
                    const _StatusPanel(
                      icon: Icons.radar_rounded,
                      title: 'Checking live flood status',
                      message:
                          'Your home screen is ready. We are looking for active warnings in the background.',
                      showProgress: true,
                    ),
                    const SizedBox(height: 20),
                    _QuickActionsPanel(onEditProfile: _editProfile),
                  ],
                );
              }
              final warnings = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.all(30),
                children: [
                  _DashboardHeading(user: widget.user),
                  const SizedBox(height: 24),
                  _MetricStrip(warningCount: warnings.length),
                  const SizedBox(height: 20),
                  _StatusPanel(
                    icon: warnings.isEmpty
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    title: warnings.isEmpty
                        ? 'All clear in your area'
                        : 'Active flood warnings',
                    message: warnings.isEmpty
                        ? 'No active warnings have been published for your monitored area.'
                        : 'Stay alert and review the warnings below for details.',
                    accent: warnings.isEmpty ? _green : const Color(0xffffc857),
                  ),
                  const SizedBox(height: 20),
                  _QuickActionsPanel(onEditProfile: _editProfile),
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Latest alerts',
                      style: TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (warnings.isEmpty)
                    const _EmptyCard()
                  else
                    ...warnings.map(
                      (warning) => Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.deepOrange,
                          ),
                          title: Text(warning.title),
                          subtitle: Text(
                            '${warning.severity.name.toUpperCase()} • ${warning.affectedArea}',
                          ),
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(warning.title),
                              content: Text(warning.description),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Main dashboard',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Welcome back, ${user.displayName?.isNotEmpty == true ? user.displayName : user.email ?? 'resident'}',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({this.warningCount, this.loading = false});
  final int? warningCount;
  final bool loading;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GridView.count(
      crossAxisCount: constraints.maxWidth < 720 ? 2 : 4,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: constraints.maxWidth < 720 ? 1.8 : 2.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _MetricCard(
          icon: Icons.water_drop_outlined,
          label: 'Active warnings',
          value: loading ? '—' : '${warningCount ?? 0}',
          color: _cyan,
        ),
        const _MetricCard(
          icon: Icons.notifications_active_outlined,
          label: 'Alert status',
          value: 'ON',
          color: _green,
        ),
        const _MetricCard(
          icon: Icons.location_on_outlined,
          label: 'Monitored area',
          value: 'Set location',
          color: Color(0xffffc857),
        ),
        _MetricCard(
          icon: Icons.shield_outlined,
          label: 'Safety status',
          value: loading
              ? 'Checking'
              : (warningCount ?? 0) == 0
              ? 'Clear'
              : 'Caution',
          color: loading || (warningCount ?? 0) > 0
              ? const Color(0xffffc857)
              : _green,
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.accent = _cyan,
    this.actionLabel,
    this.onAction,
    this.showProgress = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showProgress;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (actionLabel != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ),
          ),
          if (showProgress)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    ),
  );
}

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({required this.onEditProfile});
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                icon: Icons.location_on_outlined,
                label: 'Set location',
                onTap: onEditProfile,
              ),
              _ActionButton(
                icon: Icons.notifications_none_rounded,
                label: 'Alert preferences',
                onTap: onEditProfile,
              ),
              const _ActionButton(
                icon: Icons.menu_book_outlined,
                label: 'Safety guidance',
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: _cyan,
      foregroundColor: _navy,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
  );
}

class _DashboardRail extends StatelessWidget {
  const _DashboardRail({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: 128,
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff0c1d2d)
        : const Color(0xffeaf1f2),
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      children: [
        _RailItem(
          icon: Icons.grid_view_rounded,
          label: 'Dashboard',
          selected: selected == 0,
          onTap: () => onSelected(0),
        ),
        _RailItem(
          icon: Icons.warning_amber_rounded,
          label: 'Alerts',
          selected: selected == 1,
          onTap: () => onSelected(1),
        ),
        _RailItem(
          icon: Icons.analytics_outlined,
          label: 'Analytics',
          selected: selected == 2,
          onTap: () => onSelected(2),
        ),
        _RailItem(
          icon: Icons.menu_book_outlined,
          label: 'Guidance',
          selected: selected == 3,
          onTap: () => onSelected(3),
        ),
      ],
    ),
  );
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: selected
            ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xff254656)
                  : const Color(0xffcdebf0))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: selected
                ? _cyan
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 25,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? _cyan
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.verified_outlined, size: 42),
          SizedBox(height: 8),
          Text('No active warnings'),
        ],
      ),
    ),
  );
}
