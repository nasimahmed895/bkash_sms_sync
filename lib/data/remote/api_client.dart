import 'package:dio/dio.dart';

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
      requestBody: true,
      responseBody: true,
      logPrint: (o) => appLogger.d(o),
    ));
  }

  /// POST /webhook/verification-payment
  Future<WebhookResult> submitPayment(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post(AppConstants.webhookPath, data: body);
      final data = res.data;

      if (data is Map<String, dynamic>) {
        final status = data['status'];
        if (status == 'success') {
          final id = data['data']?['id'];
          if (id is int) return WebhookSuccess(id);
          if (id is String) {
            final parsed = int.tryParse(id);
            if (parsed != null) return WebhookSuccess(parsed);
          }
          return const WebhookTransientError('success without backend id');
        }
        if (status == 'failed') {
          // Definitive business failure from backend — stop retrying.
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
    return _dio.get(
      AppConstants.paymentListPath,
      queryParameters: {'page': page},
    );
  }
}
