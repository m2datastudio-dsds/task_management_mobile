import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'providers/auth_provider.dart';
import 'providers/bank_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/organization_provider.dart';
import 'providers/task_provider.dart';
import 'providers/user_provider.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'utils/app_theme.dart';
import 'utils/app_toast.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskMobileApp());
}

class TaskMobileApp extends StatelessWidget {
  const TaskMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiClient()),
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProxyProvider<ApiClient, AuthProvider>(
          create: (context) => AuthProvider(context.read<ApiClient>()),
          update: (_, api, previous) => previous ?? AuthProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiClient, DashboardProvider>(
          create: (context) => DashboardProvider(context.read<ApiClient>()),
          update: (_, api, previous) => previous ?? DashboardProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiClient, BankProvider>(
          create: (context) => BankProvider(context.read<ApiClient>()),
          update: (_, api, previous) => previous ?? BankProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiClient, TaskProvider>(
          create: (context) => TaskProvider(context.read<ApiClient>()),
          update: (_, api, previous) => previous ?? TaskProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiClient, ExpenseProvider>(
          create: (context) => ExpenseProvider(context.read<ApiClient>()),
          update: (_, api, previous) => previous ?? ExpenseProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiClient, OrganizationProvider>(
          create: (context) => OrganizationProvider(context.read<ApiClient>()),
          update: (_, api, previous) => previous ?? OrganizationProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiClient, UserProvider>(
          create: (context) => UserProvider(context.read<ApiClient>()),
          update: (_, api, previous) => previous ?? UserProvider(api),
        ),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: AppToast.messengerKey,
        debugShowCheckedModeBanner: false,
        title: 'Ticket Management',
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<void> _restore;

  @override
  void initState() {
    super.initState();
    _restore = context.read<AuthProvider>().restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Consumer<AuthProvider>(
          builder: (_, auth, __) {
            return auth.isAuthenticated
                ? const AppShell()
                : const LoginScreen();
          },
        );
      },
    );
  }
}
