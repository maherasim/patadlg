import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_theme.dart';

bool isImageUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp') || lower.endsWith('.gif');
}

/// Full-screen zoomable preview for an image URL.
void showImagePreview(BuildContext context, String url) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          ),
        ),
      ),
    ),
  ));
}

/// PDFs/non-image documents can't be previewed in-app yet — hand the link to
/// the OS share sheet instead, so the user can open it in a browser or PDF
/// viewer of their choice.
Future<void> shareDocumentLink(String url) async {
  await SharePlus.instance.share(ShareParams(uri: Uri.parse(url)));
}

/// Taps route to the right preview automatically based on file extension.
void openDocument(BuildContext context, String url) {
  if (isImageUrl(url)) {
    showImagePreview(context, url);
  } else {
    shareDocumentLink(url);
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({required this.url, required this.label, required this.onTap});

  final String url;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isImage = isImageUrl(url);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: isImage
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: AppColors.inkFaint),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary500, size: 22),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 9, color: AppColors.inkFaint), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
      ),
    );
  }
}

/// Mirrors the web app's PartyPhotosDisplay — two labeled galleries, or
/// nothing at all if both are empty.
class PartyPhotosDisplay extends StatelessWidget {
  const PartyPhotosDisplay({
    super.key,
    required this.divorcerPhotos,
    required this.respondentPhotos,
    required this.divorcerLabel,
    required this.respondentLabel,
  });

  final List<String> divorcerPhotos;
  final List<String> respondentPhotos;
  final String divorcerLabel;
  final String respondentLabel;

  @override
  Widget build(BuildContext context) {
    if (divorcerPhotos.isEmpty && respondentPhotos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (divorcerPhotos.isNotEmpty) _gallery(context, '$divorcerLabel Photos (${divorcerPhotos.length})', divorcerPhotos),
        if (divorcerPhotos.isNotEmpty && respondentPhotos.isNotEmpty) const SizedBox(height: 14),
        if (respondentPhotos.isNotEmpty) _gallery(context, '$respondentLabel Photos (${respondentPhotos.length})', respondentPhotos),
      ],
    );
  }

  Widget _gallery(BuildContext context, String title, List<String> urls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: urls
              .asMap()
              .entries
              .map((e) => _ThumbnailTile(url: e.value, label: 'Photo ${e.key + 1}', onTap: () => openDocument(context, e.value)))
              .toList(),
        ),
      ],
    );
  }
}

/// Mirrors the web app's KhulaDocumentsDisplay — a labeled grid of Court
/// Decree files (images or PDFs).
class KhulaDocumentsDisplay extends StatelessWidget {
  const KhulaDocumentsDisplay({super.key, required this.documents});

  final List<String> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Court Decree (${documents.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: documents
              .asMap()
              .entries
              .map((e) => _ThumbnailTile(url: e.value, label: 'Doc ${e.key + 1}', onTap: () => openDocument(context, e.value)))
              .toList(),
        ),
      ],
    );
  }
}
