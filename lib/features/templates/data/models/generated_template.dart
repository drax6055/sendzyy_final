class GeneratedTemplate {
  final String body;
  final String? header;
  final String? footer;

  const GeneratedTemplate({
    required this.body,
    this.header,
    this.footer,
  });

  factory GeneratedTemplate.fromJson(Map<String, dynamic> json) => GeneratedTemplate(
        body: json['body'] as String,
        header: json['header'] as String?,
        footer: json['footer'] as String?,
      );
}
