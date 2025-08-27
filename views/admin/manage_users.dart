import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_mangment_provider.dart';
import '../../servises/generate_password.dart';
import '../../models/user_model.dart';
import 'package:flutter/services.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Boumerdes'), Tab(text: 'Bouira')],
        ),
        actions: [
          if (_isSearching)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search users...',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddUserDialog(context, ref),
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data:
            (users) => TabBarView(
              controller: _tabController,
              children: [
                // Boumerdes tab - filter users where locations array contains "boumerdes"
                _buildUserList(
                  users
                      .where(
                        (user) =>
                            user.locations != null &&
                            user.locations!.contains('boumerdes'),
                      )
                      .toList(),
                ),
                // Bouira tab - filter users where locations array contains "bouira"
                _buildUserList(
                  users
                      .where(
                        (user) =>
                            user.locations != null &&
                            user.locations!.contains('bouira'),
                      )
                      .toList(),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildUserList(List<AppUser> users) {
    if (users.isEmpty) {
      return const Center(child: Text('No users found for this location'));
    }

    final filteredUsers =
        users.where((user) {
          final query = _searchQuery.toLowerCase();
          return user.name?.toLowerCase().contains(query) == true ||
              user.email?.toLowerCase().contains(query) == true;
        }).toList();

    if (filteredUsers.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return ListTile(
          title: Text(user.name ?? user.email),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${user.role} • ${user.phone ?? 'No phone'}'),
              if (user.locations != null && user.locations!.isNotEmpty)
                Text(
                  'Location: ${user.locations!.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditUserDialog(context, ref, user),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDeleteUser(context, ref, user),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddUserDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final phoneController = TextEditingController();
    final password = generateRandomPassword();
    final passwordController = TextEditingController(text: password);
    String role = 'client';
    String selectedLocation = 'bouira';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add User'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                        ),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: '',
                        ),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        keyboardType: TextInputType.phone,
                      ),
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          helperText:
                              'This password is generated automatically',
                        ),
                        readOnly: true,
                        enableInteractiveSelection: true,
                      ),
                      DropdownButtonFormField<String>(
                        value: role,
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem(
                            value: 'client',
                            child: Text('Client'),
                          ),
                        ],
                        onChanged: (value) => role = value!,
                        decoration: const InputDecoration(labelText: 'Role'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Select Location:'),
                      RadioListTile<String>(
                        title: const Text('Bouira'),
                        value: 'bouira',
                        groupValue: selectedLocation,
                        onChanged: (String? value) {
                          setState(() {
                            selectedLocation = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Boumerdes'),
                        value: 'boumerdes',
                        groupValue: selectedLocation,
                        onChanged: (String? value) {
                          setState(() {
                            selectedLocation = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        final username = usernameController.text.trim();
                        final email = '$username@paragalien.dz';

                        final result = await ref
                            .read(userManagementProvider)
                            .addUserWithGeneratedPassword(
                              email: email,
                              fullName: nameController.text,
                              phone: phoneController.text,
                              role: role,
                              locations: [selectedLocation],
                            );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'User created! Password: ${result.generatedPassword}',
                              ),
                            ),
                          );
                          ref.invalidate(usersProvider);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditUserDialog(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    String role = user.role;
    String selectedLocation = user.locations?.first ?? 'bouira';
    String? initialPassword;

    try {
      initialPassword = await ref
          .read(userManagementProvider)
          .getUserInitialPassword(user.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load password: $e')));
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit User'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Copyable Email Row
                      InkWell(
                        onTap:
                            user.email != null
                                ? () {
                                  Clipboard.setData(
                                    ClipboardData(text: user.email!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Copied email to clipboard',
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                                : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  user.email ?? 'No email available',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    decoration:
                                        user.email != null
                                            ? TextDecoration.underline
                                            : null,
                                    color:
                                        user.email != null
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : Colors.grey,
                                  ),
                                ),
                              ),
                              if (user.email != null)
                                const Icon(Icons.copy_outlined, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 20),

                      // Name Field
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone Field
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // Role Dropdown
                      DropdownButtonFormField<String>(
                        value: role,
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem(
                            value: 'client',
                            child: Text('Client'),
                          ),
                        ],
                        onChanged: (value) => setState(() => role = value!),
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location Selection
                      const Text('Select Location:'),
                      RadioListTile<String>(
                        title: const Text('Bouira'),
                        value: 'bouira',
                        groupValue: selectedLocation,
                        onChanged: (String? value) {
                          setState(() {
                            selectedLocation = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Boumerdes'),
                        value: 'boumerdes',
                        groupValue: selectedLocation,
                        onChanged: (String? value) {
                          setState(() {
                            selectedLocation = value!;
                          });
                        },
                      ),

                      // Initial Password Section
                      if (initialPassword != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Initial Password:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  initialPassword,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: initialPassword!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password copied to clipboard',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(userManagementProvider)
                          .updateUser(
                            userId: user.id,
                            fullName: nameController.text,
                            phone: phoneController.text,
                            role: role,
                            locations: [selectedLocation],
                          );
                      if (mounted) {
                        Navigator.pop(context);
                        ref.invalidate(usersProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User updated successfully'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteUser(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text(
              'Are you sure you want to delete ${user.name ?? user.email}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await ref.read(userManagementProvider).deleteUser(user.id);
        if (mounted) {
          ref.invalidate(usersProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

final usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) {
  return ref.read(userManagementProvider).getAllUsers();
});
