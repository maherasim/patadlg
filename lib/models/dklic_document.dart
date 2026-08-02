class DklicDocument {
  DklicDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.subject,
    this.description,
    this.referenceNo,
    this.issueDate,
    this.effectiveDate,
    this.version,
    required this.audience,
    required this.priority,
    required this.ackRequired,
    required this.tags,
    required this.fileUrl,
    required this.format,
    required this.downloadCount,
    required this.viewCount,
    this.uploadedBy,
    this.publishedAt,
    required this.bookmarked,
    required this.acknowledged,
    required this.read,
  });

  factory DklicDocument.fromJson(Map<String, dynamic> json) => DklicDocument(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        description: json['description'] as String?,
        referenceNo: json['reference_no'] as String?,
        issueDate: json['issue_date'] as String?,
        effectiveDate: json['effective_date'] as String?,
        version: json['version'] as String?,
        audience: json['audience'] as String? ?? 'All',
        priority: json['priority'] as String? ?? 'normal',
        ackRequired: json['ack_required'] as bool? ?? false,
        tags: ((json['tags'] as List?) ?? []).cast<String>(),
        fileUrl: json['file_url'] as String? ?? '',
        format: json['format'] as String? ?? '',
        downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
        viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
        uploadedBy: json['uploaded_by'] as String?,
        publishedAt: json['published_at'] as String?,
        bookmarked: json['bookmarked'] as bool? ?? false,
        acknowledged: json['acknowledged'] as bool? ?? false,
        read: json['read'] as bool? ?? false,
      );

  final int id;
  final String title;
  final String category;
  final String subject;
  final String? description;
  final String? referenceNo;
  final String? issueDate;
  final String? effectiveDate;
  final String? version;
  final String audience;
  final String priority;
  final bool ackRequired;
  final List<String> tags;
  final String fileUrl;
  final String format;
  final int downloadCount;
  final int viewCount;
  final String? uploadedBy;
  final String? publishedAt;
  final bool bookmarked;
  final bool acknowledged;
  final bool read;

  bool get isUrgent => priority == 'urgent';

  DklicDocument copyWith({bool? bookmarked, bool? acknowledged, bool? read, int? downloadCount}) => DklicDocument(
        id: id,
        title: title,
        category: category,
        subject: subject,
        description: description,
        referenceNo: referenceNo,
        issueDate: issueDate,
        effectiveDate: effectiveDate,
        version: version,
        audience: audience,
        priority: priority,
        ackRequired: ackRequired,
        tags: tags,
        fileUrl: fileUrl,
        format: format,
        downloadCount: downloadCount ?? this.downloadCount,
        viewCount: viewCount,
        uploadedBy: uploadedBy,
        publishedAt: publishedAt,
        bookmarked: bookmarked ?? this.bookmarked,
        acknowledged: acknowledged ?? this.acknowledged,
        read: read ?? this.read,
      );
}

const List<String> kDklicCategories = [
  'Rules',
  'Punjab Gazette',
  'Government Notification',
  'Circular',
  'SOP',
  'Office Order',
  'Manual',
  'Policy',
  'Form/Template',
  'Training Material',
  'Act',
  'Official Letter',
];

class DklicAiSource {
  DklicAiSource({required this.id, required this.title, this.referenceNo, required this.category});

  factory DklicAiSource.fromJson(Map<String, dynamic> json) => DklicAiSource(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        referenceNo: json['reference_no'] as String?,
        category: json['category'] as String? ?? '',
      );

  final int id;
  final String title;
  final String? referenceNo;
  final String category;
}

class DklicAiAnswer {
  DklicAiAnswer({required this.answer, required this.sources});

  factory DklicAiAnswer.fromJson(Map<String, dynamic> json) => DklicAiAnswer(
        answer: json['answer'] as String? ?? '',
        sources: ((json['sources'] as List?) ?? []).cast<Map<String, dynamic>>().map(DklicAiSource.fromJson).toList(),
      );

  final String answer;
  final List<DklicAiSource> sources;
}
