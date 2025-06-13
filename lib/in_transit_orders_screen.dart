import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:electric_battery_delivery_frontend/models/order_model.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

import 'driver_tracking.dart';

// State class for in-transit orders
class InTransitOrdersState {
  final bool isLoading;
  final List<Order> orders;
  final String? errorMessage;

  const InTransitOrdersState({
    this.isLoading = false, // Default is false to allow initial loading
    this.orders = const [],
    this.errorMessage,
  });

  // Create a copy of the state with some fields updated
  InTransitOrdersState copyWith({
    bool? isLoading,
    List<Order>? orders,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InTransitOrdersState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Notifier class to manage in-transit orders state
class InTransitOrdersNotifier extends StateNotifier<InTransitOrdersState> {
  final Ref _ref;
  
  InTransitOrdersNotifier(this._ref) : super(const InTransitOrdersState());

  // Load in-transit orders from API with proper authorization
  Future<void> loadInTransitOrders() async {
    // Skip if already loading
    if (state.isLoading) {
      return;
    }
    
    // Set loading state
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      // Get the auth token from the login provider
      final token = _ref.read(loginProvider).user.token;
      
      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Make API request
      final response = await http.get(
        Uri.parse('${ApiConfig.ordersUrl}?page=1&limit=10&status=IN_TRANSIT'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // Parse the response data
        final orderResponse = OrdersResponse.fromJson(jsonData);
        
        // Update state with orders data
        state = state.copyWith(
          orders: orderResponse.data,
          isLoading: false,
        );
      } else {
        // Handle error response
        final errorData = json.decode(response.body);
        state = state.copyWith(
          isLoading: false,
          errorMessage: errorData['message'] ?? 'Failed to load orders',
        );
      }
    } catch (e) {
      // Handle exceptions
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error: ${e.toString()}',
      );
    }
  }

  // Get order details for a specific order
  Future<Order?> getOrderDetails(int orderId) async {
    try {
      // Get the auth token from the login provider
      final token = _ref.read(loginProvider).user.token;
      
      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      

      final response = await http.get(
        Uri.parse('${ApiConfig.ordersUrl}/$orderId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final orderResponse = OrderResponse.fromJson(jsonData);
        return orderResponse.data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load order details');
      }
    } catch (e) {
      throw Exception('Error fetching order details: ${e.toString()}');
    }
  }
}

// Provider for in-transit orders notifier
final inTransitOrdersProvider = StateNotifierProvider<InTransitOrdersNotifier, InTransitOrdersState>((ref) {
  return InTransitOrdersNotifier(ref);
});

// Provider for formatters
final formattersProvider = Provider<Map<String, dynamic>>((ref) {
  return {
    'date': DateFormat('MMM dd, yyyy'),
    'time': DateFormat('hh:mm a'),
    'dateTime': DateFormat('MMM dd, yyyy hh:mm a'),
    'currency': NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
    ),
  };
});

class InTransitOrdersScreen extends ConsumerStatefulWidget {
  const InTransitOrdersScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<InTransitOrdersScreen> createState() => _InTransitOrdersScreenState();
}

class _InTransitOrdersScreenState extends ConsumerState<InTransitOrdersScreen> {
  bool _isProcessing = false; // Prevent multiple clicks

  @override
  void initState() {
    super.initState();

    // Load in-transit orders when the screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force refresh of orders data
      ref.read(inTransitOrdersProvider.notifier).loadInTransitOrders();
    });
  }

  // Method to navigate to OTP verification screen
  void _navigateToOrderOtp(int orderId) {
    if (_isProcessing) return; // Prevent multiple clicks

    setState(() {
      _isProcessing = true;
    });

    try {
      // Navigate to the OTP screen with the order ID
      Navigator.of(context).pushNamed(
        '/order-otp',
        arguments: {'orderId': orderId},
      );
    } catch (e) {
      print('Error navigating to OTP screen: $e');

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error navigating to OTP screen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Method to view order details - could be expanded in the future
  void _viewOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildOrderDetailsSheet(order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inTransitState = ref.watch(inTransitOrdersProvider);
    final formatters = ref.watch(formattersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_shipping, size: 20),
            const SizedBox(width: 8),
            const Text('In Transit Orders', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${inTransitState.orders.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.green.shade700),
            onPressed: () {
              ref.read(inTransitOrdersProvider.notifier).loadInTransitOrders();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(inTransitOrdersProvider.notifier).loadInTransitOrders();
        },
        color: Colors.green.shade600,
        child: inTransitState.isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                ),
              )
            : inTransitState.errorMessage != null 
                ? _buildErrorState(inTransitState.errorMessage!)
                : inTransitState.orders.isEmpty
                    ? _buildEmptyState()
                    : _buildOrdersList(inTransitState.orders, formatters),
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(inTransitOrdersProvider.notifier).loadInTransitOrders();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No in-transit orders found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All your in-transit deliveries will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(inTransitOrdersProvider.notifier).loadInTransitOrders();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<Order> orders, Map<String, dynamic> formatters) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order, formatters);
      },
    );
  }

  Widget _buildOrderCard(Order order, Map<String, dynamic> formatters) {
    // Check if the order has OTP expiry information - use updatedAt as fallback
    final hasOtpInfo = order.updatedAt != null;
    final otpExpiryDate = hasOtpInfo 
        ? DateTime.parse(order.updatedAt!).add(const Duration(hours: 24)) 
        : DateTime.now();
    final now = DateTime.now();
    final isOtpExpired = now.isAfter(otpExpiryDate);
    
    // Get the battery type name safely
    final batteryTypeName = order.batteryType ?? 'Unknown Battery';
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _viewOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header with status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${order.orderNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_shipping,
                          size: 12,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'IN TRANSIT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Product information
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Battery icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.battery_charging_full,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Battery details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batteryTypeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Quantity: ${order.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'x${order.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatters['currency'].format(order.totalPrice),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Delivery information
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Address',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.deliveryAddress ?? 'Address not available',
                          style: const TextStyle(
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Station information
              if (order.station != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.store_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From Station',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.station!.name ?? 'Unknown Station',
                          style: const TextStyle(
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              
              const SizedBox(height: 12),
              
              // Driver information
              if (order.driver != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order.driver!.name ?? 'Unknown'} · ${order.driver!.phone ?? 'No phone'}',
                          style: const TextStyle(
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              
              const SizedBox(height: 16),
              
              // OTP section (simplified to not depend on specific properties)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOtpExpired ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOtpExpired ? Colors.red.shade200 : Colors.green.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.vpn_key,
                              size: 16,
                              color: isOtpExpired ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delivery Verification',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isOtpExpired ? Colors.red.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOtpExpired ? Colors.red.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOtpExpired ? 'Need OTP' : 'View OTP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOtpExpired ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The driver will need to verify the delivery with an OTP code.',
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isOtpExpired
                          ? 'Your OTP has expired. Please generate a new one.'
                          : 'Tap the button below to view your OTP code.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOtpExpired ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Action buttons
              // Action buttons
Column(
  children: [
    Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _viewOrderDetails(order),
            icon: Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.blue.shade700,
            ),
            label: Text(
              'Details',
              style: TextStyle(
                color: Colors.blue.shade700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.blue.shade200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _navigateToOrderOtp(order.id),
            icon: const Icon(
              Icons.vpn_key,
              size: 16,
            ),
            label: Text(
              isOtpExpired ? 'Get OTP' : 'OTP Screen',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOtpExpired ? Colors.red.shade600 : Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 8), // Add some vertical space between the rows
    Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Navigate to Driver Tracking Screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverTrackingScreen(orderId: order.id),
                ),
              );
            },
            icon: const Icon(Icons.location_on),
            label: const Text('Track Driver Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    ),
  ],
),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetailsSheet(Order order) {
    final formatters = ref.watch(formattersProvider);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          _buildDetailRow('Order Number', order.orderNumber ?? 'N/A'),
          _buildDetailRow('Status', 'IN TRANSIT', isHighlighted: true),
          if (order.createdAt != null)
            _buildDetailRow(
              'Created On', 
              formatters['dateTime'].format(DateTime.parse(order.createdAt!))
            ),
          if (order.updatedAt != null)
            _buildDetailRow(
              'Last Updated', 
              formatters['dateTime'].format(DateTime.parse(order.updatedAt!))
            ),
          _buildDetailRow(
            'Total Price', 
            formatters['currency'].format(order.totalPrice),
            isHighlighted: true
          ),
          if (order.deliveryNotes?.isNotEmpty == true)
            _buildDetailRow('Delivery Notes', order.deliveryNotes!),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _navigateToOrderOtp(order.id),
            icon: const Icon(Icons.vpn_key, size: 18),
            label: const Text('View OTP Screen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? Colors.green.shade700 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}