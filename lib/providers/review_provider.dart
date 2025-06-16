import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

class ReviewState {
  final bool isSubmitting;
  final String? errorMessage;
  final bool submitSuccess;

  const ReviewState({
    this.isSubmitting = false,
    this.errorMessage,
    this.submitSuccess = false,
  });

  ReviewState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool? submitSuccess,
  }) {
    return ReviewState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      submitSuccess: submitSuccess ?? this.submitSuccess,
    );
  }
}

class ReviewNotifier extends StateNotifier<ReviewState> {
  final Ref _ref;
  bool _disposed = false;

  ReviewNotifier(this._ref) : super(const ReviewState());

  void _safeUpdateState(ReviewState Function(ReviewState) updater) {
    if (!_disposed && mounted) {
      try {
        state = updater(state);
      } catch (e) {
        debugPrint('Error updating review state: $e');
      }
    }
  }

  Future<bool> submitReview({
    required int providerId,
    required int bookingId,
    required int rating,
    required String comment,
    required List<String> tags,
  }) async {
    if (_disposed) return false;

    _safeUpdateState((state) => state.copyWith(
      isSubmitting: true,
      clearError: true,
      submitSuccess: false,
    ));

    try {
      final loginState = _ref.read(loginProvider);
      if (loginState.user.token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${loginState.user.token}',
      };

      final reviewData = {
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment.isNotEmpty ? comment : null,
        'tags': tags.isNotEmpty ? tags : null,
      };

      // FIXED: Removed the duplicate /api/ prefix
      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/providers/$providerId/reviews');

      debugPrint('Submitting review to: $uri');
      debugPrint('Review data: ${json.encode(reviewData)}');

      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode(reviewData),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (_disposed) return false;

      debugPrint('Submit review response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _safeUpdateState((state) => state.copyWith(
          isSubmitting: false,
          submitSuccess: true,
        ));
        return true;
      } else {
        String errorMessage = 'Failed to submit review';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        }

        _safeUpdateState((state) => state.copyWith(
          isSubmitting: false,
          errorMessage: errorMessage,
        ));
        return false;
      }
    } catch (e) {
      if (!_disposed) {
        debugPrint('Error submitting review: $e');
        _safeUpdateState((state) => state.copyWith(
          isSubmitting: false,
          errorMessage: 'Error: ${e.toString()}',
        ));
      }
      return false;
    }
  }

  void clearState() {
    _safeUpdateState((state) => const ReviewState());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// Provider for review notifier
final reviewProvider = StateNotifierProvider<ReviewNotifier, ReviewState>((ref) {
  return ReviewNotifier(ref);
});