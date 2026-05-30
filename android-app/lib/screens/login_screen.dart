import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _urlCtrl = TextEditingController(
    text: 'https://francoise-subhumid-maire.ngrok-free.dev');
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppProvider>().login(
        _urlCtrl.text.trim(), _pinCtrl.text.trim());
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3009),
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🌾', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 8),
          const Text('CONCENTRADOS MONSERRATH', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFD4800A),
            letterSpacing: 1.2)),
          const SizedBox(height: 4),
          const Text('Sistema de Pedidos', style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Sistema de gestión WhatsApp',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 40),
          Card(child: Padding(padding: const EdgeInsets.all(24),
            child: Column(children: [
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL del servidor',
                  prefixIcon: Icon(Icons.link)),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinCtrl,
                decoration: const InputDecoration(
                  labelText: 'PIN de acceso',
                  prefixIcon: Icon(Icons.lock)),
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: _loading ? null : _login,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5016),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _loading
                  ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Ingresar', style: TextStyle(fontSize: 16)),
              )),
            ]))),
        ]),
      ))),
    );
  }
}
