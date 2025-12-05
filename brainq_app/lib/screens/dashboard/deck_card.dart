import 'package:flutter/material.dart'; 
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/deck_item.dart';
import '../../models/deck_theme.dart';
import '../../providers/deck_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../screens/quiz/deck_screen.dart';
import 'deck_share_screen.dart';

class DeckCard extends StatelessWidget {
  final DeckItem deck;
  final bool showArchiveOption;
  final bool showEditDeleteOptions;

  const DeckCard({
    super.key,
    required this.deck,
    this.showArchiveOption = false,
    this.showEditDeleteOptions = false,
  });

  @override
  Widget build(BuildContext context) {
    final deckProv = Provider.of<DeckProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isOwner = deck.ownerId?.trim() == auth.userId?.trim();

   
    final deckTheme = deck.theme ?? themeProvider.activeDeckTheme ?? DeckTheme.defaultTheme();
    final accentColor = themeProvider.adaptDeckColor(
      deckTheme.cardColor ?? deckTheme.accentColor,
      fallback: Theme.of(context).primaryColor,
    );


    final icons = [Icons.psychology, Icons.lightbulb, Icons.memory, Icons.emoji_objects];
    final icon = icons[deck.id.hashCode % icons.length];


    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          deckProv.markDeckRecent(deck);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DeckScreen(deck: deck)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor.withValues(alpha:0.85), accentColor.withValues(alpha:0.95)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                  border: Border.all(
                    color: Colors.white70,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(2, 2),
                    ),
                  ],
                  image: deck.fullCoverImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(deck.fullCoverImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: deck.fullCoverImageUrl == null
                    ? Icon(
                        icon,
                        color: Colors.white,
                        size: 36,
                      )
                    : null,
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
                            deck.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!deck.isPublic)
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
                      '${deck.cardCount} cards',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    if (deck.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: deck.tags
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    t,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              if (isOwner || deck.isPublic)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (val) async {
                    switch (val) {
                      case 'edit':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeckScreen(deck: deck, editMode: true),
                          ),
                        );
                        break;
                      case 'share':
                        if (isOwner) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeckShareScreen(
                                deck: deck,
                                userToken: auth.token ?? '',
                                isOwner: isOwner,
                              ),
                            ),
                          );
                        } else {
                          final link = deck.shareUrl;
                          if (link == null || link.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Public link not enabled")),
                            );
                            return;
                          }
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Share Deck Link"),
                              content: SingleChildScrollView(
                                child: SelectableText(
                                  link,
                                  style: const TextStyle(fontSize: 16, color: Colors.blueAccent),
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
                                ElevatedButton(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: link));
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Link copied to clipboard")),
                                    );
                                  },
                                  child: const Text("Copy"),
                                ),
                              ],
                            ),
                          );
                        }
                        break;
                      case 'delete':
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Delete Deck?"),
                            content: const Text(
                                "Are you sure you want to delete this deck?\nThis action cannot be undone."),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await deckProv.deleteDeck(deck.id);
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text("Deck deleted.")),
                                    );
                                  } catch (_) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text("Failed to delete deck.")),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text("Delete"),
                              ),
                            ],
                          ),
                        );
                        break;
                      case 'archive':
                        await deckProv.toggleArchiveDeck(deck);
                        break;
                    }
                  },
                  itemBuilder: (_) {
                    final items = <PopupMenuEntry<String>>[];

                    if (isOwner) {
                      if (!deck.archived && showEditDeleteOptions) {
                        items.add(const PopupMenuItem(value: 'edit', child: Text('Edit')));
                      }
                      if (showEditDeleteOptions) {
                        items.add(const PopupMenuItem(value: 'delete', child: Text('Delete')));
                      }
                      if (showArchiveOption) {
                        items.add(PopupMenuItem(
                          value: 'archive',
                          child: Text(deck.archived ? 'Unarchive' : 'Archive'),
                        ));
                      }

                      if (!deck.archived) {
                        items.add(const PopupMenuItem(value: 'share', child: Text('Share')));
                      }
                    } else if (deck.isPublic && !deck.archived) {
                    
                      items.add(const PopupMenuItem(value: 'share', child: Text('Share')));
                    }

                    return items;
                  },

                ),
            ],
          ),
        ),
      ),
    );
  }
}
