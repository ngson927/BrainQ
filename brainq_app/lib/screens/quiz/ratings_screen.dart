import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import 'package:brainq_app/providers/auth_provider.dart';

class RatingScreen extends StatefulWidget {
  final int deckId;
  final bool canRate;

  const RatingScreen({super.key, required this.deckId, this.canRate = true});

  @override
  RatingScreenState createState() => RatingScreenState();
}

class RatingScreenState extends State<RatingScreen> {
  double _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;
  bool _submitting = false;
  bool _canRate = true;
  int? _feedbackId;

  bool _loadingAllFeedback = true;
  List<Map<String, dynamic>> _allFeedback = [];

  @override
  void initState() {
    super.initState();
    _canRate = widget.canRate;
    _loadExistingFeedback();
    _loadAllFeedback();
  }

  Future<void> _loadExistingFeedback() async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception("Not logged in");

      final response = await ApiService.getUserFeedback(
        token: token,
        deckId: widget.deckId,
      );

      if (response.statusCode == 403) {
        final msg = jsonDecode(response.body)["detail"];
        if (msg == "You cannot rate your own deck." ||
            msg == "You can only comment on public decks.") {
          setState(() => _canRate = false);
        }
        return;
      }

      if (response.statusCode == 204) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _rating = (data["rating"] ?? 0).toDouble();
          _commentController.text = data["comment"] ?? "";
          _feedbackId = data["id"];
        });
      }
    } catch (e) {
      debugPrint("Error loading feedback: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllFeedback() async {
    setState(() => _loadingAllFeedback = true);
    try {
      final response = await ApiService.getDeckFeedback(deckId: widget.deckId);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _allFeedback = data.map((e) => e as Map<String, dynamic>).toList();

          // For owners: compute average rating
          if (!_canRate && _allFeedback.isNotEmpty) {
            final total = _allFeedback.fold<double>(
              0,
              (sum, f) => sum + (f["rating"]?.toDouble() ?? 0),
            );
            _rating = total / _allFeedback.length;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading all feedback: $e");
    } finally {
      setState(() => _loadingAllFeedback = false);
    }
  }

  Future<void> _submitRating() async {
    if (!_canRate) return;

    if (_rating == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = true);

    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception("Not logged in");

      final response = _feedbackId != null
          ? await ApiService.updateFeedback(
              token: token,
              feedbackId: _feedbackId!,
              rating: _rating.toInt(),
              comment: _commentController.text.trim(),
            )
          : await ApiService.addFeedback(
              token: token,
              deckId: widget.deckId,
              rating: _rating.toInt(),
              comment: _commentController.text.trim(),
            );

      if (!mounted) return;

      if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonDecode(response.body)["detail"])),
        );
        return;
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Failed to save feedback");
      }

      if (_feedbackId == null) {
        final data = jsonDecode(response.body);
        _feedbackId = data["id"];
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback saved!')),
        );
      }

      if (!mounted) return;
      await _loadAllFeedback();

      if (!mounted) return;
      await _loadExistingFeedback();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit rating: $e')),
        );
      }
    } finally {

      if (mounted) setState(() => _submitting = false);
    }
  }


  Future<void> _deleteRating() async {
    if (_feedbackId == null) return;

    if (!mounted) return;
    setState(() => _submitting = true);

    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) throw Exception("Not logged in");

      final response = await ApiService.deleteFeedback(
        token: token,
        feedbackId: _feedbackId!,
      );

      if (!mounted) return;

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception("Failed to delete feedback");
      }

      if (mounted) {
        setState(() {
          _feedbackId = null;
          _rating = 0;
          _commentController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback deleted')),
        );
      }

      if (!mounted) return;
      await _loadAllFeedback();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete feedback: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Rate Deck")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Title and Average Rating for owners
            Text(
              _canRate ? "How would you rate this deck?" : "Average Rating: ${_rating.toStringAsFixed(1)}",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _canRate
                ? RatingBar.builder(
                    initialRating: _rating,
                    minRating: 1,
                    maxRating: 5,
                    itemCount: 5,
                    itemSize: 50,
                    itemBuilder: (_, _) =>
                        const Icon(Icons.star, color: Colors.amber),
                    onRatingUpdate: (value) => setState(() => _rating = value),
                  )
                : RatingBarIndicator(
                    rating: _rating,
                    itemBuilder: (_, _) =>
                        const Icon(Icons.star, color: Colors.amber),
                    itemCount: 5,
                    itemSize: 50,
                  ),
            const SizedBox(height: 24),

            if (_canRate) ...[
              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Add a comment...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitRating,
                      child: _submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_feedbackId != null ? "Update" : "Submit"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_feedbackId != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _deleteRating,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                        child: _submitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Delete"),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            const Divider(),
            const SizedBox(height: 12),

            Expanded(
              child: _loadingAllFeedback
                  ? const Center(child: CircularProgressIndicator())
                  : _allFeedback.isEmpty
                      ? const Center(child: Text("No feedback yet."))
                      : ListView.separated(
                          itemCount: _allFeedback.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) {
                            final feedback = _allFeedback[index];
                            final userField = feedback["user"];
                            final username = userField is String
                                ? userField
                                : userField?["username"] ?? "Anonymous";
                            final rating = (feedback["rating"] ?? 0).toDouble();
                            final comment = feedback["comment"] ?? "";

                            return ListTile(
                              title: Row(
                                children: [
                                  Text(username,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  RatingBarIndicator(
                                    rating: rating,
                                    itemBuilder: (_, _) => const Icon(
                                        Icons.star, color: Colors.amber),
                                    itemCount: 5,
                                    itemSize: 16,
                                  ),
                                ],
                              ),
                              subtitle: comment.isNotEmpty ? Text(comment) : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
