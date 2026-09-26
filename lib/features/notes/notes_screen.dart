import 'package:flutter/material.dart';

import '../../database/app_database.dart';
import '../../database/db.dart';
import '../../widgets/app_ui.dart';

/// Local notes for business reminders (orders, follow-ups, load, etc.).
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final list = await appDatabase.allNotes();
      if (!mounted) return;
      setState(() {
        _notes = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Note> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _notes;
    return _notes.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.body.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openEditor({Note? note}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _NoteEditorSheet(note: note),
    );
    if (saved == true) await _reload();
  }

  Future<void> _confirmDelete(Note note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          note.title.trim().isEmpty
              ? 'This note will be removed.'
              : 'Delete “${note.title.trim()}”?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await appDatabase.deleteNote(note.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note deleted')),
    );
    await _reload();
  }

  String _preview(Note note) {
    final body = note.body.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (body.isEmpty) return 'Empty note';
    return body.length > 120 ? '${body.substring(0, 120)}…' : body;
  }

  String _when(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year && local.month == now.month && local.day == now.day;
    final hm =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (sameDay) return hm;
    return '${local.month}/${local.day} $hm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('New note'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search notes',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? AppEmptyState(
                        icon: Icons.sticky_note_2_outlined,
                        title: _notes.isEmpty ? 'No notes yet' : 'No matches',
                        message: _notes.isEmpty
                            ? 'Save order reminders, customer follow-ups, load tips, or anything you need while sending SMS.'
                            : 'Try a different search.',
                        action: _notes.isEmpty
                            ? FilledButton.icon(
                                onPressed: () => _openEditor(),
                                icon: const Icon(Icons.note_add_outlined),
                                label: const Text('New note'),
                              )
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final note = items[i];
                            final title = note.title.trim().isEmpty
                                ? 'Untitled'
                                : note.title.trim();
                            return Dismissible(
                              key: ValueKey('note-${note.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: theme.colorScheme.errorContainer,
                                child: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                              confirmDismiss: (_) async {
                                await _confirmDelete(note);
                                return false;
                              },
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  title: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _preview(note),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  trailing: Text(
                                    _when(note.updatedAt),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  onTap: () => _openEditor(note: note),
                                  onLongPress: () => _confirmDelete(note),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({this.note});

  final Note? note;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _body.text.trim();
    if (body.isEmpty && _title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something first')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = widget.note;
      if (existing == null) {
        await appDatabase.insertNote(
          title: _title.text,
          body: body.isEmpty ? _title.text : body,
        );
      } else {
        await appDatabase.updateNote(
          id: existing.id,
          title: _title.text,
          body: body.isEmpty ? _title.text : body,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final editing = widget.note != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editing ? 'Edit note' : 'New note',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _body,
            minLines: 6,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Order tip, follow-up, load reminder…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(editing ? 'Save changes' : 'Save note'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
