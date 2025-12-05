import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/deck_provider.dart';
import 'deck_card.dart';

class LibraryScreen extends StatefulWidget {
  final String? userId;

  const LibraryScreen({super.key, required this.userId});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<void> _initialFetch;

  @override
  void initState() {
    super.initState();
    _initialFetch = _fetchDecks();
  }

  Future<void> _fetchDecks() async {
    if (widget.userId != null) {
      final deckProv = context.read<DeckProvider>();
      await deckProv.fetchDecks();
      await deckProv.fetchArchivedDecks();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return const Center(child: Text('Login to see your decks.'));
    }

    return FutureBuilder(
      future: _initialFetch,
      builder: (context, snapshot) {
        return Consumer<DeckProvider>(
          builder: (context, deckProv, _) {
            final userDecks = deckProv.decks
                .where((d) => d.ownerId == deckProv.userId)
                .toList();
            final activeDecks = userDecks.where((d) => !d.archived).toList();
            final hasArchived = deckProv.archivedDecks
                .any((d) => d.ownerId == deckProv.userId);

            return Column(
              children: [
                if (hasArchived)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.archive),
                      label: const Text('View Archived Decks'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ArchivedDecksScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchDecks,
                    child: activeDecks.isEmpty
                        ? const Center(
                            child: Text(
                              'You haven’t created any decks yet.\nTap + to create your first deck!',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: activeDecks.length,
                            itemBuilder: (_, index) => DeckCard(
                              deck: activeDecks[index],
                              showArchiveOption: true,
                              showEditDeleteOptions: true,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ArchivedDecksScreen extends StatefulWidget {
  const ArchivedDecksScreen({super.key});

  @override
  State<ArchivedDecksScreen> createState() => _ArchivedDecksScreenState();
}

class _ArchivedDecksScreenState extends State<ArchivedDecksScreen> {
  late Future<void> _initialFetch;

  @override
  void initState() {
    super.initState();
    _initialFetch = _fetchArchivedDecks();
  }

  Future<void> _fetchArchivedDecks() async {
    final deckProv = context.read<DeckProvider>();
    await deckProv.fetchArchivedDecks();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialFetch,
      builder: (context, snapshot) {
        return Consumer<DeckProvider>(
          builder: (context, deckProv, _) {
            final archivedDecks = deckProv.archivedDecks
                .where((d) => d.ownerId == deckProv.userId)
                .toList();

            return Scaffold(
              appBar: AppBar(title: const Text('Archived Decks')),
              body: RefreshIndicator(
                onRefresh: _fetchArchivedDecks,
                child: archivedDecks.isEmpty
                    ? const Center(child: Text('No archived decks yet.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: archivedDecks.length,
                        itemBuilder: (_, index) => DeckCard(
                          deck: archivedDecks[index],
                          showArchiveOption: true,
                          showEditDeleteOptions: true,
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
