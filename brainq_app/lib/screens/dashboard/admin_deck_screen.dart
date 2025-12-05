import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brainq_app/providers/admin_provider.dart';

class AdminDecksScreen extends StatefulWidget {
  const AdminDecksScreen({super.key});

  @override
  State<AdminDecksScreen> createState() => _AdminDecksScreenState();
}

class _AdminDecksScreenState extends State<AdminDecksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final Set<int> _selectedDecks = {};

  bool _selectMode = false;

  bool? _filterHidden;
  bool? _filterArchived;
  bool? _filterPrivate;
  bool? _filterFlagged;
  String _filterOwner = "";
  DateTime? _filterCreatedAfter;
  DateTime? _filterCreatedBefore;


  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDecks(reset: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildStatusChips(Map<String, dynamic> deck) {
    final bool isHidden = deck['admin_hidden'] == true;
    final bool isArchived = deck['is_archived'] == true;
    final bool isPrivate = deck['is_public'] == false;

    List<Widget> chips = [];

    if (isHidden) {
      chips.add(
        Chip(
          label: const Text("HIDDEN"),
          backgroundColor: Colors.red.shade200,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (isArchived) {
      chips.add(
        Chip(
          label: const Text("ARCHIVED"),
          backgroundColor: Colors.orange.shade200,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (isPrivate) {
      chips.add(
        Chip(
          label: const Text("PRIVATE"),
          backgroundColor: Colors.blueGrey.shade200,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        children: chips,
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildDeckMenuItems(Map<String, dynamic> deck) {
    final bool isHidden = deck['admin_hidden'] ?? false;
    final bool isArchived = deck['is_archived'] ?? false;

    return [
      PopupMenuItem(
        value: isArchived ? "unarchive" : "archive",
        child: Text(isArchived ? "Unarchive" : "Archive"),
      ),
      PopupMenuItem(
        value: isHidden ? "unhide" : "hide",
        child: Text(isHidden ? "Unhide" : "Hide"),
      ),
      const PopupMenuItem(
        value: "delete",
        child: Text("Delete"),
      ),
    ];
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _currentPage++;
      _fetchDecks();
    }
  }

  Map<String, String> _buildQueryParams() {
    final queryParams = <String, String>{};

    if (_searchQuery.isNotEmpty) queryParams['search'] = _searchQuery;
    if (_filterHidden != null) queryParams['admin_hidden'] = _filterHidden.toString();
    if (_filterArchived != null) queryParams['is_archived'] = _filterArchived.toString();
    if (_filterPrivate != null) queryParams['is_public'] = (!_filterPrivate!).toString();
    if (_filterFlagged != null) queryParams['flagged'] = _filterFlagged.toString();
    if (_filterOwner.isNotEmpty) queryParams['owner'] = _filterOwner;
    if (_filterCreatedAfter != null) queryParams['created_after'] = _filterCreatedAfter!.toIso8601String();
    if (_filterCreatedBefore != null) queryParams['created_before'] = _filterCreatedBefore!.toIso8601String();

    queryParams['page'] = '$_currentPage';
    queryParams['page_size'] = '$_pageSize';

    return queryParams;
  }


  Future<void> _fetchDecks({bool reset = false}) async {
    if (reset) {
      _currentPage = 1;
      _hasMore = true;
    }

    _isLoadingMore = true;

    final provider = context.read<AdminProvider>();

    await provider.fetchDecks(queryParams: _buildQueryParams());

    if (provider.decks.length < _currentPage * _pageSize) {
      _hasMore = false;
    }

    _isLoadingMore = false;
  }

  Future<void> _refresh() async {
    _currentPage = 1;
    _hasMore = true;
    await _fetchDecks(reset: true);
  }

  void _toggleSelection(int deckId) {
    setState(() {
      if (_selectedDecks.contains(deckId)) {
        _selectedDecks.remove(deckId);
      } else {
        _selectedDecks.add(deckId);
      }
    });
  }

  Future<void> _performDeckAction({
    required String action,
    List<int>? deckIds,
  }) async {
    final provider = context.read<AdminProvider>();

    List<int> targetDecks = deckIds ?? _selectedDecks.toList();
    if (targetDecks.isEmpty) return;

    if (action == 'delete') {
      targetDecks = targetDecks.where((id) {
        final deck = provider.decks.firstWhere(
          (d) => d['id'] == id,
          orElse: () => {},
        );
        return deck['is_public'] != false;
      }).toList();

      if (targetDecks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot delete private decks.")),
        );
        return;
      }
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Confirm Action"),
            content: Text("Are you sure you want to $action this deck(s)?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Yes"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await provider.bulkDeckAction(targetDecks, action);

    if (deckIds == null) {
      _selectedDecks.clear();
    }

    await _fetchDecks(reset: true);
  }

  //  FILTER SHEET
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Filter Decks",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    CheckboxListTile(
                      title: const Text("Hidden"),
                      value: _filterHidden,
                      tristate: true,
                      onChanged: (val) => setState(() => _filterHidden = val),
                    ),

                    CheckboxListTile(
                      title: const Text("Archived"),
                      value: _filterArchived,
                      tristate: true,
                      onChanged: (val) => setState(() => _filterArchived = val),
                    ),

                    CheckboxListTile(
                      title: const Text("Private"),
                      value: _filterPrivate,
                      tristate: true,
                      onChanged: (val) => setState(() => _filterPrivate = val),
                    ),

                    CheckboxListTile(
                      title: const Text("Flagged"),
                      value: _filterFlagged,
                      tristate: true,
                      onChanged: (val) => setState(() => _filterFlagged = val),
                    ),

                    TextField(
                      decoration: const InputDecoration(
                        labelText: "Owner Username",
                      ),
                      onChanged: (val) => setState(() => _filterOwner = val),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            child: Text(
                              _filterCreatedAfter == null
                                  ? "Created After"
                                  : _filterCreatedAfter!.toLocal().toString().split(' ')[0],
                            ),
                            onPressed: () async {
                              DateTime? date = await showDatePicker(
                                context: context,
                                initialDate: _filterCreatedAfter ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) setState(() => _filterCreatedAfter = date);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton(
                            child: Text(
                              _filterCreatedBefore == null
                                  ? "Created Before"
                                  : _filterCreatedBefore!.toLocal().toString().split(' ')[0],
                            ),
                            onPressed: () async {
                              DateTime? date = await showDatePicker(
                                context: context,
                                initialDate: _filterCreatedBefore ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) setState(() => _filterCreatedBefore = date);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _filterHidden = null;
                                _filterArchived = null;
                                _filterPrivate = null;
                                _filterFlagged = null;
                                _filterOwner = "";
                                _filterCreatedAfter = null;
                                _filterCreatedBefore = null;
                              });
                              context.read<AdminProvider>().fetchDecks();
                              Navigator.pop(context);
                            },
                            child: const Text("Reset"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _fetchDecks(reset: true);
                            },
                            child: const Text("Apply"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Future<void> _openDeckScreen(int deckId) async {
    final provider = context.read<AdminProvider>();
    final deck = await provider.getDeckDetail(deckId);
    if (deck == null) return;

    bool isPublic = deck['is_public'] ?? false;

    if (!isPublic) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(deck['title'] ?? 'Deck Metadata'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Owner: ${deck['owner_username'] ?? '-'}"),
              Text("Created: ${deck['created_at'] ?? '-'}"),
              Text("Archived: ${deck['is_archived'] ?? false}"),
              Text("Admin Hidden: ${deck['admin_hidden'] ?? false}"),
              Text("Flagged: ${deck['is_flagged'] ?? false}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicDeckScreen(deckId: deckId),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(builder: (context, admin, _) {
      final decks = admin.decks;
      final loading = admin.loadingDecks && decks.isEmpty;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    onSubmitted: (_) => _fetchDecks(reset: true),
                    decoration: InputDecoration(
                      hintText: "Search decks",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = "";
                                  _searchController.clear();
                                });
                                _fetchDecks(reset: true);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                OutlinedButton.icon(
                  icon: const Icon(Icons.filter_list),
                  label: const Text("Filter"),
                  onPressed: _openFilterSheet,
                ),

                const SizedBox(width: 6),

                _selectMode
                    ? Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedDecks.addAll(decks
                                    .where((d) => d['id'] != null)
                                    .map((d) => d['id'] as int));
                              });
                            },
                            child: const Text("Select All"),
                          ),
                          if (_selectedDecks.isNotEmpty)
                            PopupMenuButton<String>(
                              onSelected: (action) =>
                                  _performDeckAction(action: action),
                              itemBuilder: (_) {
                                final selectedDecks = decks
                                    .where((d) => _selectedDecks.contains(d['id']))
                                    .toList();

                                final hasHidden =
                                    selectedDecks.any((d) => d['admin_hidden'] == true);
                                final hasVisible =
                                    selectedDecks.any((d) => d['admin_hidden'] != true);
                                final hasArchived =
                                    selectedDecks.any((d) => d['is_archived'] == true);
                                final hasUnarchived =
                                    selectedDecks.any((d) => d['is_archived'] != true);

                                return [
                                  if (hasUnarchived)
                                    const PopupMenuItem(
                                      value: "archive",
                                      child: Text("Archive"),
                                    ),
                                  if (hasArchived)
                                    const PopupMenuItem(
                                      value: "unarchive",
                                      child: Text("Unarchive"),
                                    ),
                                  if (hasVisible)
                                    const PopupMenuItem(
                                      value: "hide",
                                      child: Text("Hide"),
                                    ),
                                  if (hasHidden)
                                    const PopupMenuItem(
                                      value: "unhide",
                                      child: Text("Unhide"),
                                    ),
                                  const PopupMenuItem(
                                    value: "delete",
                                    child: Text("Delete"),
                                  ),
                                ];
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectMode = false;
                                _selectedDecks.clear();
                              });
                            },
                          ),
                        ],
                      )
                    : OutlinedButton.icon(
                        icon: const Icon(Icons.select_all),
                        label: const Text("Select"),
                        onPressed: () => setState(() => _selectMode = true),
                      ),
              ],
            ),
          ),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: decks.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == decks.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final deck = decks[index];
                        final deckId = deck['id'];
                        if (deckId == null) return const SizedBox.shrink();

                        final isSelected = _selectedDecks.contains(deckId);

                        return Card(
                          color: isSelected
                              ? Colors.blue.withAlpha((0.2 * 255).round())
                              : null,
                          child: ListTile(
                            onTap: () {
                              if (_selectMode) {
                                _toggleSelection(deckId);
                              } else {
                                _openDeckScreen(deckId);
                              }
                            },
                            onLongPress: () => _toggleSelection(deckId),
                            leading: _selectMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleSelection(deckId),
                                  )
                                : CircleAvatar(
                                    child: Text(
                                      deck['title']?[0].toUpperCase() ?? '?',
                                    ),
                                  ),
                            title: Text(deck['title'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Owner: ${deck['owner_username'] ?? '-'}",
                                ),
                                _buildStatusChips(deck),
                              ],
                            ),
                            trailing: !_selectMode
                                ? PopupMenuButton<String>(
                                    onSelected: (action) => _performDeckAction(
                                      action: action,
                                      deckIds: [deckId],
                                    ),
                                    itemBuilder: (_) => _buildDeckMenuItems(deck),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      );
    });
  }
}



class PublicDeckScreen extends StatefulWidget {
  final int deckId;
  const PublicDeckScreen({super.key, required this.deckId});

  @override
  State<PublicDeckScreen> createState() => _PublicDeckScreenState();
}

class _PublicDeckScreenState extends State<PublicDeckScreen> {
  bool _loading = true;
  Map<String, dynamic>? _deck;

  bool isArchived = false;
  bool isFlagged = false;
  bool adminHidden = false;

  String? flagReason;
  String? adminNote;

  @override
  void initState() {
    super.initState();
    _fetchDeck();
  }

  Future<void> _fetchDeck() async {
    final provider = context.read<AdminProvider>();
    final deck = await provider.getDeckDetail(widget.deckId, forceRefresh: true);

    if (!mounted || deck == null) return;

    setState(() {
      _deck = deck;
      _loading = false;
      isArchived = deck['is_archived'] ?? false;
      isFlagged = deck['is_flagged'] ?? false;
      adminHidden = deck['admin_hidden'] ?? false;
      flagReason = deck['flag_reason'];
      adminNote = deck['admin_note'];
    });
  }

  Future<void> _showFlagDialog(AdminProvider provider) async {
    final reasonController = TextEditingController(text: flagReason);
    final noteController = TextEditingController(text: adminNote);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Flag Deck"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: "Flag Reason",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: "Admin Note",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.flagDeck(widget.deckId, reasonController.text);
              await provider.updateDeck(widget.deckId, {
                'admin_note': noteController.text,
              });

              setState(() {
                isFlagged = true;
                flagReason = reasonController.text;
                adminNote = noteController.text;
              });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final deck = _deck!;
    final tags = List<String>.from(deck['tags'] ?? []);
    final flashcards = List<Map<String, dynamic>>.from(deck['flashcards'] ?? []);
    final comments = List<Map<String, dynamic>>.from(deck['comments'] ?? []);
    final averageRating = deck['average_rating'];

    final provider = context.read<AdminProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(deck['title'] ?? "Deck"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'archive':
                  isArchived
                      ? await provider.unarchiveDeck(widget.deckId)
                      : await provider.archiveDeck(widget.deckId);
                  setState(() => isArchived = !isArchived);
                  break;

                case 'hide':
                  adminHidden
                      ? await provider.unhideDeck(widget.deckId)
                      : await provider.hideDeck(widget.deckId);
                  setState(() => adminHidden = !adminHidden);
                  break;

                case 'flag':
                  if (isFlagged) {
                    await provider.unflagDeck(widget.deckId);
                    setState(() {
                      isFlagged = false;
                      flagReason = null;
                    });
                  } else {
                    await _showFlagDialog(provider);
                  }
                  break;

                case 'delete':
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Delete Deck"),
                      content: const Text(
                        "This cannot be undone. Only public decks are deletable.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final success = await provider.deleteDeck(widget.deckId);
                    if (success && mounted) {
                      Navigator.pop(context);
                    }
                  }
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    const Icon(Icons.archive),
                    const SizedBox(width: 10),
                    Text(isArchived ? "Unarchive" : "Archive"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'flag',
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.orange),
                    const SizedBox(width: 10),
                    Text(isFlagged ? "Unflag" : "Flag"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'hide',
                child: Row(
                  children: [
                    const Icon(Icons.visibility_off),
                    const SizedBox(width: 10),
                    Text(adminHidden ? "Unhide" : "Hide"),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 10),
                    Text("Delete"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          /// HEADER
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                if (deck['cover_image'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      deck['cover_image'],
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 12),

                Text(
                  deck['title'] ?? '-',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                const SizedBox(height: 6),
                Text("Owner: ${deck['owner_username'] ?? '-'}"),

                const SizedBox(height: 8),

                /// STATUS CHIPS
                Wrap(spacing: 8, children: [
                  if (isArchived)
                    const Chip(label: Text("Archived"), backgroundColor: Colors.grey),
                  if (isFlagged)
                    const Chip(label: Text("Flagged"), backgroundColor: Colors.orange),
                  if (adminHidden)
                    const Chip(label: Text("Hidden"), backgroundColor: Colors.redAccent),
                ]),

                const SizedBox(height: 10),

                Text(deck['description'] ?? '-'),

                const SizedBox(height: 10),

                /// TAGS
                Wrap(
                  spacing: 8,
                  children: tags.isNotEmpty
                      ? tags.map((e) => Chip(label: Text(e))).toList()
                      : const [Text("-")],
                ),

                if (averageRating != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text("$averageRating"),
                  ])
                ],
              ]),
            ),
          ),

          const SizedBox(height: 20),

          /// FLASHCARDS
          if (flashcards.isNotEmpty) ...[
            Text("Flashcards", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...flashcards.map((card) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    card['question'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(card['answer'] ?? ''),
                  ),

                  if (card['rating'] != null || card['flagged'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          if (card['rating'] != null) ...[
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text("${card['rating']}"),
                          ],
                          if (card['flagged'] == true) ...[
                            const SizedBox(width: 16),
                            const Chip(
                              label: Text("Flagged"),
                              backgroundColor: Colors.redAccent,
                            )
                          ]
                        ],
                      ),
                    ),
                ]),
              ),
            )),
          ],

          const SizedBox(height: 10),

          /// COMMENTS
          if (comments.isNotEmpty) ...[
            Text("Comments", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...comments.map((c) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      child: Text((c['user'] ?? 'U')[0]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                c['user'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (c['rating'] != null) ...[
                                const SizedBox(width: 10),
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text("${c['rating']}"),
                              ]
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(c['comment'] ?? ''),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ))
          ]
        ]),
      ),
    );
  }
}
