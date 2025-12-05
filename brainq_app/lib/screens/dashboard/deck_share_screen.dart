import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/deck.dart';
import '../../models/deck_item.dart';
import '../../services/api_service.dart';

class DeckShareScreen extends StatefulWidget {
  final DeckItem deck;
  final String userToken;
  final bool isOwner;

  const DeckShareScreen({
    super.key,
    required this.deck,
    required this.userToken,
    required this.isOwner,
  });

  @override
  State<DeckShareScreen> createState() => _DeckShareScreenState();
}

class _DeckShareScreenState extends State<DeckShareScreen>
    with WidgetsBindingObserver {
  late DeckItem deck;
  bool loading = true;
  bool processing = false;
  String _selectedPermission = 'view';

  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    deck = widget.deck;
    WidgetsBinding.instance.addObserver(this);

    if (widget.isOwner || deck.isPublic) {
      _loadShares();
    } else {
      loading = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadShares() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.getDeckShares(widget.userToken, deck.id);
      if (!mounted) return;

      final shares = (data['shares'] as List<dynamic>? ?? [])
          .map((s) => SharedUser.fromJson(s))
          .toList();

      setState(() {
        deck = deck.copyWith(
          sharedUsers: shares,
          isLinkShared: data['is_link_shared'] ?? false,
          shareLink: data['share_link'],
        );
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to load shares')));
    }
  }

  Future<void> _addUser() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() => processing = true);

    try {
      final newShares = await ApiService.shareDeck(
        widget.userToken,
        deck.id,
        [
          {'username': username, 'permission': _selectedPermission}
        ],
      );

      if (mounted) {
        setState(() {
          deck = deck.copyWith(sharedUsers: [...?deck.sharedUsers, ...newShares]);
          _usernameController.clear();
          _selectedPermission = 'view';
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to add user')));
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> _removeUser(SharedUser user) async {
    setState(() => processing = true);

    try {
      final revoked =
          await ApiService.revokeDeckShare(widget.userToken, deck.id, [user.username]);
      if (mounted && revoked.contains(user.username)) {
        setState(() {
          deck.sharedUsers?.remove(user);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to remove user')));
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> _toggleLink() async {
    setState(() => processing = true);

    try {
      final response = await ApiService.toggleDeckLink(
        widget.userToken,
        deck.id,
        (deck.isLinkShared ?? false) ? 'disable' : 'enable',
      );

      if (!mounted) return;

      setState(() {
        deck = deck.copyWith(
          isLinkShared: response['is_link_shared'] ?? false,
          shareLink: response['share_link'],
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to toggle link')));
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOwner) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Share "${deck.title}"'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // =========================
                  // Link Sharing Card
                  // =========================
                  if (deck.isPublic)
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      color: theme.colorScheme.surface,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.link, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                deck.isLinkShared == true
                                    ? (deck.shareUrl ?? 'Generating link...')
                                    : 'Link disabled',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: deck.isLinkShared == true
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            if (deck.isLinkShared == true && deck.shareUrl != null)
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: deck.shareUrl!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Link copied to clipboard')),
                                  );
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                deck.isLinkShared == true
                                    ? Icons.toggle_on
                                    : Icons.toggle_off,
                                size: 34,
                                color: deck.isLinkShared == true
                                    ? theme.colorScheme.primary
                                    : Colors.grey,
                              ),
                              onPressed: processing ? null : _toggleLink,
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // =========================
                  // Shared Users Section
                  // =========================
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      color: theme.colorScheme.surface,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shared Users',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: deck.sharedUsers!.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No users yet. Add below!',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: deck.sharedUsers!.length,
                                      separatorBuilder: (_, _) => const Divider(),
                                      itemBuilder: (_, index) {
                                        final user = deck.sharedUsers![index];
                                        return ListTile(
                                          title: Text(user.username),
                                          subtitle: DropdownButton<String>(
                                            value: user.permission,
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'view',
                                                  child: Text('Can View')),
                                              DropdownMenuItem(
                                                  value: 'edit',
                                                  child: Text('Can Edit')),
                                            ],
                                            onChanged: processing
                                                ? null
                                                : (value) async {
                                                    if (value == null) return;
                                                    setState(() => processing = true);
                                                    await ApiService.shareDeck(
                                                      widget.userToken,
                                                      deck.id,
                                                      [
                                                        {
                                                          'username': user.username,
                                                          'permission': value,
                                                        }
                                                      ],
                                                    );
                                                    setState(() {
                                                      user.permission = value;
                                                      processing = false;
                                                    });
                                                  },
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                            color: theme.colorScheme.error,
                                            onPressed: processing
                                                ? null
                                                : () => _removeUser(user),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _usernameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Username',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: _selectedPermission,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'view', child: Text('Can View')),
                                    DropdownMenuItem(
                                        value: 'edit', child: Text('Can Edit')),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedPermission = value!);
                                  },
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: processing ? null : _addUser,
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}