import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/flood_warning.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/flood_risk_service.dart';
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
  final Set<String> _knownWarningIds = <String>{};
  bool _receivedFirstWarningSnapshot = false;
  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();
    _database = DatabaseService();
    _notifications = NotificationService(database: _database);
    _warningStream = _database.watchActiveWarnings();
    _ensureProfile();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notifications.initialize(
        onMessageReceived: (message) {
          if (!mounted) return;
          _playAlertSound();
          final title = message.notification?.title ?? 'New flood warning';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(title)));
        },
      );
    } catch (error) {
      // A notification permission/token problem must not prevent the dashboard
      // from rendering or signing the user out.
      debugPrint('Could not initialize notifications: $error');
    }
  }

  Future<void> _ensureProfile() async {
    try {
      final profile = await _database.watchCurrentUserProfile().first;
      if (profile != null) return;
      await _database.createOrUpdateUserProfile(
        displayName: widget.user.displayName ?? '',
        location: '',
        alertsEnabled: true,
        emailAlertsEnabled: false,
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
        emailAlertsEnabled: false,
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

  Future<void> _simulateFlood(
    WarningSeverity severity,
    String area,
    String title,
    String description,
    Duration duration,
  ) async {
    try {
      await _database.simulateFlood(
        severity: severity,
        affectedArea: area,
        title: title,
        description: description,
        duration: duration,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live alert published to all signed-in devices.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alert could not be published: $error')),
      );
    }
  }

  Future<void> _playAlertSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (error) {
      debugPrint('Could not play alert sound: $error');
    }
  }

  void _announceNewWarnings(List<FloodWarning> warnings) {
    final currentIds = warnings.map((warning) => warning.id).toSet();
    if (!_receivedFirstWarningSnapshot) {
      _knownWarningIds
        ..clear()
        ..addAll(currentIds);
      _receivedFirstWarningSnapshot = true;
      return;
    }

    final newWarnings = warnings
        .where((warning) => !_knownWarningIds.contains(warning.id))
        .toList();
    _knownWarningIds
      ..clear()
      ..addAll(currentIds);
    if (newWarnings.isEmpty || !mounted) return;

    _playAlertSound();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final first = newWarnings.first;
      final message = newWarnings.length == 1
          ? 'New flood warning: ${first.title}'
          : '${newWarnings.length} new flood warnings received';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(message),
            action: SnackBarAction(label: 'VIEW', onPressed: _refreshWarnings),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      drawer: compact
          ? Drawer(
              child: SafeArea(
                child: _DashboardRail(
                  compact: true,
                  selected: _selectedNav,
                  onSelected: (value) {
                    setState(() => _selectedNav = value);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            )
          : null,
      appBar: AppBar(
        leading: compact
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Open menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        titleSpacing: compact ? 4 : 22,
        title: Row(
          children: [
            Icon(Icons.shield_rounded, color: _cyan, size: compact ? 24 : 30),
            SizedBox(width: compact ? 6 : 10),
            Text(
              'FloodWatch',
              style:
                  (compact
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.titleLarge)
                      ?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
            ),
            if (!compact) ...[
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
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
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Open alerts',
            onPressed: () => setState(() => _selectedNav = 2),
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
              padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 16),
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
          if (!compact)
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
                    padding: _pagePadding(context),
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
                    padding: _pagePadding(context),
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
                      _QuickActionsPanel(
                        onEditProfile: _editProfile,
                        onSimulate: () => setState(() => _selectedNav = 1),
                        onGuidance: () => setState(() => _selectedNav = 4),
                      ),
                    ],
                  );
                }
                final warnings = snapshot.data!;
                _announceNewWarnings(warnings);
                if (_selectedNav == 1) {
                  return _SimulationPage(onSimulate: _simulateFlood);
                }
                if (_selectedNav == 2) {
                  return _AlertsPage(warnings: warnings);
                }
                if (_selectedNav == 3) {
                  return _AnalyticsPage(warnings: warnings);
                }
                if (_selectedNav == 4) {
                  return const _GuidancePage();
                }
                return ListView(
                  padding: _pagePadding(context),
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
                      accent: warnings.isEmpty
                          ? _green
                          : const Color(0xffffc857),
                    ),
                    const SizedBox(height: 20),
                    _QuickActionsPanel(
                      onEditProfile: _editProfile,
                      onSimulate: () => setState(() => _selectedNav = 1),
                      onGuidance: () => setState(() => _selectedNav = 4),
                    ),
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
}

EdgeInsets _pagePadding(BuildContext context) =>
    EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 30);

class _SimulationPage extends StatefulWidget {
  const _SimulationPage({required this.onSimulate});
  final Future<void> Function(
    WarningSeverity severity,
    String area,
    String title,
    String description,
    Duration duration,
  )
  onSimulate;

  @override
  State<_SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<_SimulationPage> {
  final _areaController = TextEditingController();
  final _titleController = TextEditingController(text: 'Flood warning');
  final _descriptionController = TextEditingController(
    text:
        'Water levels are rising. Stay alert, move to higher ground if necessary, and follow local safety guidance.',
  );
  final _waterLevelController = TextEditingController();
  final _rainfallController = TextEditingController();
  final _riseRateController = TextEditingController();
  WarningSeverity _severity = WarningSeverity.high;
  int _durationMinutes = 30;
  bool _submitting = false;
  FloodRiskAssessment? _riskAssessment;

  @override
  void dispose() {
    _areaController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _waterLevelController.dispose();
    _rainfallController.dispose();
    _riseRateController.dispose();
    super.dispose();
  }

  FloodRiskAssessment? _readRiskAssessment() {
    final waterLevel = double.tryParse(_waterLevelController.text.trim());
    final rainfall = double.tryParse(_rainfallController.text.trim());
    final riseRate = double.tryParse(_riseRateController.text.trim());
    if (waterLevel == null || rainfall == null || riseRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter water level, rainfall, and rise rate readings.'),
        ),
      );
      return null;
    }
    if (waterLevel < 0 || rainfall < 0 || riseRate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sensor readings cannot be negative.')),
      );
      return null;
    }
    return FloodRiskService.assess(
      waterLevelCm: waterLevel,
      rainfallMmPerHour: rainfall,
      riseRateCmPerHour: riseRate,
    );
  }

  Future<void> _assessAndPublish() async {
    final assessment = _readRiskAssessment();
    if (assessment == null) return;
    setState(() => _riskAssessment = assessment);
    if (!assessment.shouldAlert) return;
    if (_areaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the affected area before publishing.'),
        ),
      );
      return;
    }

    _severity = assessment.warningSeverity;
    _titleController.text = '${assessment.label}: flood risk detected';
    _descriptionController.text =
        '${assessment.summary}. Risk score ${assessment.score}/105. '
        'Move to higher ground if necessary and follow local safety guidance.';
    await _submit();
  }

  Widget _riskMonitor(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: _cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Early-warning risk monitor',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Use readings from a water-level or rain sensor. FloodWatch combines the readings and publishes an alert when the risk reaches warning level.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _waterLevelController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Water level (cm)',
              prefixIcon: Icon(Icons.water_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rainfallController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Rainfall intensity (mm/hour)',
              prefixIcon: Icon(Icons.water_drop_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _riseRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Water rise rate (cm/hour)',
              prefixIcon: Icon(Icons.trending_up_rounded),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : _assessAndPublish,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Assess conditions and alert if needed'),
            ),
          ),
          if (_riskAssessment != null) ...[
            const SizedBox(height: 16),
            _RiskResult(assessment: _riskAssessment!),
          ],
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    if (_areaController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await widget.onSimulate(
        _severity,
        _areaController.text,
        _titleController.text,
        _descriptionController.text,
        Duration(minutes: _durationMinutes),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: _pagePadding(context),
    children: [
      Text(
        'Create flood alert',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        'Publish a live warning that appears immediately in the Alerts screen on every signed-in device.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 22),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign_outlined, color: _cyan),
                  const SizedBox(width: 10),
                  Text(
                    'Alert details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: 'Affected area',
                  hintText: 'Example: Mubi',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Alert title',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Alert message',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<WarningSeverity>(
                value: _severity,
                decoration: const InputDecoration(
                  labelText: 'Severity',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
                items: WarningSeverity.values
                    .map(
                      (severity) => DropdownMenuItem(
                        value: severity,
                        child: Text(severity.name.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _severity = value);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _durationMinutes,
                decoration: const InputDecoration(
                  labelText: 'Alert duration',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                items: const [15, 30, 60, 180]
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes minutes'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _durationMinutes = value);
                },
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: Text(
                    _submitting
                        ? 'Publishing alert...'
                        : 'Send alert to all devices',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _riskMonitor(context),
      const SizedBox(height: 16),
      _StatusPanel(
        icon: Icons.notifications_active_outlined,
        title: 'Alert delivery',
        message:
            'Published alerts are shared with every signed-in device and expire automatically after the selected duration.',
        accent: const Color(0xffffc857),
      ),
    ],
  );
}

class _RiskResult extends StatelessWidget {
  const _RiskResult({required this.assessment});
  final FloodRiskAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final alert = assessment.shouldAlert;
    final color = assessment.level == FloodRiskLevel.emergency
        ? Colors.redAccent
        : assessment.level == FloodRiskLevel.warning
        ? Colors.deepOrange
        : assessment.level == FloodRiskLevel.watch
        ? const Color(0xffffc857)
        : _green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alert)
            const _BlinkingCautionIcon()
          else
            Icon(Icons.verified_rounded, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${assessment.label} • score ${assessment.score}/105',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(assessment.summary),
                const SizedBox(height: 4),
                Text(
                  alert
                      ? 'The warning was published to signed-in devices.'
                      : 'No alert was published. Continue monitoring the readings.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsPage extends StatelessWidget {
  const _AlertsPage({required this.warnings});
  final List<FloodWarning> warnings;

  @override
  Widget build(BuildContext context) => ListView(
    padding: _pagePadding(context),
    children: [
      Text(
        'Alerts',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        'Live warnings shared with every signed-in device.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 22),
      if (warnings.isEmpty)
        const _EmptyCard()
      else
        ...warnings.map(
          (warning) => Card(
            child: ListTile(
              leading:
                  warning.severity == WarningSeverity.high ||
                      warning.severity == WarningSeverity.severe
                  ? const _BlinkingCautionIcon()
                  : const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.deepOrange,
                    ),
              title: Text(warning.title),
              subtitle: Text(
                '${warning.severity.name.toUpperCase()} • ${warning.affectedArea}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
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
}

class _BlinkingCautionIcon extends StatefulWidget {
  const _BlinkingCautionIcon();

  @override
  State<_BlinkingCautionIcon> createState() => _BlinkingCautionIconState();
}

class _BlinkingCautionIconState extends State<_BlinkingCautionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .35, end: 1).animate(_controller),
    child: const Icon(
      Icons.warning_amber_rounded,
      color: Colors.deepOrange,
      size: 30,
    ),
  );
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage({required this.warnings});
  final List<FloodWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final critical = warnings
        .where(
          (warning) =>
              warning.severity == WarningSeverity.high ||
              warning.severity == WarningSeverity.severe,
        )
        .length;
    final areas = <String, int>{};
    for (final warning in warnings) {
      areas.update(
        warning.affectedArea,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    return ListView(
      padding: _pagePadding(context),
      children: [
        Text(
          'Analytics',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Live metrics from the current warning feed.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            crossAxisCount: constraints.maxWidth < 720 ? 2 : 4,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: constraints.maxWidth < 720 ? 1.8 : 2.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MetricCard(
                icon: Icons.warning_amber_rounded,
                label: 'Active warnings',
                value: '${warnings.length}',
                color: const Color(0xffffc857),
              ),
              _MetricCard(
                icon: Icons.priority_high_rounded,
                label: 'High priority',
                value: '$critical',
                color: Colors.deepOrange,
              ),
              _MetricCard(
                icon: Icons.campaign_outlined,
                label: 'Live alerts',
                value: '${warnings.length}',
                color: _cyan,
              ),
              _MetricCard(
                icon: Icons.location_on_outlined,
                label: 'Affected areas',
                value: '${areas.length}',
                color: _green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Area breakdown',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                if (areas.isEmpty)
                  const Text('No active warning data yet.')
                else
                  ...areas.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GuidancePage extends StatelessWidget {
  const _GuidancePage();

  @override
  Widget build(BuildContext context) => ListView(
    padding: _pagePadding(context),
    children: [
      Text(
        'Safety guidance',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 22),
      const _GuidanceCard(
        icon: Icons.home_work_outlined,
        title: 'Before flooding',
        text:
            'Keep important documents, medication, and a torch in a waterproof bag. Know the safest route to higher ground.',
      ),
      const _GuidanceCard(
        icon: Icons.directions_walk_rounded,
        title: 'During flooding',
        text:
            'Move to higher ground, avoid walking or driving through moving water, and follow official emergency instructions.',
      ),
      const _GuidanceCard(
        icon: Icons.power_off_rounded,
        title: 'After flooding',
        text:
            'Avoid fallen power lines and contaminated water. Return only when local authorities say it is safe.',
      ),
    ],
  );
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(18),
      leading: Icon(icon, color: _cyan, size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text),
      ),
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
  const _QuickActionsPanel({
    required this.onEditProfile,
    this.onSimulate,
    this.onGuidance,
  });
  final VoidCallback onEditProfile;
  final VoidCallback? onSimulate;
  final VoidCallback? onGuidance;

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
              _ActionButton(
                icon: Icons.water_damage_outlined,
                label: 'Simulate flood',
                onTap: onSimulate,
              ),
              _ActionButton(
                icon: Icons.menu_book_outlined,
                label: 'Safety guidance',
                onTap: onGuidance,
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
  const _DashboardRail({
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: compact ? double.infinity : 128,
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
          icon: Icons.campaign_outlined,
          label: 'Create alert',
          selected: selected == 1,
          onTap: () => onSelected(1),
        ),
        _RailItem(
          icon: Icons.warning_amber_rounded,
          label: 'Alerts',
          selected: selected == 2,
          onTap: () => onSelected(2),
        ),
        _RailItem(
          icon: Icons.analytics_outlined,
          label: 'Analytics',
          selected: selected == 3,
          onTap: () => onSelected(3),
        ),
        _RailItem(
          icon: Icons.menu_book_outlined,
          label: 'Guidance',
          selected: selected == 4,
          onTap: () => onSelected(4),
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
