import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../providers/auth_provider.dart';
import '../providers/bank_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/organization_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../utils/roles.dart';
import '../utils/organization_terminology.dart';
import 'dashboard_screen.dart';
import 'bank_management_screen.dart';
import 'expense_list_screen.dart';
import 'notifications_screen.dart';
import 'organization_screen.dart';
import 'profile_screen.dart';
import 'purchase_order_list_screen.dart';
import 'role_management_screen.dart';
import 'task_list_screen.dart';
import 'user_management_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().select(0);
      _refreshAll();
    });
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshAll(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    if (!mounted || _refreshing) return;

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (!auth.isAuthenticated || user == null) return;

    _refreshing = true;
    try {
      final isAdmin = Roles.isAdminLike(user.role);
      final isSuperAdmin = Roles.isSuperAdmin(user.role);
      final refreshes = <Future<void>>[
        if (context.read<TaskProvider>().hasLoadedTasks)
          context.read<TaskProvider>().refreshCurrentTasks(silent: true),
        if (!isSuperAdmin) context.read<ExpenseProvider>().load(silent: true),
      ];

      if (isAdmin) {
        refreshes.add(context.read<DashboardProvider>().load(silent: true));
        refreshes.add(context.read<UserProvider>().loadUsers(silent: true));
        refreshes.add(context.read<UserProvider>().loadRoles(silent: true));
        if (!isSuperAdmin) {
          refreshes.add(context.read<BankProvider>().load(silent: true));
        }
      }

      if (isSuperAdmin) {
        refreshes.add(context.read<OrganizationProvider>().load(silent: true));
      }

      await Future.wait(refreshes);
    } catch (_) {
      // Keep auto-refresh quiet; visible screens still show errors on manual loads.
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appState = context.watch<AppState>();
    final user = auth.currentUser;
    final role = user?.role;
    final isAdmin = Roles.isAdminLike(role);
    final isSuperAdmin = Roles.isSuperAdmin(role);
    final usesBankLabels =
        OrganizationTerminology.usesBankLabels(user?.organizationName);

    final destinations = <_Destination>[
      if (isAdmin)
        const _Destination(
            'Dashboard', 'Home', Icons.dashboard_outlined, DashboardScreen()),
      if (!isAdmin)
        const _Destination('My Tickets', 'Mine', Icons.check_box_outlined,
            TaskListScreen(adminView: false)),
      if (isAdmin)
        _Destination(
            isSuperAdmin ? 'Ticket Monitoring' : 'Ticket Management',
            'Tickets',
            Icons.list_alt_outlined,
            const TaskListScreen(adminView: true)),
      if (!isSuperAdmin)
        const _Destination('Expenses', 'Expense', Icons.receipt_long_outlined,
            ExpenseListScreen()),
      if (isAdmin && !isSuperAdmin)
        _Destination(
            usesBankLabels ? 'Bank Management' : 'Category Management',
            usesBankLabels ? 'Bank' : 'Category',
            Icons.category_outlined,
            const BankManagementScreen()),
      if (!isSuperAdmin)
        const _Destination('Purchase Orders', 'PO',
            Icons.shopping_cart_checkout_outlined, PurchaseOrderListScreen()),
      if (isSuperAdmin)
        const _Destination('Organizations', 'Orgs', Icons.apartment_outlined,
            OrganizationScreen()),
      if (isAdmin)
        const _Destination('User Management', 'Users', Icons.people_outline,
            UserManagementScreen()),
      if (isAdmin)
        const _Destination('Role Management', 'Role', Icons.security_outlined,
            RoleManagementScreen()),
      if (!isSuperAdmin)
        const _Destination('Notifications', 'Alerts',
            Icons.notifications_outlined, NotificationsScreen()),
      const _Destination(
          'Profile', 'Me', Icons.person_outline, ProfileScreen()),
    ];

    final selected = appState.selectedIndex.clamp(0, destinations.length - 1);
    final current = destinations[selected];
    final bottomLimit = isAdmin && !isSuperAdmin ? 6 : 5;
    final bottomDestinations = destinations.take(bottomLimit).toList();
    final bottomSelected = selected < bottomDestinations.length ? selected : 0;
    final hidePlatformNavigation = isSuperAdmin && selected == 0;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 2,
        title: Row(
          children: [
            _OrgAvatar(
                name:
                    auth.isSuperAdmin ? 'Super Admin' : user?.organizationName),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    auth.isSuperAdmin
                        ? 'Super Admin'
                        : (user?.organizationName ?? 'Ticket Management'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, height: 1.1, fontWeight: FontWeight.w900),
                  ),
                  if (user != null)
                    Text(
                      [
                        if (user.name.trim().isNotEmpty) user.name.trim(),
                        if (user.role.trim().isNotEmpty)
                          user.role.replaceAll('_', ' '),
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.15,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isSuperAdmin) ...[
            IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                final index =
                    destinations.indexWhere((d) => d.title == 'Notifications');
                if (index >= 0) context.read<AppState>().select(index);
              },
              icon: const Icon(Icons.notifications_outlined, size: 24),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
      drawer: hidePlatformNavigation
          ? null
          : Drawer(
              backgroundColor: AppTheme.sidebar,
              child: SafeArea(
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          child: Icon(Icons.task_alt, color: Colors.white)),
                      title: const Text('TicketManager',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      subtitle: Text(user?.email ?? '',
                          style: const TextStyle(color: Colors.white70)),
                    ),
                    const Divider(color: Color(0xFF374151)),
                    Expanded(
                      child: ListView.builder(
                        itemCount: destinations.length,
                        itemBuilder: (context, index) {
                          final item = destinations[index];
                          final active = index == selected;
                          return ListTile(
                            selected: active,
                            selectedTileColor: AppTheme.primary,
                            leading: Icon(item.icon, color: Colors.white),
                            title: Text(item.title,
                                style: const TextStyle(color: Colors.white)),
                            onTap: () {
                              context.read<AppState>().select(index);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.white),
                      title: const Text('Logout',
                          style: TextStyle(color: Colors.white)),
                      onTap: () => context.read<AuthProvider>().logout(),
                    ),
                  ],
                ),
              ),
            ),
      body: current.screen,
      bottomNavigationBar:
          !hidePlatformNavigation && selected < bottomDestinations.length
              ? NavigationBar(
                  selectedIndex: bottomSelected,
                  onDestinationSelected: context.read<AppState>().select,
                  destinations: bottomDestinations.map((item) {
                    return NavigationDestination(
                        icon: Icon(item.icon), label: item.shortTitle);
                  }).toList(),
                )
              : null,
    );
  }
}

class _Destination {
  const _Destination(this.title, this.shortTitle, this.icon, this.screen);
  final String title;
  final String shortTitle;
  final IconData icon;
  final Widget screen;
}

class _OrgAvatar extends StatelessWidget {
  const _OrgAvatar({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 19,
      backgroundColor: const Color(0xFFF3F4F6),
      child: Text(
        ((name?.isNotEmpty ?? false) ? name![0] : 'O').toUpperCase(),
        style:
            const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w900),
      ),
    );
  }
}
