import 'package:flutter/material.dart';

import 'slash_templates.dart';

/// Shows a `/` quick-reply list when the [controller] ends with `/query`.
class SlashQuickReplyPanel extends StatefulWidget {
  const SlashQuickReplyPanel({
    super.key,
    required this.controller,
    this.maxHeight = 280,
  });

  final TextEditingController controller;
  final double maxHeight;

  @override
  State<SlashQuickReplyPanel> createState() => _SlashQuickReplyPanelState();
}

class _SlashQuickReplyPanelState extends State<SlashQuickReplyPanel> {
  String? _query;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _onChanged();
  }

  @override
  void didUpdateWidget(covariant SlashQuickReplyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _onChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = SlashTemplates.activeQuery(widget.controller.text);
    if (next != _query) {
      setState(() => _query = next);
    }
  }

  void _pick(SlashTemplate t) {
    final body = t.resolvedBody();
    final next = SlashTemplates.apply(widget.controller.text, body);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() => _query = null);
  }

  void _dismiss() {
    // Remove trailing `/query` so the panel closes without inserting.
    final text = widget.controller.text;
    final m = RegExp(r'(^|\s)/([a-zA-Z0-9_]*)$').firstMatch(text);
    if (m == null) {
      setState(() => _query = null);
      return;
    }
    final next = text.substring(0, m.start) + (m.group(1) ?? '');
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() => _query = null);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    if (query == null) return const SizedBox.shrink();

    final items = SlashTemplates.filter(query);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      color: scheme.surfaceContainerLowest,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.65),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap a quick reply — type / then a keyword',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: _dismiss,
                    icon: Icon(Icons.close, size: 18, color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No templates match “/$query”',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: scheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final t = items[index];
                    final preview = t.resolvedBody().replaceAll('\n', ' ');
                    return InkWell(
                      onTap: () => _pick(t),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      _KeywordChip(label: '/${t.keyword}'),
                                      for (final a in t.aliases)
                                        _KeywordChip(label: '/$a', muted: true),
                                      Text(
                                        t.title,
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    preview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: muted
            ? scheme.surfaceContainerHighest
            : scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: muted ? scheme.onSurfaceVariant : scheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
