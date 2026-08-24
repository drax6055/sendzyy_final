import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iFloraBuzz/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:convert';
import 'package:iFloraBuzz/features/credits/data/models/panel_plan.dart';
import 'package:iFloraBuzz/features/templates/data/models/app_entry.dart';
import 'package:iFloraBuzz/core/utils/snackbar_utils.dart';

class WhatsAppRepository {
  final Dio _dio;
  final SharedPreferences _prefs;

  WhatsAppRepository(this._dio, this._prefs);

  String? get _accessToken => _prefs.getString(AppConstants.keyAccessToken);
  String? get _phoneNumberId => _prefs.getString(AppConstants.keyPhoneNumberId);
  String? get _wabaId => _prefs.getString(AppConstants.keyWabaId);
  String? get _appId => _prefs.getString(AppConstants.keyAppId);

  // --- API Methods (Proxied through Node.js) ---

  Future<List<PanelPlan>> fetchPanelPlans() async {
    try {
      final response = await _dio.get('/panel-plans');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => PanelPlan.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch panel plans');
    } catch (e) {
      throw Exception('Error fetching panel plans: $e');
    }
  }

  /// Create a Razorpay order for a panel plan renewal (authenticated)
  Future<Map<String, dynamic>> createPanelOrder({required String planId}) async {
    final response = await _dio.post('/create-panel-order', data: {'planId': planId});
    if (response.statusCode == 200) return response.data as Map<String, dynamic>;
    throw Exception('Failed to create panel order');
  }

  /// Verify panel payment — only updates panel expiry, never touches credits
  Future<bool> verifyPanelPayment({
    required String planId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final response = await _dio.post('/verify-panel-payment', data: {
        'planId': planId,
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPaymentHistory() async {
    final response = await _dio.get('/payment-history');
    if (response.statusCode == 200) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to fetch payment history');
  }

  Future<List<dynamic>> fetchTemplates() async {
    try {
      final response = await _dio.get('/fetch-templates');

      if (response.statusCode == 200) {
        return response.data['data'] as List<dynamic>;
      } else {
        throw Exception('Failed to fetch templates: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Error fetching templates: $e');
    }
  }

  Future<String?> sendMessage({
    required String to,
    required String templateName,
    required String languageCode,
    String? mediaId,
    String? mediaType,
    String? campaignId,
    String? recipientName,          // client name stored in recipient doc for report display
    Map<int, String>? variables,       // body variables {1: 'John', 2: '+91...', 3: 'ABC Co.'}
    Map<int, String>? headerVariables, // header TEXT variables {1: 'value'}
  }) async {
    try {
      // Build body component parameters from variables map
      final List<Map<String, dynamic>> bodyParams = [];
      if (variables != null && variables.isNotEmpty) {
        final sortedKeys = variables.keys.toList()..sort();
        for (final key in sortedKeys) {
          bodyParams.add({'type': 'text', 'text': variables[key] ?? ''});
        }
      }

      final List<Map<String, dynamic>> components = [];

      // Header component — media takes priority over text variables
      if (mediaId != null && mediaType != null) {
        components.add({
          'type': 'header',
          'parameters': [
            {
              'type': mediaType.toLowerCase(),
              mediaType.toLowerCase(): {'id': mediaId},
            }
          ],
        });
      } else if (headerVariables != null && headerVariables.isNotEmpty) {
        // TEXT header with {{n}} variables
        final sortedHeaderKeys = headerVariables.keys.toList()..sort();
        final headerParams = sortedHeaderKeys
            .map((k) => {'type': 'text', 'text': headerVariables[k] ?? ''})
            .toList();
        components.add({'type': 'header', 'parameters': headerParams});
      }

      // Body component (variables)
      if (bodyParams.isNotEmpty) {
        components.add({'type': 'body', 'parameters': bodyParams});
      }

      final response = await _dio.post(
        '/send-message',
        data: {
          'to': to,
          'type': 'template',
          'campaignId': campaignId,
          if (recipientName != null && recipientName.isNotEmpty)
            'recipientName': recipientName,
          'template': {
            'name': templateName,
            'language': {'code': languageCode},
            if (components.isNotEmpty) 'components': components,
          },
        },
      );

      if (response.statusCode == 200) {
        return response.data['wamid'] as String;
      }
      return null;
    } catch (e) {
      String errorMessage = 'Failed to send message: $e';
      if (e is DioException) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        } else if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (e.message != null && e.message!.isNotEmpty) {
          errorMessage = e.message!;
        }
      }
      throw Exception(errorMessage);
    }
  }

  Future<String?> sendFreeFormMessage({
    required String to,
    required String text,
    String? replyToMessageId,
    String? replyToWamid,
  }) async {
    try {
      final response = await _dio.post(
        '/send-message',
        data: {
          'to': to,
          'type': 'text',
          'text': text,
          if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
          if (replyToWamid != null) 'replyToWamid': replyToWamid,
        },
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return data['wamid']?.toString() ?? data['id']?.toString();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> sendDirectMediaMessage({
    required String to,
    required String mediaId,
    required String type, // 'image' | 'video' | 'audio' | 'document'
    String? filename,     // optional filename for document
    String? replyToMessageId,
    String? replyToWamid,
  }) async {
    try {
      final response = await _dio.post(
        '/send-message',
        data: {
          'to': to,
          'type': type,
          'mediaId': mediaId,
          if (filename != null) 'text': filename,
          if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
          if (replyToWamid != null) 'replyToWamid': replyToWamid,
        },
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return data['wamid']?.toString() ?? data['id']?.toString();
        }
      }
      return null;
    } catch (e) {
      final errorMessage = parseErrorMessage(e, 'Failed to send direct media message');
      showGlobalSnackBar(errorMessage);
      return null;
    }
  }

  /// Sends a test OTP via an AUTHENTICATION template.
  /// Returns true on success, false on failure.
  Future<bool> sendOtp({
    required String to,
    required String templateName,
    required String languageCode,
  }) async {
    try {
      final response = await _dio.post(
        '/send-otp',
        data: {'to': to, 'templateName': templateName, 'languageCode': languageCode},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      final errorMessage = parseErrorMessage(e, 'Failed to send OTP');
      showGlobalSnackBar(errorMessage);
      return false;
    }
  }

  /// Verifies the OTP entered by the user.
  /// Returns null on success, or an error message string on failure.
  Future<String?> verifyOtp({
    required String to,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        '/verify-otp',
        data: {'to': to, 'otp': otp},
      );
      if (response.statusCode == 200 && response.data['success'] == true) return null;
      return response.data['error'] ?? 'Verification failed.';
    } catch (e) {
      // Extract server error message if available
      if (e is DioException && e.response?.data != null) {
        return e.response!.data['error'] ?? 'Verification failed.';
      }
      return 'Verification failed.';
    }
  }

  Future<bool> createTemplate({
    required String name,
    required String category,
    String? subCategory,
    required String language,
    String? header,
    String? mediaSample,
    String? variableType,
    required String body,
    String? footer,
    List<Map<String, dynamic>>? buttons,
    PlatformFile? mediaFile,
    // validity period (UTILITY + AUTHENTICATION)
    int? messageSendTtlSeconds,
    // auth-specific (AUTHENTICATION only)
    String? codeDeliveryType,
    List<dynamic>? appEntries,
    bool? addSecurityRecommendation,
    bool? addExpiryTime,
    int? codeExpirationMinutes,
    bool? zeroTapTosAccepted,
  }) async {
    if (_accessToken == null || _wabaId == null) {
      throw Exception('API Credentials not configured');
    }

    try {
      // --- AUTHENTICATION branch ---
      if (category == 'AUTHENTICATION') {
        final otpButton = <String, dynamic>{
          'type': 'OTP',
          'otp_type': codeDeliveryType ?? 'COPY_CODE',
        };

        // ZERO_TAP requires zero_tap_terms_accepted: true
        if (codeDeliveryType == 'ZERO_TAP') {
          otpButton['zero_tap_terms_accepted'] = zeroTapTosAccepted ?? true;
        }

        // Include supported_apps for ZERO_TAP and ONE_TAP
        if ((codeDeliveryType == 'ZERO_TAP' || codeDeliveryType == 'ONE_TAP') &&
            appEntries != null &&
            appEntries.isNotEmpty) {
          otpButton['supported_apps'] = appEntries.map((e) {
            final entry = e as AppEntry;
            return {
              'package_name': entry.packageName,
              'signature_hash': entry.signatureHash,
            };
          }).toList();
        }

        final components = <Map<String, dynamic>>[
          {
            'type': 'BODY',
            'add_security_recommendation': addSecurityRecommendation ?? false,
          },
          // code_expiration_minutes belongs on the FOOTER component per Meta API
          if (addExpiryTime == true && codeExpirationMinutes != null)
            {
              'type': 'FOOTER',
              'code_expiration_minutes': codeExpirationMinutes,
            },
          {
            'type': 'BUTTONS',
            'buttons': [otpButton],
          },
        ];

        final authPayload = <String, dynamic>{
          'name': name,
          'category': category,
          'language': language,
          'components': components,
        };

        if (messageSendTtlSeconds != null) {
          authPayload['message_send_ttl_seconds'] = messageSendTtlSeconds;
        }

    

        final authResponse = await _dio.post('/create-template', data: authPayload);
        return authResponse.statusCode == 200;
      }
      // --- END AUTHENTICATION branch ---

      // Sanitize header (Meta doesn't allow emojis, asterisks, etc. in template headers)
      final sanitizedHeader = header != null
          ? _sanitizeHeaderText(header)
          : null;

      final payload = <String, dynamic>{
        'name': name,
        'category': category,
        'language': language,
        if (messageSendTtlSeconds != null) 'message_send_ttl_seconds': messageSendTtlSeconds,
        'components': [
          if (mediaSample != null && mediaSample != 'NONE')
            {
              'type': 'HEADER',
              'format': mediaSample.toUpperCase() == 'DOCUMENT'
                  ? 'DOCUMENT'
                  : (mediaSample.toUpperCase() == 'VIDEO' ? 'VIDEO' : 'IMAGE'),
              if (mediaFile != null)
                'example': {
                  'header_handle': [await _getTemplateMediaHandle(mediaFile)],
                },
            }
          else if (sanitizedHeader != null && sanitizedHeader.isNotEmpty)
            {
              'type': 'HEADER',
              'format': 'TEXT',
              'text': sanitizedHeader,
              if (sanitizedHeader.contains('{{'))
                'example': {
                  'header_text': ['Sample Header'],
                },
            },
          {
            'type': 'BODY',
            'text': body,
            if (body.contains('{{'))
              'example': {
                'body_text': [
                  List.generate(
                    _getMaxVariableIndex(body),
                    (index) => 'Sample ${index + 1}',
                  ),
                ],
              },
          },
          if (footer != null && footer.isNotEmpty)
            {'type': 'FOOTER', 'text': footer},
          if (buttons != null && buttons.isNotEmpty)
            {
              'type': 'BUTTONS',
              'buttons': buttons.map((btn) {
                final type = btn['type'];
                if (type == 'QUICK_REPLY') {
                  return {'type': 'QUICK_REPLY', 'text': btn['text']};
                } else if (type == 'PHONE_NUMBER') {
                  return {
                    'type': 'PHONE_NUMBER',
                    'text': btn['text'],
                    'phone_number': btn['phone_number'],
                  };
                } else if (type == 'URL') {
                  return {
                    'type': 'URL',
                    'text': btn['text'],
                    'url': btn['url'],
                  };
                }
                return btn;
              }).toList(),
            },
        ],
      };

  

      final response = await _dio.post('/create-template', data: payload);

      return response.statusCode == 200;
    } on DioException catch (e) {
      final errorData = e.response?.data;
      
      String errorMessage = 'Error creating template';

      if (errorData is Map) {
        final details = errorData['details'];
        if (details is Map && details['error'] is Map) {
          final metaError = details['error'] as Map;
          errorMessage = metaError['error_user_msg'] ?? 
                        metaError['error_user_title'] ?? 
                        metaError['message'] ?? 
                        errorMessage;
        } else if (errorData['error'] is Map) {
          errorMessage = errorData['error']['message'] ?? errorMessage;
        } else if (errorData['error'] is String) {
          errorMessage = errorData['error'];
        }
      } else {
        errorMessage = e.message ?? errorMessage;
      }
      throw errorMessage;
    } catch (e) {
      final errorMessage = parseErrorMessage(e, 'Error creating template');
      showGlobalSnackBar(errorMessage);
      throw errorMessage;
    }
  }

  String _sanitizeHeaderText(String text) {
    return text
        .replaceAll(
          RegExp(
            r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
            unicode: true,
          ),
          '',
        )
        .replaceAll('*', '')
        .replaceAll('_', '')
        .replaceAll('~', '')
        .replaceAll('`', '')
        .trim();
  }

  Future<String> uploadMedia(PlatformFile file) async {
    if (_accessToken == null || _phoneNumberId == null) {
      throw Exception('API Credentials not configured');
    }

    try {
      final uploadDio = Dio();
      final authToken = _prefs.getString('auth_token');
      final proxyUrl = '${AppConstants.baseUrl}/media-upload';

      final dynamic fileData;
      if (file.bytes != null) {
        fileData = file.bytes;
      } else if (!kIsWeb && file.path != null) {
        fileData = await File(file.path!).readAsBytes();
      } else {
        throw Exception(
          'File data is unavailable. Please ensure withData: true is set in the file picker.',
        );
      }

      final response = await uploadDio.post(
        proxyUrl,
        data: fileData,
        queryParameters: {
          'phoneNumberId': _phoneNumberId,
          'accessToken': _accessToken,
          'fileName': file.name,
          'fileType': _getMimeType(file),
        },
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['id'] != null) {
        return response.data['id'] as String;
      } else {
        throw Exception(
          'Media upload failed: ${response.data['error'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      if (e is DioException) {
        final resp = e.response;
        if (resp != null) {
          final data = resp.data;
          String? message;
          if (data is Map) {
            final errorData = data['error'];
            if (errorData is Map) {
              final details = errorData['details'];
              if (details != null) {
                if (details is Map && details['error'] != null && details['error']['message'] != null) {
                  message = details['error']['message'].toString();
                } else {
                  message = details.toString();
                }
              } else {
                message = errorData['message']?.toString();
              }
            } else if (errorData is String) {
              message = errorData;
            }
          } else if (data is String) {
            message = data;
          }
          message ??= e.message;
          throw Exception('Media Upload API Error: $message');
        }
      }
      throw Exception('Error uploading media: $e');
    }
  }

  Future<String> _getTemplateMediaHandle(PlatformFile file) async {
    if (_accessToken == null) throw Exception('Access token not set');
    if (_appId == null || _appId!.isEmpty) {
      throw Exception(
        'Meta App ID is required for media templates. Please configure it in API Configuration.',
      );
    }

    try {
      final uploadDio = Dio();
      final authToken = _prefs.getString('auth_token');

      // --- WEB PROXY LOGIC ---
      if (kIsWeb) {
        final proxyUrl = '${AppConstants.baseUrl}/upload-media';

        final dynamic fileData;
        if (file.bytes != null) {
          fileData = file.bytes;
        } else {
          throw Exception(
            'File data is unavailable. Please ensure withData: true is set in the file picker.',
          );
        }

        final response = await uploadDio.post(
          proxyUrl,
          data: fileData,
          queryParameters: {
            'name': file.name,
            'size': file.size,
            'type': _getMimeType(file),
            'accessToken': _accessToken,
            'appId': _appId,
          },
          options: Options(
            headers: {
              'Content-Type': 'application/octet-stream',
              if (authToken != null) 'Authorization': 'Bearer $authToken',
            },
          ),
        );

        if (response.statusCode == 200) {
          return response.data['h'] as String;
        } else {
          throw Exception(
            'Proxy upload failed: ${response.data['error'] ?? 'Unknown error'}',
          );
        }
      }
      // --- END WEB PROXY LOGIC ---

      // Non-web platforms: Initialize and upload directly
      final baseUrl = AppConstants.baseUrl;
      final initResponse = await uploadDio.post(
        '$baseUrl/$_appId/uploads',
        queryParameters: {
          'file_name': file.name,
          'file_length': file.size,
          'file_type': _getMimeType(file),
          'access_token': _accessToken,
        },
        options: Options(
          headers: {'Content-Type': 'text/plain', 'Accept': '*/*'},
        ),
      );

      final sessionId = initResponse.data['id'] as String;
      final List<int> fileData;
      if (file.bytes != null) {
        fileData = file.bytes!;
      } else if (!kIsWeb && file.path != null) {
        fileData = await File(file.path!).readAsBytes();
      } else {
        throw Exception('File data unavailable');
      }

      final uploadResponse = await uploadDio.post(
        '$baseUrl/$sessionId',
        data: fileData,
        queryParameters: {'access_token': _accessToken, 'file_offset': '0'},
        options: Options(
          headers: {'Content-Type': 'text/plain', 'Accept': '*/*'},
        ),
      );

      return uploadResponse.data['h'] as String;
    } catch (e) {
      if (e is DioException) {
        final resp = e.response;
        if (resp != null) {
       
          final data = resp.data;
          String? message;

          if (data is Map) {
            final errorData = data['error'];
            if (errorData is Map) {
              message = errorData['message'];
            } else if (errorData is String) {
              message = errorData;
            }
          } else if (data is String) {
            // Handle plain text errors like "Unauthorized"
            message = data;
          }

          message ??= e.message;
          throw Exception('Meta Upload API Error: $message');
        }
      }
      throw Exception('Error getting template media handle: $e');
    }
  }

  String _getMimeType(PlatformFile file) {
    String? ext = file.extension?.toLowerCase();
    if (ext == null || ext.isEmpty) {
      final parts = file.name.split('.');
      if (parts.length > 1) {
        ext = parts.last.toLowerCase();
      }
    }
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case '3gp':
        return 'video/3gpp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      case 'rtf':
        return 'application/rtf';
      case 'zip':
        return 'application/zip';
      case 'mp3':
        return 'audio/mpeg';
      case 'aac':
        return 'audio/aac';
      case 'amr':
        return 'audio/amr';
      case 'ogg':
        return 'audio/ogg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  Future<bool> deleteTemplate(String name) async {
    try {
      final response = await _dio.delete(
        '/delete-template',
        queryParameters: {'name': name},
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error deleting template: $e');
    }
  }

  // --- Persistence Methods ---

  String? _cachedTenantId;
  String? get tenantId => _cachedTenantId ?? _prefs.getString('tenant_id');
  String? get _tenantId => tenantId;

  Future<void> saveCampaign(Map<String, dynamic> campaign) async {
    if (_tenantId == null) return;
    await _dio.post('/campaigns', data: campaign);
  }

  Future<List<Map<String, dynamic>>> getCampaigns() async {
    try {
      final response = await _dio.get('/campaigns');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final response = await _dio.get('/conversations');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getMessages(String contactId) async {
    try {
      final response = await _dio.get('/conversations/$contactId/messages');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  /// Returns the full proxy URL for a WhatsApp media file.
  /// The [mediaId] is the Meta media ID stored in the message's mediaUrl field.
  String getMediaUrl(String mediaId) => '${AppConstants.baseUrl}/media/$mediaId';

  /// Returns the current JWT auth token, used for authenticated image requests.
  String? get authToken => _prefs.getString('auth_token');

  Stream<List<Map<String, dynamic>>> getCampaignsStream() {
    // Campaigns are pushed via Socket.IO (campaigns_update event)
    // This stream is subscribed in ReportBloc via SocketService
    return const Stream.empty();
  }

  Future<List<Map<String, dynamic>>> getCampaignRecipients(String campaignId) async {
    if (_tenantId == null) return [];
    try {
      final response = await _dio.get('/campaigns/$campaignId/recipients');
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        } else if (response.data is Map) {
          final dataMap = Map<String, dynamic>.from(response.data as Map);
          final recipientsList = dataMap['recipients'] as List? ?? [];
          final templateButtons = dataMap['templateButtons'] as List? ?? [];
          final list = recipientsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          for (var r in list) {
            r['_templateButtons'] = templateButtons;
          }
          return list;
        }

      }
    } catch (_) {}
    return [];
  }

  Future<void> saveMessageStatusMapping(String wamid, String campaignId) async {
    await _dio.post('/status-mappings', data: {
      'wamid': wamid,
      'campaignId': campaignId,
    });
  }

  Future<bool> updateConfig({
    required String phoneNumberId,
    required String accessToken,
    required String businessAccountId,
    required String metaAppId,
    String? displayPhone,
    String? verifiedName,
    String? qualityRating,
    String? throughputLevel,
  }) async {
    try {
      final response = await _dio.post(
        '/update-config',
        data: {
          'phoneNumberId': phoneNumberId,
          'accessToken': accessToken,
          'businessAccountId': businessAccountId,
          'metaAppId': metaAppId,
          if (displayPhone != null) 'displayPhone': displayPhone,
          if (verifiedName != null) 'verifiedName': verifiedName,
          if (qualityRating != null) 'qualityRating': qualityRating,
          if (throughputLevel != null) 'throughputLevel': throughputLevel,
        },
      );
      if (response.statusCode == 200) {
        // Update cached tenant_data so AuthBloc reflects the new config immediately
        final tenantJson = _prefs.getString('tenant_data');
        if (tenantJson != null) {
          final tenant = jsonDecode(tenantJson) as Map<String, dynamic>;
          final config = Map<String, dynamic>.from(
            (tenant['whatsappConfig'] as Map<String, dynamic>?) ?? {},
          );
          config['phoneNumberId'] = phoneNumberId;
          config['accessToken'] = accessToken;
          config['businessAccountId'] = businessAccountId;
          config['metaAppId'] = metaAppId;
          config['verified'] = true;
          if (displayPhone != null) config['displayPhone'] = displayPhone;
          if (verifiedName != null) config['verifiedName'] = verifiedName;
          if (qualityRating != null) config['qualityRating'] = qualityRating;
          if (throughputLevel != null) config['throughputLevel'] = throughputLevel;
          tenant['whatsappConfig'] = config;
          await _prefs.setString('tenant_data', jsonEncode(tenant));
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> facebookEmbeddedSignup({
    required String code,
    required String appId,
    String? wabaId,
    String? phoneNumberId,
    String? sessionId,
    String? sessionInfoResponse,
    String? businessPortfolioId, // Step 3 — Business Portfolio ID for official token exchange
  }) async {
    try {
      final response = await _dio.post(
        '/facebook-embedded-signup',
        data: {
          'code': code,
          'appId': appId,
          if (wabaId != null) 'wabaId': wabaId,
          if (phoneNumberId != null) 'phoneNumberId': phoneNumberId,
          if (sessionId != null) 'sessionId': sessionId,
          if (sessionInfoResponse != null) 'sessionInfoResponse': sessionInfoResponse,
          if (businessPortfolioId != null) 'businessPortfolioId': businessPortfolioId,
        },
      );
      if (response.statusCode == 200) {
        // Returns { success, config: { wabaId, phoneNumberId, displayPhone, verifiedName, qualityRating, throughputLevel, verified } }
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> registerPhoneNumber({String? pin}) async {
    try {
      final response = await _dio.post(
        '/api/whatsapp/register-phone',
        data: {
          if (pin != null && pin.isNotEmpty) 'pin': pin,
        },
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        return e.response?.data as Map<String, dynamic>;
      }
      return {'error': e.toString()};
    }
  }

  Future<void> logSignupEvent({
    required String eventName,
    String? sessionId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _dio.post(
        '/log-signup-event',
        data: {
          'eventName': eventName,
          if (sessionId != null) 'sessionId': sessionId,
          if (data != null) 'data': data,
        },
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/me');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Sync API configurations to SharedPreferences for local workflows
        final config = data['whatsappConfig'] ?? {};
        if (config['accessToken'] != null) {
          await _prefs.setString(
            AppConstants.keyAccessToken,
            config['accessToken'],
          );
        }
        if (config['phoneNumberId'] != null) {
          await _prefs.setString(
            AppConstants.keyPhoneNumberId,
            config['phoneNumberId'],
          );
        }
        if (config['businessAccountId'] != null) {
          await _prefs.setString(
            AppConstants.keyWabaId,
            config['businessAccountId'],
          );
        }
        if (config['metaAppId'] != null) {
          await _prefs.setString(AppConstants.keyAppId, config['metaAppId']);
        }

        return data;
      }
      throw Exception('Failed to fetch profile');
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  Future<Map<String, dynamic>> scheduleCampaign({
    required String campaignName,
    required String template,
    required String language,
    required List<Map<String, dynamic>> recipients,
    required DateTime scheduledAt,
    String? mediaId,
    String? mediaType,
  }) async {
    final response = await _dio.post('/scheduled-campaigns', data: {
      'campaignName': campaignName,
      'template': template,
      'language': language,
      'recipients': recipients,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      if (mediaId != null) 'mediaId': mediaId,
      if (mediaType != null) 'mediaType': mediaType,
    });
    return Map<String, dynamic>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> fetchScheduledCampaigns() async {
    try {
      final response = await _dio.get('/scheduled-campaigns');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    return [];
  }

  Future<void> completePhase1(String campaignId) async {
    try {
      await _dio.post('/api/campaigns/$campaignId/complete-phase1');
    } catch (e) {
      // Non-fatal — log but don't crash the campaign result
    }
  }

  Future<bool> cancelScheduledCampaign(String id) async {
    try {
      final response = await _dio.delete('/scheduled-campaigns/$id');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post('/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    if (response.statusCode != 200) {
      throw Exception(response.data['error'] ?? 'Failed to change password');
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final response = await _dio.post('/forgot-password', data: {'email': email});
      if (response.statusCode != 200) {
        throw Exception(response.data['error'] ?? 'Failed to send reset email');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Failed to send reset email';
      throw Exception(msg);
    }
  }

  Future<List<Map<String, dynamic>>?> fetchPhoneNumbers({
    required String wabaId,
    required String accessToken,
  }) async {
    try {
      final dio = Dio(); // Use a clean Dio instance to avoid custom application headers
      final response = await dio.get(
        '${AppConstants.metaGraphUrl}/$wabaId/phone_numbers',
        queryParameters: {
          'fields': 'id,display_phone_number,verified_name,code_verification_status,quality_rating,platform_type,throughput,webhook_configuration',
          'access_token': accessToken,
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchWhatsAppProfile({
    required String phoneNumberId,
    required String accessToken,
  }) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '${AppConstants.metaGraphUrl}/$phoneNumberId/whatsapp_business_profile',
        queryParameters: {
          'fields': 'about,address,description,email,profile_picture_url,websites,vertical',
          'access_token': accessToken,
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        if (data.isNotEmpty) {
          return Map<String, dynamic>.from(data.first);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateWhatsAppProfileText({
    required String phoneNumberId,
    required String accessToken,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final dio = Dio();
      final response = await dio.post(
        '${AppConstants.metaGraphUrl}/$phoneNumberId/whatsapp_business_profile',
        queryParameters: {
          'access_token': accessToken,
        },
        data: {
          'messaging_product': 'whatsapp',
          ...profileData,
        },
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final errorData = data['error'];
        if (errorData is Map && errorData['message'] != null) {
          throw Exception(errorData['message'].toString());
        }
      } else if (data is String) {
        throw Exception(data);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> uploadWhatsAppProfileImage({
    required String phoneNumberId,
    required String accessToken,
    required List<int> imageBytes,
    required String fileName,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final dio = Dio();
      final binaryData = Uint8List.fromList(imageBytes);

      // Step 1: Create Resumable Upload Session
      final sessionResponse = await dio.post(
        '${AppConstants.metaGraphUrl}/app/uploads',
        queryParameters: {
          'file_length': binaryData.length.toString(),
          'file_type': mimeType,
          'file_name': fileName,
          'access_token': accessToken,
        },
      );

      if (sessionResponse.statusCode != 200) return null;
      final uploadId = sessionResponse.data['id']?.toString();
      if (uploadId == null) return null;

      // Step 2: Upload Binary Data to Meta
      final uploadResponse = await dio.post(
        '${AppConstants.metaGraphUrl}/$uploadId',
        data: binaryData,
        queryParameters: {
          'access_token': accessToken,
        },
        options: Options(
          headers: {
            'file_offset': '0',
            'Content-Type': 'application/octet-stream',
          },
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress(sent / total);
          }
        },
      );

      if (uploadResponse.statusCode != 200) return null;
      final handleId = uploadResponse.data['h']?.toString() ?? uploadId;

      // Step 3: Attach profile picture handle to profile
      final attachResponse = await dio.post(
        '${AppConstants.metaGraphUrl}/$phoneNumberId/whatsapp_business_profile',
        queryParameters: {
          'access_token': accessToken,
        },
        data: {
          'messaging_product': 'whatsapp',
          'profile_picture_handle': handleId,
        },
      );

      if (attachResponse.statusCode == 200 && attachResponse.data['success'] == true) {
        return handleId;
      }
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final errorVal = data['error'];
        if (errorVal is Map && errorVal['message'] != null) {
          throw Exception(errorVal['message'].toString());
        }
      } else if (data is String) {
        throw Exception(data);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  int _getMaxVariableIndex(String text) {
    final matches = RegExp(r'\{\{(\d+)\}\}').allMatches(text);
    if (matches.isEmpty) return 0;
    int maxIndex = 0;
    for (final m in matches) {
      final idx = int.tryParse(m.group(1) ?? '') ?? 0;
      if (idx > maxIndex) maxIndex = idx;
    }
    return maxIndex > 0 ? maxIndex : matches.length;
  }
}

