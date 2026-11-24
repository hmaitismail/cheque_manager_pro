import 'package:flutter/material.dart';

/// Champ texte avec suggestions (bénéficiaires et villes déjà saisis).
class ChampSuggestions extends StatefulWidget {
  const ChampSuggestions({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.label,
    this.icone,
    this.validator,
    this.capitalisation = TextCapitalization.words,
  });
  final TextEditingController controller;
  final List<String> suggestions;
  final String label;
  final IconData? icone;
  final String? Function(String?)? validator;
  final TextCapitalization capitalisation;

  @override
  State<ChampSuggestions> createState() => _ChampSuggestionsState();
}

class _ChampSuggestionsState extends State<ChampSuggestions> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return widget.suggestions
            .where((s) => s.toLowerCase().contains(q) && s.toLowerCase() != q)
            .take(6);
      },
      fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextFormField(
        controller: ctrl,
        focusNode: focus,
        textCapitalization: widget.capitalisation,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: widget.icone == null ? null : Icon(widget.icone),
        ),
      ),
      optionsViewBuilder: (ctx, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: options
                  .map(
                    (o) => ListTile(
                      dense: true,
                      title: Text(o),
                      onTap: () => onSelected(o),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
