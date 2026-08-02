class NewsletterOption {
  NewsletterOption({required this.id, required this.label});

  factory NewsletterOption.fromJson(Map<String, dynamic> json) => NewsletterOption(
        id: json['id'] as int,
        label: json['label'] as String? ?? '',
      );

  final int id;
  final String label;
}

class NewsletterMyResponse {
  NewsletterMyResponse({required this.optionId, this.remarks, this.respondedAt});

  factory NewsletterMyResponse.fromJson(Map<String, dynamic> json) => NewsletterMyResponse(
        optionId: json['option_id'] as int,
        remarks: json['remarks'] as String?,
        respondedAt: json['responded_at'] as String?,
      );

  final int optionId;
  final String? remarks;
  final String? respondedAt;
}

/// A directive/circular published by the Super Admin — ADLG and DDLG both
/// see the same feed and each responds independently (mirrors the web app's
/// adlg/Newsletters.jsx and ddlg/Newsletters.jsx, which are functionally
/// identical bar the API route prefix).
class Newsletter {
  Newsletter({
    required this.id,
    required this.subject,
    required this.body,
    required this.priority,
    this.attachmentUrl,
    required this.options,
    required this.publishedAt,
    this.myResponse,
  });

  factory Newsletter.fromJson(Map<String, dynamic> json) => Newsletter(
        id: json['id'] as int,
        subject: json['subject'] as String? ?? '',
        body: json['body'] as String? ?? '',
        priority: json['priority'] as String? ?? 'normal',
        attachmentUrl: json['attachment_url'] as String?,
        options: ((json['options'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(NewsletterOption.fromJson)
            .toList(),
        publishedAt: json['published_at'] as String? ?? '',
        myResponse: json['my_response'] != null ? NewsletterMyResponse.fromJson(json['my_response'] as Map<String, dynamic>) : null,
      );

  final int id;
  final String subject;
  final String body;
  final String priority;
  final String? attachmentUrl;
  final List<NewsletterOption> options;
  final String publishedAt;
  final NewsletterMyResponse? myResponse;

  bool get responded => myResponse != null;
}
