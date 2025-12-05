import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../models/deck_theme.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class DeckCustomizeScreen extends StatefulWidget {
  final int deckId;
  final String token;

  const DeckCustomizeScreen({
    super.key,
    required this.deckId,
    required this.token,
  });

  @override
  State<DeckCustomizeScreen> createState() => _DeckCustomizeScreenState();
}

class _DeckCustomizeScreenState extends State<DeckCustomizeScreen> {
  Map<String, dynamic> themeData = {};
  bool saveAsNew = false;
  bool isLoading = true;

  final List<String> fontOptions = ['Roboto', 'Arial', 'Poppins', 'Montserrat'];
  final List<String> layoutOptions = ['classic', 'minimal', 'compact'];

  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  List<DeckTheme> availableThemes = [];
  DeckTheme? selectedTheme;

  @override
  void initState() {
    super.initState();
    _loadAvailableThemes();
    _loadTheme();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final themeProvider = Provider.of<ThemeProvider>(context);
    availableThemes = List.from(themeProvider.availableThemes);

    // Include deck's current theme if missing
    final deckThemeId = themeData['theme_id'];
    if (deckThemeId != null && !availableThemes.any((t) => t.id == deckThemeId)) {
      availableThemes.add(
        DeckTheme(
          id: deckThemeId,
          name: themeData['name'] ?? 'Custom',
          backgroundColor: themeData['background_color'] ?? '#FFFFFF',
          textColor: themeData['text_color'] ?? '#000000',
          accentColor: themeData['accent_color'] ?? '#4f46e5',
          fontFamily: themeData['font_family'] ?? 'Roboto',
          fontSize: themeData['font_size'] ?? 16,
          layoutStyle: themeData['layout_style'] ?? 'classic',
          borderRadius: themeData['border_radius'] ?? 12,
          cardSpacing: themeData['card_spacing'] ?? 12,
        ),
      );
    }

    // Set selectedTheme
    if (selectedTheme == null && availableThemes.isNotEmpty) {
      selectedTheme = availableThemes.firstWhere(
        (t) => t.id == themeData['theme_id'],
        orElse: () => availableThemes.first,
      );
    }
  }


  void _loadAvailableThemes() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    availableThemes = List.from(themeProvider.availableThemes);
  }

  Future<void> _loadTheme() async {
    final response = await ApiService.getDeckTheme(
      token: widget.token,
      deckId: widget.deckId,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Initialize defaults if missing
      data['font_family'] ??= fontOptions.first;
      data['layout_style'] ??= layoutOptions.first;
      data['font_size'] ??= 16;
      data['border_radius'] ??= 12;
      data['card_spacing'] ??= 12;
      data['background_color'] ??= '#FFFFFF';
      data['text_color'] ??= '#000000';
      data['accent_color'] ??= '#4f46e5';
      data['name'] ??= '';
      data['description'] ??= '';

      _nameController.text = data['name'];
      _descController.text = data['description'];

      setState(() {
        themeData = data;

        selectedTheme = availableThemes.firstWhere(
          (t) => t.id == data['theme_id'],
          orElse: () {
            final fallback = Provider.of<ThemeProvider>(context, listen: false).activeDeckTheme;
            if (fallback != null) return fallback;
            if (availableThemes.isNotEmpty) return availableThemes.first;
            return DeckTheme(
              id: 13,
              name: "System Default",
              backgroundColor: "#FFFFFF",
              textColor: "#000000",
              accentColor: "#4f46e5",
              fontFamily: "Roboto",
              fontSize: 14,
              layoutStyle: "classic",
              borderRadius: 8,
              cardSpacing: 12,
            );
          },
        );

        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }


  Map<String, dynamic> _sanitizeThemeData(Map<String, dynamic> data) {
    final fixed = Map<String, dynamic>.from(data);
    const intFields = ['font_size', 'border_radius', 'card_spacing'];
    for (final key in intFields) {
      if (fixed[key] != null && fixed[key] is double) {
        fixed[key] = (fixed[key] as double).round();
      }
    }
    return fixed;
  }

Future<DeckTheme> _saveTheme() async {
  themeData['name'] = _nameController.text;
  themeData['description'] = _descController.text;

  final cleanData = _sanitizeThemeData(themeData);

  // Call API
  final response = await ApiService.customizeDeckTheme(
    token: widget.token,
    deckId: widget.deckId,
    themeData: cleanData,
    saveAsNew: saveAsNew,
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    // Create a DeckTheme object from backend response with safe conversions
    final DeckTheme savedTheme = DeckTheme(
      id: data['id'],
      name: data['name'] ?? 'Unnamed',
      description: data['description'] ?? '',
      backgroundColor: data['background_color'] ?? '#FFFFFF',
      textColor: data['text_color'] ?? '#000000',
      accentColor: data['accent_color'] ?? '#4f46e5',
      fontFamily: data['font_family'] ?? 'Roboto',
      fontSize: (data['font_size']?.toDouble()) ?? 16,
      layoutStyle: data['layout_style'] ?? 'classic',
      borderRadius: (data['border_radius']?.toDouble()) ?? 12,
      cardSpacing: (data['card_spacing']?.toDouble()) ?? 12,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Theme saved successfully')),
      );

      Navigator.pop(context, savedTheme);
    }

    return savedTheme;
  } else {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to save theme')),
      );
    }
    throw Exception('Failed to save theme: ${response.statusCode}');
  }
}




  Future<void> _resetToDefault() async {
    await ApiService.customizeDeckTheme(
      token: widget.token,
      deckId: widget.deckId,
      resetToDefault: true,
    );
    _loadTheme();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex'; 
    return Color(int.parse(hex, radix: 16));
  }


  String _colorToHex(Color color) {
    final r = (color.r * 255).round() & 0xFF;
    final g = (color.g * 255).round() & 0xFF;
    final b = (color.b * 255).round() & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
          '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
          '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  // Color picker dialog
  Future<void> _pickColor(String key, Color current) async {
    Color selectedColor = current;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Color"),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) => selectedColor = c,
            enableAlpha: false,
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() => themeData[key] = _colorToHex(selectedColor));
              Navigator.pop(context);
            },
            child: const Text("Select"),
          ),
        ],
      ),
    );
  }

  // Color picker widget
  Widget _colorPicker(String label, String key) {
    final current = _hexToColor(themeData[key] ?? '#FFFFFF');
    return ListTile(
      title: Text(label),
      trailing: GestureDetector(
        onTap: () => _pickColor(key, current),
        child: CircleAvatar(backgroundColor: current),
      ),
    );
  }

  Widget _slider(String label, String key, int min, int max) {
    final value = (themeData[key] ?? min).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label: ${value.round()}"),
        Slider(
          value: value,
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: value.round().toString(),
          onChanged: (val) => setState(() => themeData[key] = val.round()),
        ),
      ],
    );
  }

  Widget _dropdown(String label, String key, List<String> options, {bool isFont = false}) {
    String currentValue = themeData[key] ?? options.first;
    if (!options.contains(currentValue)) {
      currentValue = options.first;
      themeData[key] = currentValue;
    }

    return DropdownButtonFormField<String>(
      initialValue: currentValue,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((e) => DropdownMenuItem(
                value: e,
                child: isFont
                    ? Text(e, style: TextStyle(fontFamily: e))
                    : Text(e),
              ))
          .toList(),
      onChanged: (val) => setState(() => themeData[key] = val),
    );
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    availableThemes = List.from(themeProvider.availableThemes);

    // Include deck's current theme if missing
    final deckThemeId = themeData['theme_id'];
    if (deckThemeId != null &&
        !availableThemes.any((t) => t.id == deckThemeId)) {
      availableThemes.add(
        DeckTheme(
          id: deckThemeId,
          name: themeData['name'] ?? 'Custom',
          backgroundColor: themeData['background_color'] ?? '#FFFFFF',
          textColor: themeData['text_color'] ?? '#000000',
          accentColor: themeData['accent_color'] ?? '#4f46e5',
          fontFamily: themeData['font_family'] ?? 'Roboto',
          fontSize: themeData['font_size'] ?? 16,
          layoutStyle: themeData['layout_style'] ?? 'classic',
          borderRadius: themeData['border_radius'] ?? 12,
          cardSpacing: themeData['card_spacing'] ?? 12,
        ),
      );
    }

    // Set selectedTheme if null
    if (selectedTheme == null && availableThemes.isNotEmpty) {
      selectedTheme = availableThemes.firstWhere(
        (t) => t.id == themeData['theme_id'],
        orElse: () => availableThemes.first,
      );
    }

    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Deck Customization')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (availableThemes.isNotEmpty)
              DropdownButtonFormField<int>(
                initialValue: selectedTheme?.id,
                decoration: const InputDecoration(labelText: 'Select Theme'),
                items: availableThemes
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.name ?? 'Unnamed'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  final theme = availableThemes.firstWhere((t) => t.id == val);
                  setState(() {
                    selectedTheme = theme;

                    themeData['theme_id'] = theme.id;
                    themeData['background_color'] = theme.backgroundColor;
                    themeData['text_color'] = theme.textColor;
                    themeData['accent_color'] = theme.accentColor;
                    themeData['font_family'] = theme.fontFamily;
                    themeData['layout_style'] = theme.layoutStyle;
                    themeData['font_size'] = theme.fontSize;
                    themeData['border_radius'] = theme.borderRadius;
                    themeData['card_spacing'] = theme.cardSpacing;
                  });

                  // Notify ThemeProvider
                  Provider.of<ThemeProvider>(context, listen: false)
                      .setActiveDeckTheme(theme);


                },
              ),

            // Name & Description
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Theme Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Theme Description'),
            ),

            const SizedBox(height: 24),
            const Text("Live Preview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              color: _hexToColor(themeData['background_color']),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular((themeData['border_radius'] ?? 12).toDouble()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Sample Card",
                  style: TextStyle(
                    color: _hexToColor(themeData['text_color']),
                    fontSize: (themeData['font_size'] ?? 16).toDouble(),
                    fontFamily: themeData['font_family'],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            _colorPicker('Background Color', 'background_color'),
            _colorPicker('Text Color', 'text_color'),
            _colorPicker('Accent Color', 'accent_color'),
            const SizedBox(height: 12),
            _dropdown('Font Family', 'font_family', fontOptions, isFont: true),
            const SizedBox(height: 12),
            _dropdown('Layout Style', 'layout_style', layoutOptions),
            const SizedBox(height: 12),
            _slider('Font Size', 'font_size', 12, 30),
            _slider('Border Radius', 'border_radius', 0, 30),
            _slider('Card Spacing', 'card_spacing', 4, 40),

            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Save as new theme'),
              value: saveAsNew,
              onChanged: (val) => setState(() => saveAsNew = val),
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Theme'),
                    onPressed: _saveTheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset Default'),
                    onPressed: _resetToDefault,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
