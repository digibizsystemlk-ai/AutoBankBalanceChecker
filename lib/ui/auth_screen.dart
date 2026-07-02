import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'dashboard.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticated = false;
  String _authMessage = 'Authentication Required';

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        // Fallback for devices without biometric support
        setState(() {
          _isAuthenticated = true;
        });
        _navigateToDashboard();
        return;
      }

      authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access Auto Bank Balance Checker',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      setState(() {
        _authMessage = 'Error: \${e.message}';
      });
      return;
    }

    if (!mounted) return;

    if (authenticated) {
      setState(() {
        _isAuthenticated = true;
      });
      _navigateToDashboard();
    } else {
      setState(() {
        _authMessage = 'Authentication Failed. Try Again.';
      });
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 100,
              color: Colors.teal,
            ),
            const SizedBox(height: 20),
            Text(
              _authMessage,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),
            if (!_isAuthenticated)
              ElevatedButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Authenticate Again'),
                onPressed: _authenticate,
              ),
          ],
        ),
      ),
    );
  }
}
