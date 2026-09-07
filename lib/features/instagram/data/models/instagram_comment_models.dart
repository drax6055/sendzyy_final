class InstagramMediaItem {
  final String id;
  final String caption;
  final String mediaType;
  final String mediaProductType;
  final String mediaUrl;
  final String thumbnailUrl;
  final String permalink;
  final String timestamp;

  InstagramMediaItem({
    required this.id,
    this.caption = '',
    this.mediaType = '',
    this.mediaProductType = '',
    this.mediaUrl = '',
    this.thumbnailUrl = '',
    this.permalink = '',
    this.timestamp = '',
  });

  String get displayImageUrl =>
      thumbnailUrl.isNotEmpty ? thumbnailUrl : mediaUrl;

  bool get isReel =>
      mediaProductType.toUpperCase() == 'REELS' ||
      mediaType.toUpperCase() == 'VIDEO';

  factory InstagramMediaItem.fromJson(Map<String, dynamic> json) {
    return InstagramMediaItem(
      id: json['id']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? json['mediaType']?.toString() ?? '',
      mediaProductType: json['media_product_type']?.toString() ??
          json['mediaProductType']?.toString() ??
          '',
      mediaUrl: json['media_url']?.toString() ?? json['mediaUrl']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ??
          json['thumbnailUrl']?.toString() ??
          '',
      permalink: json['permalink']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'caption': caption,
        'mediaType': mediaType,
        'mediaProductType': mediaProductType,
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumbnailUrl,
        'permalink': permalink,
        'timestamp': timestamp,
      };
}

class InstagramCommentAutomation {
  final String id;
  final String name;
  final String postSelectionType; // 'all' | 'specific'
  final List<InstagramMediaItem> selectedMedia;
  final String triggerType; // 'all' | 'keyword'
  final List<String> triggerKeywords;
  final bool sendPublicReply;
  final String publicReplyMessage;
  final bool sendPrivateDm;
  final String privateDmMessage;
  final bool isActive;
  final DateTime createdAt;

  InstagramCommentAutomation({
    required this.id,
    required this.name,
    this.postSelectionType = 'all',
    this.selectedMedia = const [],
    this.triggerType = 'keyword',
    this.triggerKeywords = const [],
    this.sendPublicReply = true,
    this.publicReplyMessage = '',
    this.sendPrivateDm = true,
    required this.privateDmMessage,
    this.isActive = true,
    required this.createdAt,
  });

  factory InstagramCommentAutomation.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['selectedMedia'] as List? ?? [];
    final mediaList = rawMedia.map((m) {
      if (m is Map) {
        return InstagramMediaItem.fromJson(Map<String, dynamic>.from(m));
      }
      return InstagramMediaItem(id: m.toString());
    }).toList();

    return InstagramCommentAutomation(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Automation',
      postSelectionType: json['postSelectionType']?.toString() ?? 'all',
      selectedMedia: mediaList,
      triggerType: json['triggerType']?.toString() ?? 'keyword',
      triggerKeywords: (json['triggerKeywords'] as List? ?? [])
          .map((k) => k.toString())
          .toList(),
      sendPublicReply: json['sendPublicReply'] as bool? ?? true,
      publicReplyMessage: json['publicReplyMessage']?.toString() ?? '',
      sendPrivateDm: json['sendPrivateDm'] as bool? ?? true,
      privateDmMessage: json['privateDmMessage']?.toString() ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'postSelectionType': postSelectionType,
        'selectedMedia': selectedMedia.map((m) => m.toJson()).toList(),
        'triggerType': triggerType,
        'triggerKeywords': triggerKeywords,
        'sendPublicReply': sendPublicReply,
        'publicReplyMessage': publicReplyMessage.trim(),
        'sendPrivateDm': sendPrivateDm,
        'privateDmMessage': privateDmMessage.trim(),
        'isActive': isActive,
      };
}
