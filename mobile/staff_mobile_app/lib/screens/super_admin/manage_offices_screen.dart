import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class ManageOfficesScreen extends StatefulWidget {
  const ManageOfficesScreen({super.key});

  @override
  State<ManageOfficesScreen> createState() => _ManageOfficesScreenState();
}

class _ManageOfficesScreenState extends State<ManageOfficesScreen> {
  final AuthService _authService = AuthService();
  late Future<List<dynamic>> _officesFuture;

  @override
  void initState() {
    super.initState();
    _officesFuture = _authService.getOffices(includeInactive: true);
  }

  Future<void> _refresh() async {
    final future = _authService.getOffices(includeInactive: true);
    setState(() => _officesFuture = future);
    await future;
  }

  Future<void> _openAddOfficeDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final descriptionController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF233246),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Add Government Office',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  controller: nameController,
                  label: 'Office name',
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: codeController,
                  label: 'Short code',
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: descriptionController,
                  label: 'Description',
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.82)),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (created != true) {
      nameController.dispose();
      codeController.dispose();
      descriptionController.dispose();
      return;
    }

    try {
      final response = await _authService.createOffice(
        name: nameController.text.trim(),
        code: codeController.text.trim(),
        description: descriptionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Office added successfully',
          ),
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      nameController.dispose();
      codeController.dispose();
      descriptionController.dispose();
    }
  }

  InputDecoration _dialogDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.72)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Color(0xFF2563EB)),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _dialogDecoration(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1727),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Office Directory'),
        actions: [
          IconButton(
            onPressed: _openAddOfficeDialog,
            icon: const Icon(Icons.add_business_outlined),
            tooltip: 'Add office',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C1727),
              Color(0xFF1A2940),
              Color(0xFF463327),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF2563EB),
          child: FutureBuilder<List<dynamic>>(
            future: _officesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _MessageCard(
                      title: 'Unable to load offices',
                      message: snapshot.error
                          .toString()
                          .replaceFirst('Exception: ', ''),
                    ),
                  ],
                );
              }

              final offices = snapshot.data ?? const [];

              return ListView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomSafeArea),
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _openAddOfficeDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Add department or office'),
                  ),
                  const SizedBox(height: 18),
                  if (offices.isEmpty)
                    const _MessageCard(
                      title: 'No offices found',
                      message: 'Government offices will appear here once they are added.',
                    )
                  else
                    ...offices.map((item) {
                      final office = item as Map<String, dynamic>;
                      final name = (office['name'] ?? 'Unnamed office').toString();
                      final code = (office['code'] ?? '').toString();
                      final description =
                          (office['description'] ?? 'No description provided.')
                              .toString();
                      final isActive = office['is_active'] != false;

                      return _OfficeCard(
                        name: name,
                        code: code,
                        description: description,
                        isActive: isActive,
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1D4ED8),
            Color(0xFF2563EB),
          ],
        ),
      ),
      child: Text(
        'Add Tacloban City departments and offices here so citizens can route complaints to the correct government unit.',
        style: TextStyle(
          color: Colors.white.withOpacity(0.88),
          height: 1.4,
        ),
      ),
    );
  }
}

class _OfficeCard extends StatelessWidget {
  const _OfficeCard({
    required this.name,
    required this.code,
    required this.description,
    required this.isActive,
  });

  final String name;
  final String code;
  final String description;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_outlined, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(
                label: isActive ? 'Active' : 'Inactive',
                color: isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              ),
            ],
          ),
          if (code.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              code,
              style: TextStyle(color: Colors.white.withOpacity(0.72)),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.74),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
