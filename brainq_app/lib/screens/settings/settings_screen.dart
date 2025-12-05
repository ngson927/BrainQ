// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../config/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;

  bool _editingUsername = false;
  bool _editingEmail = false;
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.loadUserFromPrefs();
    if (!mounted) return;

    setState(() {
      _usernameController.text = auth.username ?? '';
      _emailController.text = auth.email ?? '';
      _firstNameController.text = auth.firstName ?? '';
      _lastNameController.text = auth.lastName ?? '';
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(auth),
          const SizedBox(height: 20),
          _buildDarkModeToggle(themeProv),
          const Divider(height: 30),
          if (auth.isLoggedIn) ...[
            _buildChangePassword(auth),
            _buildLogout(auth, themeProv),
            _buildDeleteAccount(auth, themeProv),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileCard(AuthProvider auth) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary,
              child: Text(
                (auth.username?.isNotEmpty ?? false)
                    ? auth.username![0].toUpperCase()
                    : 'U',
                style: const TextStyle(fontSize: 28, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),

            // First + Last Name Row
            _buildEditableRow(
              label: 'Name',
              firstController: _firstNameController,
              secondController: _lastNameController,
              isEditing: _editingName,
              onEditPressed: () => setState(() => _editingName = true),
              onSavePressed: () async {
                await auth.updateProfile(
                  firstName: _firstNameController.text.isNotEmpty ? _firstNameController.text : null,
                  lastName: _lastNameController.text.isNotEmpty ? _lastNameController.text : null,
                );
                if (!mounted) return;
                setState(() => _editingName = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name updated')),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildEditableSingle(
              label: 'Username',
              controller: _usernameController,
              isEditing: _editingUsername,
              onEditPressed: () => setState(() => _editingUsername = true),
              onSavePressed: () async {
                await auth.updateProfile(username: _usernameController.text.isNotEmpty ? _usernameController.text : null);
                if (!mounted) return;
                setState(() => _editingUsername = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username updated')),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildEditableSingle(
              label: 'Email',
              controller: _emailController,
              isEditing: _editingEmail,
              onEditPressed: () => setState(() => _editingEmail = true),
              onSavePressed: () async {
                await auth.updateProfile(email: _emailController.text.isNotEmpty ? _emailController.text : null);
                if (!mounted) return;
                setState(() => _editingEmail = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email updated')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableRow({
    required String label,
    required TextEditingController firstController,
    required TextEditingController secondController,
    required bool isEditing,
    required VoidCallback onEditPressed,
    required VoidCallback onSavePressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: firstController,
                enabled: isEditing,
                decoration: const InputDecoration(
                  labelText: 'First',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: secondController,
                enabled: isEditing,
                decoration: const InputDecoration(
                  labelText: 'Last',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(isEditing ? Icons.check_circle : Icons.edit,
                  color: isEditing ? Colors.green : Colors.grey),
              onPressed: isEditing ? onSavePressed : onEditPressed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditableSingle({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEditPressed,
    required VoidCallback onSavePressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: isEditing,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: Icon(isEditing ? Icons.check_circle : Icons.edit,
              color: isEditing ? Colors.green : Colors.grey),
          onPressed: isEditing ? onSavePressed : onEditPressed,
        ),
      ],
    );
  }

  Widget _buildChangePassword(AuthProvider auth) {
    return ListTile(
      leading: const Icon(Icons.lock, color: Colors.teal),
      title: const Text('Change Password'),
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16),
            child: _ChangePasswordSheet(auth: auth),
          ),
        );
      },
    );
  }

  Widget _buildDarkModeToggle(ThemeProvider themeProv) {
    return SwitchListTile(
      title: Row(
        children: const [
          Icon(Icons.nightlight_round, color: Colors.grey),
          SizedBox(width: 10),
          Text('Dark Mode'),
        ],
      ),
      activeThumbColor: AppColors.primary,
      value: themeProv.isDarkMode,
      onChanged: (_) async => await themeProv.toggleTheme(),
    );
  }

  Widget _buildLogout(AuthProvider auth, ThemeProvider themeProv) {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.redAccent),
      title: const Text('Logout'),
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Logout', style: TextStyle(color: Colors.red))),
            ],
          ),
        );

        if (confirm == true) {
          auth.logout();
          themeProv.resetToLight();
          if (mounted) context.go('/');
        }
      },
    );
  }

  Widget _buildDeleteAccount(AuthProvider auth, ThemeProvider themeProv) {
    return ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: const Text('Delete Account'),
      onTap: () async {
        final passwordController = TextEditingController();
        // Step 1: Enter password
        final entered = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'This is permanent.\n\nEnter your password to confirm:'),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child:
                      const Text('Next', style: TextStyle(color: Colors.red))),
            ],
          ),
        );

        if (entered == true) {
          // Step 2: Final confirmation
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Confirm Deletion'),
              content: const Text(
                  'Are you absolutely sure you want to delete your account?\n\nAll your data will be permanently removed and cannot be recovered.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          );

          if (confirm == true) {
            try {
              await auth.deleteAccount(password: passwordController.text);
              themeProv.resetToLight();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deleted successfully')),
              );
              context.go('/');
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          }
        }
      },
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  final AuthProvider auth;
  const _ChangePasswordSheet({required this.auth});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  int _strength = 0;

  void _checkStrength() {
    final pw = _newController.text;
    int strength = 0;
    if (pw.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) strength++;
    if (RegExp(r'[0-9]').hasMatch(pw)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pw)) strength++;
    setState(() => _strength = strength);
  }

  @override
  void initState() {
    super.initState();
    _newController.addListener(_checkStrength);
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Change Password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildField(
                  'Current Password', _currentController, _showCurrent,
                  () => setState(() => _showCurrent = !_showCurrent)),
              const SizedBox(height: 10),
              _buildField('New Password', _newController, _showNew,
                  () => setState(() => _showNew = !_showNew)),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _strength / 4,
                backgroundColor: Colors.grey[300],
                color: _strength <= 1
                    ? Colors.red
                    : _strength == 2
                        ? Colors.orange
                        : _strength == 3
                            ? Colors.blue
                            : Colors.green,
              ),
              const SizedBox(height: 4),
              Text(
                _strength <= 1
                    ? 'Weak'
                    : _strength == 2
                        ? 'Okay'
                        : _strength == 3
                            ? 'Strong'
                            : 'Very strong',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              _buildField('Confirm Password', _confirmController, _showConfirm,
                  () => setState(() => _showConfirm = !_showConfirm)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_newController.text != _confirmController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Passwords do not match')),
                          );
                          return;
                        }

                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Confirm Password Change'),
                            content: const Text(
                                'Are you sure you want to update your password?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Update', style: TextStyle(color: Colors.green))),
                            ],
                          ),
                        );

                        if (confirm != true) return;

                        try {
                          await widget.auth.updateProfile(
                            currentPassword: _currentController.text,
                            newPassword: _newController.text,
                            confirmPassword: _confirmController.text,
                          );

                          _currentController.clear();
                          _newController.clear();
                          _confirmController.clear();

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password updated')),
                          );
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      },
                      child: const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, bool visible, VoidCallback toggle) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
          onPressed: toggle,
        ),
      ),
    );
  }
}
