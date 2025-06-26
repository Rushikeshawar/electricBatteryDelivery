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
  final bool isCheckingStatus;

  const ReviewState({
    this.isSubmitting = false,
    this.errorMessage,
    this.submitSuccess = false,
    this.isCheckingStatus = false,
  });

  ReviewState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool? submitSuccess,
    bool? isCheckingStatus,
  }) {
    return ReviewState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      submitSuccess: submitSuccess ?? this.submitSuccess,
      isCheckingStatus: isCheckingStatus ?? this.isCheckingStatus,
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

  Future<bool> hasUserReviewedBooking({
    required int providerId,
    required int bookingId,
  }) async {
    if (_disposed) return false;

    _safeUpdateState((state) => state.copyWith(isCheckingStatus: true));

    try {
      final loginState = _ref.read(loginProvider);
      if (loginState.user.token.isEmpty) {
        debugPrint('No authentication token available for review check');
        _safeUpdateState((state) => state.copyWith(isCheckingStatus: false));
        return false;
      }

      final headers = {
        'Authorization': 'Bearer ${loginState.user.token}',
        'Content-Type': 'application/json',
      };

      // Try to get existing review first
      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/providers/$providerId/reviews/booking/$bookingId');

      debugPrint('Checking existing review at: $uri');

      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (_disposed) return false;

      debugPrint('Review check response status: ${response.statusCode}');

      _safeUpdateState((state) => state.copyWith(isCheckingStatus: false));

      if (response.statusCode == 200) {
        // Review exists
        return true;
      } else if (response.statusCode == 404) {
        // No review found
        return false;
      } else {
        // Other error, assume no review to allow user to try
        debugPrint('Unexpected status code for review check: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error checking review status: $e');
      if (!_disposed) {
        _safeUpdateState((state) => state.copyWith(isCheckingStatus: false));
      }
      return false; // Assume no review to allow user to try
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
        // Remove tags since your API doesn't seem to support them based on the documentation
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
      debugPrint('Submit review response body: ${response.body}');

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
          // Check both 'message' and 'error' fields for error messages
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
          
          // Handle specific error cases
          if (response.statusCode == 409) {
            errorMessage = errorData['message'] ?? errorData['error'] ?? 'A review for this booking already exists';
          } else if (response.statusCode == 400) {
            errorMessage = errorData['message'] ?? errorData['error'] ?? 'Invalid review data';
          } else if (response.statusCode == 401) {
            errorMessage = 'Authentication failed. Please login again.';
          } else if (response.statusCode == 403) {
            errorMessage = 'You are not authorized to review this booking';
          } else if (response.statusCode == 404) {
            errorMessage = 'Booking or provider not found';
          } else if (response.statusCode == 422) {
            errorMessage = errorData['message'] ?? errorData['error'] ?? 'Invalid review data provided';
          } else if (response.statusCode >= 500) {
            errorMessage = 'Server error. Please try again later.';
          }
        } catch (e) {
          if (response.statusCode == 409) {
            errorMessage = 'A review for this booking already exists';
          } else if (response.statusCode == 400) {
            errorMessage = 'Invalid review data';
          } else if (response.statusCode == 401) {
            errorMessage = 'Authentication failed. Please login again.';
          } else if (response.statusCode == 403) {
            errorMessage = 'You are not authorized to review this booking';
          } else if (response.statusCode == 404) {
            errorMessage = 'Booking or provider not found';
          } else if (response.statusCode >= 500) {
            errorMessage = 'Server error. Please try again later.';
          } else {
            errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
          }
        }

        _safeUpdateState((state) => state.copyWith(
          isSubmitting: false,
          errorMessage: errorMessage,
        ));
        return false;
      }
    } on TimeoutException {
      if (!_disposed) {
        debugPrint('Review submission timeout');
        _safeUpdateState((state) => state.copyWith(
          isSubmitting: false,
          errorMessage: 'Request timeout. Please check your connection and try again.',
        ));
      }
      return false;
    } catch (e) {
      if (!_disposed) {
        debugPrint('Error submitting review: $e');
        String errorMessage = 'Network error: ${e.toString()}';
        
        if (e.toString().contains('SocketException') || 
            e.toString().contains('NetworkException')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Request timeout. Please try again.';
        } else if (e.toString().contains('certificate') || 
                   e.toString().contains('SSL') ||
                   e.toString().contains('TLS')) {
          errorMessage = 'Security certificate error. Please try again.';
        }
        
        _safeUpdateState((state) => state.copyWith(
          isSubmitting: false,
          errorMessage: errorMessage,
        ));
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> getReviewByBooking({
    required int providerId,
    required int bookingId,
  }) async {
    if (_disposed) return null;

    try {
      final loginState = _ref.read(loginProvider);
      if (loginState.user.token.isEmpty) {
        return null;
      }

      final headers = {
        'Authorization': 'Bearer ${loginState.user.token}',
        'Content-Type': 'application/json',
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/providers/$providerId/reviews/booking/$bookingId');

      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching review: $e');
      return null;
    }
  }

  void clearState() {
    if (!_disposed) {
      _safeUpdateState((state) => const ReviewState());
    }
  }

  void clearError() {
    if (!_disposed) {
      _safeUpdateState((state) => state.copyWith(clearError: true));
    }
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