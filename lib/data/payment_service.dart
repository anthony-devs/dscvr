import 'dart:convert';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/subscription.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Handles Google Pay payment verification and subscription management
/// through the dedicated DSCVR Flask server.
class PaymentService {
  PaymentService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, String>> _authHeaders() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Not signed in');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Verify a Google Pay payment token and activate the subscription.
  ///
  /// [paymentToken] is the raw token data from the Google Pay SDK.
  /// Returns the activated subscription details.
  Future<Map<String, dynamic>> verifyAndActivate({
    required String tier,
    required String interval,
    required Map<String, dynamic> paymentToken,
  }) async {
    final headers = await _authHeaders();
    final resp = await _client.post(
      Uri.parse('${Env.serverUrl}/payments/verify'),
      headers: headers,
      body: jsonEncode({
        'tier': tier,
        'interval': interval,
        'paymentToken': paymentToken,
      }),
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(data['error'] ?? 'Payment failed');
    }
    return data;
  }

  /// Cancel the current subscription at period end.
  Future<void> cancelSubscription() async {
    final headers = await _authHeaders();
    final resp = await _client.post(
      Uri.parse('${Env.serverUrl}/payments/cancel'),
      headers: headers,
    );

    if (resp.statusCode != 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Cancellation failed');
    }
  }

  /// Get the current subscription status from the server.
  Future<Subscription> getStatus() async {
    final headers = await _authHeaders();
    final resp = await _client.get(
      Uri.parse('${Env.serverUrl}/payments/status'),
      headers: headers,
    );

    if (resp.statusCode != 200) {
      throw Exception('Could not fetch subscription status');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return Subscription.fromMap(data['subscription'] as Map<String, dynamic>);
  }

  /// Build the Google Pay payment configuration for the `pay` package.
  ///
  /// This returns the configuration map that the Pay button widget expects.
  static Map<String, dynamic> googlePayConfig({
    required String tier,
    required BillingInterval interval,
  }) {
    final plan = PlanPricing.plans.firstWhere((p) => p.tier.name == tier);
    final price = plan.price(interval);

    return {
      'provider': 'google_pay',
      'data': {
        'environment': 'TEST', // Change to 'PRODUCTION' when live
        'apiVersion': 2,
        'apiVersionMinor': 0,
        'allowedPaymentMethods': [
          {
            'type': 'CARD',
            'parameters': {
              'allowedAuthMethods': ['PAN_ONLY', 'CRYPTOGRAM_3DS'],
              'allowedCardNetworks': ['VISA', 'MASTERCARD', 'AMEX', 'DISCOVER'],
            },
            'tokenizationSpecification': {
              'type': 'PAYMENT_GATEWAY',
              'parameters': {
                'gateway': 'example', // Replace with your gateway
                'gatewayMerchantId': Env.googlePayMerchantId,
              },
            },
          },
        ],
        'merchantInfo': {
          'merchantId': Env.googlePayMerchantId,
          'merchantName': 'DSCVR Research',
        },
        'transactionInfo': {
          'totalPriceStatus': 'FINAL',
          'totalPrice': price.toStringAsFixed(2),
          'currencyCode': 'USD',
          'countryCode': 'US',
          'totalPriceLabel': 'DSCVR ${tier[0].toUpperCase()}${tier.substring(1)} — ${interval.label}',
        },
      },
    };
  }
}
