import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileNumber = TextEditingController();
  final _password = TextEditingController();
  String? _selectedOrganizationName;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _mobileNumber.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearOrganizationSelection() {
    _selectedOrganizationName = null;
    context.read<AuthProvider>().clearOrganizationOptions();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      mobileNumber: _mobileNumber.text,
      password: _password.text,
      organizationName: _selectedOrganizationName,
    );
    if (!mounted) return;
    if (ok) {
      context.read<AppState>().select(0);
      AppToast.success(context, 'Welcome back');
    } else if (!auth.requiresOrganizationSelection) {
      AppToast.error(context, auth.error ?? 'Unable to sign in');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: width < 600 ? 20 : 40,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Row(
                    children: [
                      if (desktop) ...[
                        const Expanded(child: _BrandPanel()),
                        const SizedBox(width: 72),
                      ],
                      Expanded(
                        flex: desktop ? 1 : 0,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _buildCard(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final organizations = auth.organizationOptions;
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  _AppMark(size: 46),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ticket Management',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _VersionBadge(),
                ],
              ),
              const SizedBox(height: 34),
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                organizations.isEmpty
                    ? 'Enter your details to access your workspace.'
                    : 'Select the workspace you want to continue to.',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              const _FieldLabel('Mobile number'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mobileNumber,
                enabled: !auth.loading,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  hintText: 'e.g. 9876543210',
                  prefixIcon: Icon(Icons.phone_iphone_rounded, size: 20),
                ),
                onChanged: (_) => _clearOrganizationSelection(),
                validator: (value) {
                  final mobile = value?.trim() ?? '';
                  if (mobile.isEmpty) return 'Enter your mobile number';
                  return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(mobile)
                      ? null
                      : 'Enter a valid mobile number';
                },
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _password,
                enabled: !auth.loading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) {
                  if (!auth.loading) _submit();
                },
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                onChanged: (_) => _clearOrganizationSelection(),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password'
                    : null,
              ),
              if (organizations.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _FieldLabel('Workspace'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedOrganizationName,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Select a workspace',
                    prefixIcon: Icon(Icons.apartment_rounded, size: 20),
                  ),
                  items: organizations.map((organization) {
                    final name = organization['name']?.toString() ?? '';
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Select a workspace'
                      : null,
                  onChanged: auth.loading
                      ? null
                      : (value) => setState(
                            () => _selectedOrganizationName = value,
                          ),
                ),
              ],
              const SizedBox(height: 26),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.loading ? null : _submit,
                  child: auth.loading
                      ? const SizedBox(
                          height: 21,
                          width: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                organizations.isEmpty ? 'Sign in' : 'Continue'),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              const Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Icon(Icons.lock_rounded, size: 13, color: AppTheme.muted),
                  Text(
                    'Your account is securely protected',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppMark(size: 64),
        SizedBox(height: 32),
        Text(
          'Keep every ticket\nmoving forward.',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 46,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.6,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Track requests, coordinate your team, and resolve\nwork from one clear workspace.',
          style: TextStyle(color: AppTheme.muted, fontSize: 17, height: 1.6),
        ),
        SizedBox(height: 38),
        _Feature(Icons.inbox_rounded, 'One place for every request'),
        SizedBox(height: 16),
        _Feature(Icons.bolt_rounded, 'Faster handoffs and resolutions'),
        SizedBox(height: 16),
        _Feature(Icons.query_stats_rounded, 'Clear progress at a glance'),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Color(0x0D0F172A), blurRadius: 14)
              ],
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 13),
          Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      );
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(size * .28),
          boxShadow: const [
            BoxShadow(
                color: Color(0x332563EB), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Icon(Icons.confirmation_number_rounded,
            color: Colors.white, size: size * .52),
      );
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'v0.1',
          style: TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w800),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w700),
      );
}

class _Background extends StatelessWidget {
  const _Background();
  @override
  Widget build(BuildContext context) => ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: -170,
              top: -220,
              child: Container(
                width: 520,
                height: 520,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [Color(0x242563EB), Color(0x002563EB)]),
                ),
              ),
            ),
            Positioned(
              right: -200,
              bottom: -260,
              child: Container(
                width: 620,
                height: 620,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [Color(0x184F46E5), Color(0x004F46E5)]),
                ),
              ),
            ),
          ],
        ),
      );
}
