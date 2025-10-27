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

  bool _editingUsername = false;
  bool _editingEmail = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.loadUserFromPrefs();
    if (!mounted) return;

    setState(() {
      _usernameController.text = auth.username ?? '';
      _emailController.text = auth.email ?? '';
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
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
              Navigator.pop(context); // Go back if possible
            } else {
              context.go('/dashboard'); // Otherwise navigate to dashboard
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
            _buildChangePassword(),
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
            _buildEditableRow(
              label: 'Username',
              controller: _usernameController,
              isEditing: _editingUsername,
              onEditPressed: () => setState(() => _editingUsername = true),
              onSavePressed: () async {
                await auth.updateProfile(username: _usernameController.text);
                if (!mounted) return;
                setState(() => _editingUsername = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username updated')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildEditableRow(
              label: 'Email',
              controller: _emailController,
              isEditing: _editingEmail,
              onEditPressed: () => setState(() => _editingEmail = true),
              onSavePressed: () async {
                await auth.updateProfile(email: _emailController.text);
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

  Widget _buildChangePassword() {
    return ListTile(
      leading: const Icon(Icons.lock, color: Colors.teal),
      title: const Text('Change Password'),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Change password feature coming soon!')),
        );
      },
    );
  }

  Widget _buildLogout(AuthProvider auth, ThemeProvider themeProv) {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.redAccent),
      title: const Text('Logout'),
      onTap: () {
        auth.logout();
        themeProv.resetToLight();
        if (mounted) context.go('/');
      },
    );
  }

  Widget _buildDeleteAccount(AuthProvider auth, ThemeProvider themeProv) {
    return ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: const Text('Delete Account'),
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
                'Are you sure you want to permanently delete your account? This action cannot be undone.'),
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

        if (confirm == true) {
          await auth.deleteAccount();
          if (!mounted) return;
          themeProv.resetToLight();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully')),
          );
          context.go('/');
        }
      },
    );
  }

  Widget _buildEditableRow({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEditPressed,
    required VoidCallback onSavePressed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        Column(
          children: [
            IconButton(
              icon: Icon(
                isEditing ? Icons.check_circle : Icons.edit,
                color: isEditing ? Colors.green : Colors.grey,
              ),
              onPressed: isEditing ? onSavePressed : onEditPressed,
            ),
            Text(
              isEditing ? 'Save' : 'Edit',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
