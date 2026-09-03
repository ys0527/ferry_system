import 'package:ferry_system/complete_profile.dart';
import 'package:ferry_system/home.dart';
import 'package:ferry_system/login.dart';
import 'package:ferry_system/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Stripe.publishableKey =
  'pk_test_51TwayUKyvqb9xJlKM1qZlkpz1VTNASSJ649H0090fSYngnIDp7T99JdTHiLRk3cb7VuS7RuyCdrHpK9kOybEPjig006HJ3M5O4';
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _initialPage() {
    final parameters = Uri.base.queryParameters;
    if (parameters['reset'] == 'true') return const ResetPasswordPage();
    if (parameters['confirmed'] == 'true') return const EmailConfirmedPage();
    if (parameters['emailChanged'] == 'true') {
      return const EmailChangedPage();
    }
    return const AuthGate();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FerryLink Penang',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3472CA)),
        useMaterial3: true,
      ),
      home: _initialPage(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<Widget> _destination = _findDestination();

  Future<Widget> _findDestination() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return const LoginPage();

    final profile = await Supabase.instance.client
        .from('users')
        .select('user_id')
        .eq('auth_id', authUser.id)
        .maybeSingle();

    return profile == null ? const CompleteProfilePage() : const HomePage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const LoginPage();
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!;
      },
    );
  }
}

class EmailConfirmedPage extends StatelessWidget {
  const EmailConfirmedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _StatusPage(
      icon: Icons.mark_email_read_outlined,
      title: 'Your email has been confirmed',
      message: 'You can now log in to FerryLink Penang.',
      buttonText: 'Go to Login',
      onPressed: () async {
        await Supabase.instance.client.auth.signOut();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      },
    );
  }
}

class EmailChangedPage extends StatefulWidget {
  const EmailChangedPage({super.key});

  @override
  State<EmailChangedPage> createState() => _EmailChangedPageState();
}

class _EmailChangedPageState extends State<EmailChangedPage> {
  String _message = 'Confirming your new email...';
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _syncConfirmedEmail();
  }

  Future<void> _syncConfirmedEmail() async {
    try {
      await Supabase.instance.client.auth.refreshSession();
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null || authUser.email == null) {
        throw Exception('Please log in again to finish updating your email.');
      }

      await Supabase.instance.client
          .from('users')
          .update({
        'email': authUser.email,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('auth_id', authUser.id);

      if (!mounted) return;
      setState(() {
        _message = 'Your email has been updated successfully.';
        _isReady = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StatusPage(
      icon: Icons.verified_outlined,
      title: 'Email verification',
      message: _message,
      buttonText: 'Continue',
      onPressed: !_isReady
          ? null
          : () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate()),
              (route) => false,
        );
      },
    );
  }
}

class _StatusPage extends StatelessWidget {
  const _StatusPage({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 72, color: const Color(0xFF3472CA)),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
