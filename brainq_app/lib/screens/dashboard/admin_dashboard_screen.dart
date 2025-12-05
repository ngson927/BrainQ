import 'package:brainq_app/providers/admin_provider.dart';
import 'package:brainq_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'admin_analytics_screen.dart';
import 'admin_deck_screen.dart';
import 'admin_user_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();

    // Only fetch dashboard stats and small samples for home page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      admin.fetchDashboardStats();

      // Fetch only a few users and decks for home preview
      admin.fetchUsers(queryParams: {'page': '1', 'page_size': '5'});
      admin.fetchDecks(queryParams: {'page': '1', 'page_size': '5'});
    });
  }

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = "";
      _searchController.clear();
    });
  }

  Future<void> _refreshAll() async {
    final admin = context.read<AdminProvider>();
    await Future.wait([
      admin.fetchDashboardStats(),
      admin.fetchUsers(queryParams: {'page': '1', 'page_size': '5'}),
      admin.fetchDecks(queryParams: {'page': '1', 'page_size': '5'}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final usernameLetter = (auth.username != null && auth.username!.isNotEmpty)
        ? auth.username!.substring(0, 1).toUpperCase()
        : '?';

    return Consumer<AdminProvider>(
      builder: (context, admin, _) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Row(
                children: [
                  Expanded(
                    child: (_selectedIndex == 0)
                        ? Container(
                            height: 40,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              onSubmitted: (query) {
                                admin.fetchUsers(queryParams: {
                                  'search': query,
                                  'page': '1',
                                  'page_size': '5'
                                });
                                admin.fetchDecks(queryParams: {
                                  'search': query,
                                  'page': '1',
                                  'page_size': '5'
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: _clearSearch,
                                      )
                                    : null,
                                filled: true,
                                fillColor: theme.cardColor,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    offset: const Offset(0, 45),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    icon: CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.primaryColor,
                      child: Text(
                        usernameLetter,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onSelected: (val) {
                      switch (val) {
                        case 'notifications':
                          context.push('/notifications');
                          break;
                        case 'reminders':
                          context.push('/reminders');
                          break;
                        case 'settings':
                          context.go('/settings');
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      final theme = Theme.of(context);
                      return [
                        PopupMenuItem(
                          value: 'notifications',
                          child: Text(
                            'Notifications',
                            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        PopupMenuItem(
                          value: 'reminders',
                          child: Text(
                            'Reminders',
                            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        PopupMenuItem(
                          value: 'settings',
                          child: Text(
                            'Settings',
                            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                          ),
                        ),
                      ];
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

          ),
          body: _buildBody(admin),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onTabSelected,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
              BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Decks'),
              BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
            ],
          ),
        );
      },
    );
  }

Widget _buildBody(AdminProvider admin) {
  switch (_selectedIndex) {
    case 0:
      return RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('Recent Users', style: Theme.of(context).textTheme.titleMedium),
            ...admin.users.take(5).map((u) => ListTile(
                  title: Text(u['username'] ?? ''),
                  subtitle: Text(u['email'] ?? ''),
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                  },
                )),
            const SizedBox(height: 16),
            Text('Recent Decks', style: Theme.of(context).textTheme.titleMedium),
            ...admin.decks.take(5).map((d) {
              final owner = d['owner_username']?.toString() ?? 'Unknown';
              return ListTile(
                title: Text(d['title'] ?? ''),
                subtitle: Text('Owner: $owner'),
                onTap: () {
                  setState(() => _selectedIndex = 2);
                },
              );
            }),
          ],
        ),
      );
    case 1:
      return const AdminUsersScreen();
    case 2:
      return const AdminDecksScreen();
    case 3:
      return const AdminAnalyticsScreen();

    default:
      return const SizedBox.shrink();
  }
}

}
