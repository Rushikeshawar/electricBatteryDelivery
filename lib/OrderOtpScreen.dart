import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

import 'package:electric_battery_delivery_frontend/driver_tracking.dart';

// OTP state class
class OrderOtpState {
  final bool isLoading;
  final bool error;
  final String? errorMessage;
  final Map<String, dynamic>? otpData;
  final int? orderId;
  final Timer? refreshTimer;

  OrderOtpState({
    required this.isLoading,
    required this.error,
    this.errorMessage,
    this.otpData,
    this.orderId,
    this.refreshTimer,
  });

  OrderOtpState copyWith({
    bool? isLoading,
    bool? error,
    String? errorMessage,
    Map<String, dynamic>? otpData,
    int? orderId,
    Timer? refreshTimer,
    bool clearError = false,
    bool clearOtpData = false,
  }) {
    return OrderOtpState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      otpData: clearOtpData ? null : (otpData ?? this.otpData),
      orderId: orderId ?? this.orderId,
      refreshTimer: refreshTimer ?? this.refreshTimer,
    );
  }
}

// Order OTP notifier
class OrderOtpNotifier extends StateNotifier<OrderOtpState> {
  final Ref _ref;

  OrderOtpNotifier(this._ref)
      : super(OrderOtpState(
          isLoading: false,
          error: false,
        ));

  // Initialize OTP screen with an order ID and start polling
  void initOtpScreen(int orderId) {
    // Cancel any existing timer
    state.refreshTimer?.cancel();

    // Update state with new order ID and clear any previous data
    state = state.copyWith(
      isLoading: true,
      error: false,
      clearError: true,
      clearOtpData: true,
      orderId: orderId,
    );

    // Fetch OTP immediately
    fetchOrderOtp();

    // Create a timer to refresh the OTP status every 5 seconds
    final timer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchOrderOtp();
    });

    // Update state with the new timer
    state = state.copyWith(refreshTimer: timer);
  }

  // Fetch OTP for the current order
  Future<void> fetchOrderOtp() async {
    if (state.orderId == null) return;

    try {
      state = state.copyWith(isLoading: true, error: false, clearError: true);

      // Get auth token
      final token = _ref.read(loginProvider).user.token;
      if (token == null || token.isEmpty) {
        throw Exception(
            'Authentication token not available. Please log in again.');
      }

      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Make API request to get OTP
      final url = Uri.parse('${ApiConfig.ordersUrl}/${state.orderId}/otp');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true && jsonData['data'] != null) {
          state = state.copyWith(
            otpData: jsonData['data'],
            isLoading: false,
            error: false,
          );

          // If OTP is verified, stop polling
          if (jsonData['data']['isVerified'] == true) {
            stopPolling();
          }
        } else {
          throw Exception('Invalid data format from API');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load OTP');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: true,
        errorMessage: 'Error fetching OTP: ${e.toString()}',
      );
    }
  }

  // Stop polling for OTP updates
  void stopPolling() {
    state.refreshTimer?.cancel();
    state = state.copyWith(refreshTimer: null);
  }

  // Manual refresh of OTP data
  Future<void> refreshOtp() async {
    await fetchOrderOtp();
  }

  // Clean up resources
  @override
  void dispose() {
    state.refreshTimer?.cancel();
    super.dispose();
  }
}

// Provider for order OTP state
final orderOtpProvider =
    StateNotifierProvider<OrderOtpNotifier, OrderOtpState>((ref) {
  return OrderOtpNotifier(ref);
});

class OrderOtpScreen extends ConsumerStatefulWidget {
  final int orderId;

  const OrderOtpScreen({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  ConsumerState<OrderOtpScreen> createState() => _OrderOtpScreenState();
}

class _OrderOtpScreenState extends ConsumerState<OrderOtpScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Initialize OTP screen with the provided order ID
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderOtpProvider.notifier).initOtpScreen(widget.orderId);
    });
  }

  @override
  void dispose() {
    // Stop polling when screen is disposed
    ref.read(orderOtpProvider.notifier).stopPolling();
    super.dispose();
  }

  // Format OTP with spaces for better readability
  String _formatOtp(String otp) {
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < otp.length; i++) {
      buffer.write(otp[i]);
      if (i % 3 == 2 && i != otp.length - 1) {
        buffer.write(' ');
      }
    }

    return buffer.toString();
  }

  // Copy OTP to clipboard
  void _copyOtpToClipboard(String otp) {
    Clipboard.setData(ClipboardData(text: otp));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OTP copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(orderOtpProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order OTP',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (_isProcessing) return;

              setState(() {
                _isProcessing = true;
              });

              ref.read(orderOtpProvider.notifier).refreshOtp().then((_) {
                if (mounted) {
                  setState(() {
                    _isProcessing = false;
                  });
                }
              });
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh OTP',
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: otpState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : otpState.error
                  ? _buildErrorView(
                      otpState.errorMessage ?? 'Unknown error occurred')
                  : otpState.otpData != null
                      ? _buildOtpView(otpState.otpData!)
                      : _buildEmptyState(),
        ),
      ),
    );
  }

  Widget _buildOtpView(Map<String, dynamic> otpData) {
    final otp = otpData['otp'] as String? ?? '';
    final isExpired = otpData['isExpired'] as bool? ?? false;
    final isVerified = otpData['isVerified'] as bool? ?? false;
    final orderNumber = otpData['orderNumber'] as String? ?? 'Unknown';
    final status = otpData['status'] as String? ?? 'UNKNOWN';

    return Column(
      mainAxisAlignment: MainAxisAlignment
          .spaceBetween, // Use space between to push the button to the bottom
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            // Order details section
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Order #$orderNumber',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // OTP display
            Text(
              'Your One-Time Password',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // OTP digits in separate containers with automatic copying
            GestureDetector(
              onTap: () {
                // Copy OTP to clipboard
                if (otp.isNotEmpty) {
                  _copyOtpToClipboard(otp);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: isExpired || isVerified
                      ? Colors.grey.shade200
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isExpired || isVerified
                        ? Colors.grey.shade400
                        : Colors.green.shade200,
                    width: 2,
                  ),
                ),
                child: otp.isEmpty
                    ? const Center(
                        child: Text(
                          'Waiting for OTP...',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatOtp(otp),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: isExpired || isVerified
                                  ? Colors.grey.shade600
                                  : Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.copy,
                            size: 18,
                            color: isExpired || isVerified
                                ? Colors.grey.shade600
                                : Colors.green.shade700,
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Status badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusBadge(
                  isExpired ? 'Expired' : 'Valid',
                  isExpired ? Colors.red : Colors.green,
                  isExpired ? Icons.timer_off : Icons.timer,
                ),
                const SizedBox(width: 16),
                _buildStatusBadge(
                  isVerified ? 'Verified' : 'Not Verified',
                  isVerified ? Colors.green : Colors.orange,
                  isVerified ? Icons.verified : Icons.pending,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Auto-refresh indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sync,
                  size: 14,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Auto-refreshing every 5 seconds',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),

            // Buttons
            const SizedBox(height: 32),
            if (isVerified)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('OTP Verified - Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else if (isExpired)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('OTP Expired - Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please share this OTP with the station attendant',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The OTP will be verified automatically when used',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        // See Driver Location Button
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DriverTrackingScreen(orderId: widget.orderId),
                ),
              );
            },
            icon: const Icon(Icons.location_on),
            label: const Text('See Driver Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading OTP',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (_isProcessing) return;

              setState(() {
                _isProcessing = true;
              });

              ref.read(orderOtpProvider.notifier).refreshOtp().then((_) {
                if (mounted) {
                  setState(() {
                    _isProcessing = false;
                  });
                }
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.vpn_key_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No OTP Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Loading OTP for Order #${widget.orderId}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (_isProcessing) return;

              setState(() {
                _isProcessing = true;
              });

              ref.read(orderOtpProvider.notifier).refreshOtp().then((_) {
                if (mounted) {
                  setState(() {
                    _isProcessing = false;
                  });
                }
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      case 'PROCESSING':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
