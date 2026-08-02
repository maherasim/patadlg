import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/dklic_document.dart';
import '../services/dklic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dklic/dklic_detail_sheet.dart';
import '../widgets/logout_action.dart';
import '../widgets/notification_bell.dart';

const _kFilters = [
  ('all', 'All'),
  ('urgent', 'Urgent'),
  ('bookmarked', 'Bookmarked'),
  ('unread', 'Unread'),
  ('recent', 'Recent'),
];

/// Local Government Library (DKLIC) — shared across all three roles, same
/// endpoints and filters as web's DklicKnowledge component, just a list
/// instead of a two-column grid.
class DklicScreen extends StatefulWidget {
  const DklicScreen({super.key, required this.role, required this.user});

  final String role;
  final Map<String, dynamic> user;

  @override
  State<DklicScreen> createState() => _DklicScreenState();
}

class _DklicScreenState extends State<DklicScreen> {
  bool _loading = true;
  String? _error;
  List<DklicDocument> _documents = [];

  String _search = '';
  String? _category;
  String _filter = 'all';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final documents = await DklicService.instance.index(role: widget.role, search: _search, category: _category, filter: _filter);
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load the library.";
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    _search = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _openDetail(DklicDocument doc) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DklicDetailSheet(
        role: widget.role,
        document: doc,
        onChanged: (updated) {
          setState(() {
            final i = _documents.indexWhere((d) => d.id == updated.id);
            if (i != -1) _documents[i] = updated;
          });
        },
      ),
    );
  }

  Future<void> _toggleBookmark(DklicDocument doc) async {
    setState(() {
      final i = _documents.indexWhere((d) => d.id == doc.id);
      if (i != -1) _documents[i] = doc.copyWith(bookmarked: !doc.bookmarked);
    });
    try {
      final bookmarked = await DklicService.instance.toggleBookmark(role: widget.role, documentId: doc.id);
      if (!mounted) return;
      setState(() {
        final i = _documents.indexWhere((d) => d.id == doc.id);
        if (i != -1) _documents[i] = doc.copyWith(bookmarked: bookmarked);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _documents.indexWhere((d) => d.id == doc.id);
        if (i != -1) _documents[i] = doc;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Local Government Library'),
        actions: const [NotificationBell(), LogoutAction()],
      ),
      drawer: AppDrawer(role: widget.role, currentKey: 'dklic', user: widget.user),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DKLIC — Digital Knowledge, Legal Intelligence & Notifications Centre', style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                const SizedBox(height: 12),
                TextField(
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(hintText: 'Search rules, gazette no., subject…', prefixIcon: Icon(Icons.search_rounded, size: 20)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Categories')),
                    ...kDklicCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  ],
                  onChanged: (v) {
                    setState(() => _category = v);
                    _load();
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _kFilters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final (key, label) = _kFilters[i];
                      final selected = _filter == key;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _filter = key);
                          _load();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary500 : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? AppColors.primary500 : AppColors.border),
                          ),
                          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.inkMuted)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _documents.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 100),
                                  Center(child: Text('No documents match the current filters.', style: TextStyle(color: AppColors.inkFaint))),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                                itemCount: _documents.length,
                                itemBuilder: (context, i) {
                                  final doc = _documents[i];
                                  return _DocumentCard(
                                    doc: doc,
                                    onOpen: () => _openDetail(doc),
                                    onBookmark: () => _toggleBookmark(doc),
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.doc, required this.onOpen, required this.onBookmark});

  final DklicDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final borderColor = doc.isUrgent ? AppColors.danger : AppColors.primary500;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
          left: BorderSide(color: borderColor, width: 4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _tag(doc.category, AppColors.inkMuted),
                        _tag(doc.priority.toUpperCase(), doc.isUrgent ? AppColors.danger : AppColors.primary500),
                        if (!doc.read) Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.info, shape: BoxShape.circle)),
                        if (doc.ackRequired && !doc.acknowledged) _tag('Ack Required', AppColors.info),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(doc.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(doc.subject, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        if (doc.referenceNo != null && doc.referenceNo!.isNotEmpty)
                          Text('Ref: ${doc.referenceNo}', style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                        if (doc.publishedAt != null)
                          Text(doc.publishedAt!.split('T').first, style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                        Text(doc.format, style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onBookmark,
                icon: Icon(
                  doc.bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 20,
                  color: doc.bookmarked ? AppColors.accent500 : AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
