import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/deck_provider.dart';
import '../../models/deck_item.dart';
import '../../services/api_service.dart';
import '../AI/ai_chat_screen.dart';
import '../deck/create_deck_screen.dart';
import '../deck/ai_deck_screen.dart';
import '../stats_screen.dart';
import 'deck_card.dart';
import 'library_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  late Future<Map<String, dynamic>> _streakFuture;


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDecks();
    });

    _searchController.addListener(() {
      final query = _searchController.text;
      if (query != _searchQuery) {
        _onSearchChanged(query);
      }
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token != null) {
      _streakFuture = ApiService.getStreak(token: auth.token!);
    }
  }



  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDecks() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final deckProv = Provider.of<DeckProvider>(context, listen: false);

    if (auth.isLoggedIn && auth.token != null && auth.userId != null) {
      deckProv.setAuth(token: auth.token!, userId: auth.userId!);
      await deckProv.fetchDecks();
    }
  }

  void _clearSearch() {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
      _loadingSearch = false;
    });
  }

  Future<void> _onSearchChanged(String query) async {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
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

        // Tab-specific filtering
        List<DeckItem> filtered;
        if (_selectedIndex == 0) {
          filtered = decks.where((d) => d.isPublic).toList();
        } else if (_selectedIndex == 1) {
          filtered = decks.where((d) => d.ownerId == auth.userId || d.isPublic).toList();
        } else {
          filtered = decks;
        }

        if (mounted) setState(() => _searchResults = filtered);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Search failed: $e")));
        }
      } finally {
        if (mounted) setState(() => _loadingSearch = false);
      }
    });
  }

  // ---- Search Results UI ----
  Widget _buildSearchResults() {
    if (_loadingSearch) return const Center(child: CircularProgressIndicator());

    if (_searchQuery.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Text(
            'Type to search decks',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (_, index) => DeckCard(
        deck: _searchResults[index],
        showArchiveOption: true,
        showEditDeleteOptions: true,
      ),
    );
  }

  // ---- Home Tab ----
  Widget _buildHome(List<DeckItem> decks, String? userId) {
    final deckProv = Provider.of<DeckProvider>(context);
    final recentDecks = deckProv.recents;

    if (recentDecks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDecks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Text(
                  'No recent decks yet. View or study one to see it here!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDecks,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: recentDecks.length,
        itemBuilder: (_, index) => DeckCard(
          deck: recentDecks[index],
          showArchiveOption: true,
          showEditDeleteOptions: true,
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.token == null) {
      return const Center(child: Text("Login to see your streak stats."));
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _streakFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error loading streaks: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: Text("No streak data found."));
        }

        final data = snapshot.data!;
        final badges = <Map<String, dynamic>>[];
        if (data['badges'] != null) {
          for (var b in data['badges']) {
            if (b is Map<String, dynamic>) {
              badges.add({
                'key': b['key'] ?? '',
                'name': b['name'] ?? '',
                'description': b['description'] ?? '',
                'category': b['category'] ?? '',
                'progress': b['progress']?.toDouble() ?? 1.0,
              });
            }
          }
        }

        return StatsScreen(
          token: auth.token!,
          currentStreak: data['current_streak'] ?? 0,
          bestStreak: data['best_streak'] ?? 0,
          totalStudyDays: data['total_study_days'] ?? 0,
          consecutivePerfectQuizzes: data['consecutive_perfect_quizzes'] ?? 0,
          totalDecksCreated: data['total_decks_created'] ?? 0,
          badges: badges,
        );
      },
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
          : LibraryScreen(userId: auth.userId),
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
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch)
                                : null,
                            filled: true,
                            fillColor: theme.cardColor,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                onSelected: (val) {
                  switch (val) {
                    case 'login':
                      context.go('/');
                      break;
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
                itemBuilder: (_) {
                  if (!auth.isLoggedIn) {
                    return [
                      PopupMenuItem(
                        value: 'login',
                        child: Text('Login', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                      ),
                    ];
                  }
                  return [
                    PopupMenuItem(
                      value: 'notifications',
                      child: Text('Notifications', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                    ),
                    const PopupMenuDivider(height: 1),
                    PopupMenuItem(
                      value: 'reminders',
                      child: Text('Reminders', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                    ),
                    const PopupMenuDivider(height: 1),
                    PopupMenuItem(
                      value: 'settings',
                      child: Text('Settings', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
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
              _showDeckCreationMenu();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Login to create decks!')),
              );
            }
          } else {
            _clearSearch();
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
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _openAIAssistant,
              backgroundColor: Colors.deepPurple,
              tooltip: "Chat with AI Assistant",
              child: const Icon(Icons.smart_toy),
            )
          : null,

    );
  }

  void _openAIAssistant() {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!auth.isLoggedIn || auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to chat with AI!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIChatScreen(
          token: auth.token!,
          deckId: null,
          deckTitle: 'AI Assistant',
        ),
      ),
    );
  }



void _showDeckCreationMenu() {
  final auth = Provider.of<AuthProvider>(context, listen: false);

  if (!auth.isLoggedIn || auth.token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Login to create decks!')),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Create Deck',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMenuOption(
                    context,
                    icon: Icons.create,
                    label: "Create Manually",
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateDeckScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMenuOption(
                    context,
                    icon: Icons.smart_toy,
                    label: "Generate with AI",
                    color: Colors.purpleAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AIDeckScreen(token: auth.token!),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    },
  );
}

Widget _buildMenuOption(BuildContext context,
    {required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap}) {
  final bgColor = color.withValues(alpha: 0.1);
  final borderColor = color.withValues(alpha: 0.3);


  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color.darken(0.2),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}



}
extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
  
  }