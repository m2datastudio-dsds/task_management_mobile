import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/organization.dart';
import '../providers/organization_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_toast.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import 'organization_form_screen.dart';

class OrganizationScreen extends StatefulWidget {
  const OrganizationScreen({super.key});

  @override
  State<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrganizationProvider>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm([Organization? organization]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizationFormScreen(organization: organization),
      ),
    );
    if (mounted) context.read<OrganizationProvider>().load();
  }

  Future<void> _confirmDelete(Organization org) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Organization'),
        content: Text('Are you sure you want to delete ${org.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<OrganizationProvider>().delete(org.id);
      if (!mounted) return;
      AppToast.success(context, 'Organization deleted');
    } catch (err) {
      if (mounted) {
        AppToast.error(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrganizationProvider>();
    final organizations = provider.organizations.where((org) {
      final text = '${org.name} ${org.code}'.toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_business),
        label: const Text('Create Organization'),
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.paddingOf(context).bottom + 96),
          children: [
            const SectionHeader(
              title: 'Organization Management',
              subtitle: 'Manage organizations and their admins',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search by name or code...',
                prefixIcon: Icon(Icons.search_outlined),
              ),
            ),
            const SizedBox(height: 14),
            if (provider.loading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
            ],
            if (provider.error != null) ...[
              _ErrorBanner(message: provider.error!),
              const SizedBox(height: 12),
            ],
            if (!provider.loading && organizations.isEmpty)
              const EmptyState(
                title: 'No organizations found',
                message: 'Create an organization or try another search.',
              ),
            ...organizations.map(
              (org) => _OrgTile(
                org: org,
                onEdit: () => _openForm(org),
                onDelete: () => _confirmDelete(org),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrgTile extends StatelessWidget {
  const _OrgTile({
    required this.org,
    required this.onEdit,
    required this.onDelete,
  });

  final Organization org;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final admins = org.adminNames;
    final location = [org.city, org.country]
        .where((part) => (part ?? '').trim().isNotEmpty)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    org.name.isEmpty ? 'O' : org.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        org.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit organization',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete organization',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFFDC2626),
                ),
              ],
            ),
            if ((org.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                org.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700], height: 1.35),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((org.email ?? '').isNotEmpty)
                  _InfoChip(icon: Icons.email_outlined, label: org.email!),
                if ((org.phone ?? '').isNotEmpty)
                  _InfoChip(icon: Icons.phone_outlined, label: org.phone!),
                if ((org.website ?? '').isNotEmpty)
                  _InfoChip(icon: Icons.language_outlined, label: org.website!),
                if (location.isNotEmpty)
                  _InfoChip(icon: Icons.location_on_outlined, label: location),
                _InfoChip(
                  icon: Icons.admin_panel_settings_outlined,
                  label: admins.isEmpty ? 'No admins' : admins.join(', '),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
