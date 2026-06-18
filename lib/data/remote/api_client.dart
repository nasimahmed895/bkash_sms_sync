import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_logger.dart';
import '../../core/constants.dart';

/// Outcome of a webhook submission attempt.
sealed class WebhookResult {
  const WebhookResult();
}

/// 200 / success — payment accepted. Stop retrying.
class WebhookSuccess extends WebhookResult {
  final int backendId;
  const WebhookSuccess(this.backendId);
}

/// Backend responded with a definitive failure ("payment not found").
/// Stop retrying — backend handles failed payments.
class WebhookRejected extends WebhookResult {
  final String message;
  const WebhookRejected(this.message);
}

/// Transient problem (no network, DNS, timeout, 5xx without a body,
/// connection reset...). Keep status pending_sync and retry later.
class WebhookTransientError extends WebhookResult {
  final String reason;
  const WebhookTransientError(this.reason);
}

class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConstants.baseUrl,
              connectTimeout: AppConstants.connectTimeout,
              receiveTimeout: AppConstants.receiveTimeout,
              headers: {'Content-Type': 'application/json'},
              // We inspect status codes ourselves.
              validateStatus: (_) => true,
            )) {
    _dio.interceptors.add(LogInterceptor(
      requestBody: kDebugMode,
      responseBody: kDebugMode,
      logPrint: (o) => appLogger.d(o),
    ));
  }

  Map<String, String> _signedHeaders(String secret, String payload) {
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final sig = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode('$ts.$payload'))
        .toString();
    return {'X-Webhook-Timestamp': ts, 'X-Webhook-Signature': sig};
  }

  /// POST /webhook/verification-payment
  Future<WebhookResult> submitPayment(Map<String, dynamic> body) async {
    try {
      final bodyJson = jsonEncode(body);
      final secret = AppConstants.webhookSecret;
      final options = Options();
      if (secret.isNotEmpty) {
        options.headers = _signedHeaders(secret, bodyJson);
      }
      final res = await _dio.post(AppConstants.webhookPath, data: bodyJson, options: options);
      final data = res.data;
      final code = res.statusCode ?? 0;

      if (data is Map<String, dynamic>) {
        final status = data['status'];

        int? extractId() {
          final id = data['data']?['subscription_id'] ?? data['data']?['id'];
          if (id is int) return id;
          if (id is String) return int.tryParse(id);
          return null;
        }

        // Backend uses boolean status: {status: true/false, data: {...}}
        if (status == true || status == 'success') {
          final id = extractId();
          if (id != null) return WebhookSuccess(id);
          return const WebhookTransientError('success without backend id');
        }

        // 409 = trxID already processed — payment IS delivered, stop retrying.
        if (code == 409) {
          final id = extractId();
          if (id != null) return WebhookSuccess(id);
          return WebhookRejected(
              (data['message'] as String?) ?? 'already processed');
        }

        // Other definitive business failures (404 no match, 422 invalid) —
        // backend has logged the payment and owns reconciliation.
        if ((status == false || status == 'failed') &&
            code >= 400 &&
            code < 500) {
          return WebhookRejected(
              (data['message'] as String?) ?? 'payment rejected');
        }
      }
      return WebhookTransientError(
          'unexpected response (${res.statusCode})');
    } on DioException catch (e) {
      // Network unavailable / timeout / DNS failure / connection lost —
      // always treated as transient so the payment is never lost.
      return WebhookTransientError(e.type.name);
    } catch (e) {
      return WebhookTransientError(e.toString());
    }
  }

  /// GET /api/payment-list
  Future<Response> getPaymentList({int page = 1}) {
    final secret = AppConstants.webhookSecret;
    final options = Options();
    if (secret.isNotEmpty) {
      // Backend signs over getRequestUri() = path + query string.
      final uri = '${AppConstants.paymentListPath}?page=$page';
      options.headers = _signedHeaders(secret, uri);
    }
    return _dio.get(
      AppConstants.paymentListPath,
      queryParameters: {'page': page},
      options: options,
    );
  }
}
