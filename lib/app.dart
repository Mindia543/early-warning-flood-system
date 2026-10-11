import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/flood_warning.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';

class FloodWatchApp extends StatelessWidget {
  const FloodWatchApp({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FloodWatch',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f8c)),
      scaffoldBackgroundColor: const Color(0xfff7f9fb),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: firebaseReady ? const AuthGate() : const FirebaseSetupPage(),
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
  const AuthGate({super.key});
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
            ? AuthPage(auth: auth)
            : FloodDashboard(user: snapshot.data!, auth: auth);
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.auth});
  final AuthService auth;
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
  const FloodDashboard({super.key, required this.user, required this.auth});
  final User user;
  final AuthService auth;
  @override
  State<FloodDashboard> createState() => _FloodDashboardState();
}

class _FloodDashboardState extends State<FloodDashboard> {
  late final DatabaseService _database;
  late final NotificationService _notifications;

  @override
  void initState() {
    super.initState();
    _database = DatabaseService();
    _notifications = NotificationService(database: _database);
    _database.createOrUpdateUserProfile(
      displayName: widget.user.displayName ?? '',
      location: '',
      alertsEnabled: true,
    );
    _notifications.initialize();
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
      );
    }
    locationController.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('FloodWatch'),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune),
          tooltip: 'Alert preferences',
          onPressed: _editProfile,
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sign out',
          onPressed: widget.auth.signOut,
        ),
      ],
    ),
    body: StreamBuilder<List<FloodWarning>>(
      stream: _database.watchActiveWarnings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorCard(
            message: 'Could not load warnings: ${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final warnings = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Welcome, ${widget.user.displayName ?? widget.user.email ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text('Active warnings for your registered location.'),
            const SizedBox(height: 20),
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
