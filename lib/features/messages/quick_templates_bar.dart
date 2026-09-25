import 'package:flutter/material.dart';

import '../../database/app_database.dart';
import '../../database/db.dart';
import '../../widgets/app_ui.dart';

/// One-tap SMS templates shared with Blast / Message / Thread.
class QuickTemplatesBar extends StatefulWidget {
  const QuickTemplatesBar({
    super.key,
    required this.onSelect,
    this.getBodyForSave,
    this.allowSave = false,
    this.allowDelete = true,
    this.showHeader = true,
  });

  final ValueChanged<String> onSelect;
  final String Function()? getBodyForSave;
  final bool allowSave;
  final bool allowDelete;
  final bool showHeader;

  @override
  State<QuickTemplatesBar> createState() => QuickTemplatesBarState();
}

class QuickTemplatesBarState extends State<QuickTemplatesBar> {
  List<SmsTemplate> _templates = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final list = await appDatabase.allTemplates();
    if (!mounted) return;
    setState(() {
      _templates = list;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final body = widget.getBodyForSave?.call().trim() ?? '';
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a message first, then save it as a template')),
      );
      return;
    }
    final titleCtrl = TextEditingController(
      text: body.length > 24 ? '${body.substring(0, 24)}…' : body,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save template'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'e.g. Price list, ETA, Thank you',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final title = titleCtrl.text.trim();
    titleCtrl.dispose();
    if (ok != true || !mounted) return;
    await appDatabase.addTemplate(title.isEmpty ? 'Template' : title, body);
    await reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template saved — also available in Blast')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasTemplates = _templates.isNotEmpty;
    if (!hasTemplates && !widget.allowSave) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader)
          AppSectionHeader(
            'Quick templates',
            trailing: widget.allowSave
                ? TextButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  )
                : null,
          )
        else if (widget.allowSave)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Save template'),
            ),
          ),
        if (hasTemplates)
          Padding(
            padding: EdgeInsets.only(bottom: widget.showHeader ? 0 : 8),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _templates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final t = _templates[index];
                  return InputChip(
                    label: Text(t.title),
                    tooltip: t.body,
                    onPressed: () => widget.onSelect(t.body),
                    onDeleted: widget.allowDelete
                        ? () async {
                            await appDatabase.deleteTemplate(t.id);
                            await reload();
                          }
                        : null,
                  );
                },
              ),
            ),
          )
        else if (widget.allowSave && widget.showHeader)
          Text(
            'No templates yet. Write a reply you use often, then tap Save.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
