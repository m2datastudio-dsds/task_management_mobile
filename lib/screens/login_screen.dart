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
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      mobileNumber: _mobileNumber.text,
      password: _password.text,
      organizationName: _selectedOrganizationName,
    );
    if (ok && mounted) {
      context.read<AppState>().select(0);
      AppToast.success(context, 'Login successful');
    }
    if (!ok && mounted && !auth.requiresOrganizationSelection) {
      AppToast.error(context, auth.error ?? 'Login failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loading = auth.loading;
    final organizations = auth.organizationOptions;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, Color(0xFF4F46E5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CircleAvatar(
                            radius: 32,
                            backgroundColor: AppTheme.primary,
                            child: Icon(
                              Icons.login,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Ticket Management',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            organizations.isEmpty
                                ? 'Sign in with mobile number and password'
                                : 'Choose organization to continue',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _mobileNumber,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.telephoneNumber
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                              hintText: 'Enter your mobile number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            onChanged: (_) => _clearOrganizationSelection(),
                            validator: (value) {
                              final mobile = value?.trim() ?? '';
                              if (mobile.isEmpty) {
                                return 'Mobile number is required';
                              }
                              final valid =
                                  RegExp(r'^\+?[0-9]{7,15}$').hasMatch(mobile);
                              return valid
                                  ? null
                                  : 'Enter a valid mobile number';
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) {
                              if (!loading) _submit();
                            },
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            onChanged: (_) => _clearOrganizationSelection(),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Password is required'
                                : null,
                          ),
                          if (organizations.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedOrganizationName,
                              decoration: const InputDecoration(
                                labelText: 'Organization',
                                hintText: 'Select organization',
                                prefixIcon: Icon(Icons.business_outlined),
                              ),
                              items: organizations.map((organization) {
                                final name =
                                    organization['name']?.toString() ?? '';
                                return DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(name),
                                );
                              }).toList(),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Please select organization'
                                      : null,
                              onChanged: (value) => setState(
                                () => _selectedOrganizationName = value,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    organizations.isEmpty
                                        ? 'Login'
                                        : 'Continue',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
