import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/deck_provider.dart';
import '../../models/deck_item.dart';
import '../../services/api_service.dart';
import '../deck/create_deck_screen.dart';
import '../quiz/deck_screen.dart';
import '../settings/settings_screen.dart';
import '../stats_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  List<DeckItem> _searchResults = [];
  bool _isSearching = false;
  bool _loadingSearch = false;

  @override
  void initState() {
    super.initState();
    _loadDecks();
    final deckProv = Provider.of<DeckProvider>(context, listen: false);
    deckProv.loadRecents();
  }

  Future<void> _loadDecks() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final deckProv = Provider.of<DeckProvider>(context, listen: false);

    if (auth.isLoggedIn && auth.token != null && auth.userId != null) {
      deckProv.setAuth(token: auth.token!, userId: auth.userId!);
      await deckProv.fetchDecks();
      if (mounted) setState(() {});
    }
  }

  /// ---- SEARCH HANDLER ----

Future<void> _onSearchChanged(String query) async {
  setState(() {
    _searchQuery = query;
    _isSearching = query.isNotEmpty;
    _searchResults = [];
    _loadingSearch = true;
  });

  if (query.isEmpty) {
    setState(() => _loadingSearch = false);
    return;
  }

  try {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.isLoggedIn ? auth.token : null;

    final result = await ApiService.search(query: query, token: token);

    final decksJson = result['decks_found'] as List<dynamic>;
    final decks = decksJson.map((d) => DeckItem.fromBackendJson(d)).toList();

    // ---- Tab-specific filtering ----
    List<DeckItem> filtered;
    if (_selectedIndex == 0) {
      // Home: only public decks
      filtered = decks.where((d) => d.isPublic).toList();
    } else if (_selectedIndex == 1) {
      // Library: user’s decks AND public decks
      filtered = decks.where((d) => d.ownerId == auth.userId || d.isPublic).toList();
    } else {
      filtered = decks;
    }

    setState(() => _searchResults = filtered);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Search failed: $e")));
    }
  } finally {
    if (mounted) setState(() => _loadingSearch = false);
  }
}



// ---- SEARCH RESULTS UI ----
Widget _buildSearchResults() {
  if (_loadingSearch) return const Center(child: CircularProgressIndicator());

  if (_searchResults.isEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Text(
          'No results found for "$_searchQuery"',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  return ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: _searchResults.length,
    itemBuilder: (_, index) => _buildDeckCard(_searchResults[index]),
  );
}

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final deckProv = Provider.of<DeckProvider>(context);
    final theme = Theme.of(context);

    final pages = [
      _isSearching
          ? _buildSearchResults()
          : _buildHome(deckProv.decks, auth.userId),
      _isSearching
          ? _buildSearchResults()
          : _buildLibrary(deckProv.decks, auth.userId),
      const SizedBox.shrink(),
      _buildStats(context),
    ];

    final usernameLetter =
        (auth.username?.isNotEmpty ?? false) ? auth.username![0].toUpperCase() : 'G';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(55),
        child: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: [
              Expanded(
                child: (_selectedIndex == 0 || _selectedIndex == 1)
                    ? Container(
                        height: 40,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            filled: true,
                            fillColor: theme.cardColor,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 45),
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                icon: CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.primaryColor,
                  child: Text(
                    usernameLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onSelected: (val) {
                  switch (val) {
                    case 'login':
                      context.go('/');
                      break;
                    case 'notifications':
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications coming soon!')),
                      );
                      break;
                    case 'settings':
                      context.go('/settings');
                      break;
                  }
                },
                itemBuilder: (_) {
                  if (!auth.isLoggedIn) {
                    return [
                      PopupMenuItem(
                        value: 'login',
                        child: Text(
                          'Login',
                          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                        ),
                      ),
                    ];
                  }
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
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: theme.primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) async {
          if (index == 2) {
            if (auth.isLoggedIn) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateDeckScreen()),
              );
              await _loadDecks();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Login to create decks!')),
              );
            }
          } else {
            setState(() {
              _selectedIndex = index;
              _isSearching = false;
              _searchQuery = '';
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 36), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
    );
  }

  /// ---- Home tab ----
  Widget _buildHome(List<DeckItem> decks, String? userId) {
    final recentDecks = decks.where((d) => d.recentlyUsed).toList();

    if (recentDecks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Text(
            'No recent decks yet. View or study one to see it here!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Recents",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recentDecks.length,
            itemBuilder: (_, index) => _buildDeckCard(recentDecks[index]),
          ),
        ),
      ],
    );
  }

  /// ---- Library tab ----
  Widget _buildLibrary(List<DeckItem> decks, String? userId) {
    if (userId == null) return const Center(child: Text('Login to see your decks.'));

    final userDecks = decks.where((d) => d.ownerId == userId).toList();

    if (userDecks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Text(
            'You haven’t created any decks yet.\nTap + to create your first deck!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Your Decks",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: userDecks.length,
            itemBuilder: (_, index) => _buildDeckCard(userDecks[index]),
          ),
        ),
      ],
    );
  }

/// ---- Deck card widget ----
Widget _buildDeckCard(DeckItem d) {
  final deckProv = Provider.of<DeckProvider>(context, listen: false);
  final userId = deckProv.userId;
  final isOwner = d.ownerId == userId;

  final colors = [
    Theme.of(context).primaryColor,
    Colors.teal.shade400,
    Colors.orange.shade400,
    Colors.purple.shade400,
  ];
  final icons = [Icons.psychology, Icons.lightbulb, Icons.memory, Icons.emoji_objects];

  final i = d.id.hashCode % colors.length;
  final color = colors[i];
  final icon = icons[i % icons.length];

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 10),
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () {
        d.recentlyUsed = true;
        deckProv.saveRecents();
        deckProv.notifyListeners();

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeckScreen(deck: d)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.85), color.withOpacity(0.95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!d.isPublic)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Private',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${d.cardCount} cards',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) {
                switch (val) {
                  case 'edit':
                    if (isOwner) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DeckScreen(deck: d, editMode: true)),
                      );
                    }
                    break;
                  case 'share':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share functionality coming soon!')),
                    );
                    break;
                  case 'delete':
                    if (isOwner) deckProv.removeDeck(d.id);
                    break;
                }
              },
              itemBuilder: (_) => [
                if (isOwner) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'share', child: Text('Share')),
                if (isOwner) const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}




  /// ---- Stats tab ----
  Widget _buildStats(BuildContext context) {
    final totalDecksStudied = 12;
    final totalCardsStudied = 250;
    final totalStudyTime = const Duration(hours: 5, minutes: 30);
    final quizAccuracy = 0.82;
    final achievements = [
      Achievement(
        title: "First Quiz",
        description: "Completed your first quiz!",
        icon: Icons.emoji_events,
        unlocked: true,
      ),
      Achievement(
        title: "Study Streak",
        description: "5 days in a row!",
        icon: Icons.star,
        unlocked: false,
      ),
      Achievement(
        title: "Master Learner",
        description: "100 cards studied",
        icon: Icons.school,
        unlocked: false,
      ),
    ];

    return StatsScreen(
      totalDecksStudied: totalDecksStudied,
      totalCardsStudied: totalCardsStudied,
      totalStudyTime: totalStudyTime,
      quizAccuracy: quizAccuracy,
      achievements: achievements,
    );
  }
}




