import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:electric_battery_delivery_frontend/location_map_screen1.dart';
import 'package:electric_battery_delivery_frontend/providers/payment_provider.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final Station station;
  final Battery battery;
  final BatteryBooking booking;

  const PaymentScreen({
    Key? key,
    required this.station,
    required this.battery,
    required this.booking,
  }) : super(key: key);

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  @override
  void initState() {
    super.initState();
    
    // Add debugging
    print('PAYMENT SCREEN: Initialized with station: ${widget.station.name}');
    print('PAYMENT SCREEN: Battery: ${widget.battery.type}');
    print('PAYMENT SCREEN: Booking quantity: ${widget.booking.quantity}');
    
    // Fetch pricing when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPricing();
    });
  }

  void _fetchPricing() {
    print('PAYMENT SCREEN: Fetching pricing for product ${widget.battery.id}');
    ref.read(paymentProvider.notifier).fetchPricing(
      productId: widget.battery.id,
      quantity: widget.booking.quantity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);
    final paymentNotifier = ref.read(paymentProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: paymentState.isProcessing
          ? _buildProcessingView(paymentState)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderSummary(paymentState),
                  const SizedBox(height: 24),
                  _buildLocationOptionWithMap(paymentState, paymentNotifier, context),
                  const SizedBox(height: 24),
                  _buildPaymentMethodSelection(paymentState, paymentNotifier),
                  const SizedBox(height: 32),
                  if (paymentState.errorMessage != null)
                    _buildErrorMessage(paymentState.errorMessage!),
                  _buildPaymentButton(paymentState, paymentNotifier, context),
                ],
              ),
            ),
    );
  }

  Widget _buildProcessingView(PaymentState paymentState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
          ),
          const SizedBox(height: 24),
          Text(
            paymentState.selectedPaymentMethod == 'razorpay' 
                ? 'Processing Payment...'
                : 'Creating Order...',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            paymentState.selectedPaymentMethod == 'razorpay'
                ? 'Please complete the payment in the popup'
                : 'Please wait while we process your order',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (paymentState.selectedPaymentMethod == 'razorpay') ...[
            const SizedBox(height: 16),
            Text(
              'Do not close this screen or go back',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(paymentProvider.notifier).clearError();
            },
            color: Colors.red.shade700,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLocationOptionWithMap(PaymentState paymentState, PaymentNotifier paymentNotifier, BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            
            // Current location toggle
            SwitchListTile(
              title: const Text('Use current location'),
              subtitle: Text(
                paymentState.currentPosition != null
                    ? 'Lat: ${paymentState.currentPosition!.latitude.toStringAsFixed(4)}, '
                      'Long: ${paymentState.currentPosition!.longitude.toStringAsFixed(4)}'
                    : 'Enable to use your current GPS location',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              value: paymentState.useCurrentLocation,
              activeColor: Colors.green.shade600,
              onChanged: (value) async {
                if (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Getting your location...'),
                        ],
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  
                  await paymentNotifier.getCurrentLocation();
                  
                  if (paymentState.currentPosition != null) {
                    paymentNotifier.setSelectedLocation(
                      LatLng(
                        paymentState.currentPosition!.latitude,
                        paymentState.currentPosition!.longitude,
                      ),
                      'Current Location',
                    );
                    
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Current location selected'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
                paymentNotifier.setUseCurrentLocation(value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 16),
            
            // Map selection button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationMapScreen(
                        initialLocation: paymentState.selectedLocation,
                        initialAddress: paymentState.selectedAddress,
                        onLocationSelected: (location, address) {
                          paymentNotifier.setSelectedLocation(location, address);
                          paymentNotifier.setUseCurrentLocation(false);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✓ Location selected from map'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.map),
                label: Text(
                  paymentState.selectedLocation != null 
                      ? 'Change Location on Map'
                      : 'Select Location on Map',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            // Selected location display
            if (paymentState.selectedLocation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, 
                             color: Colors.green.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Selected Location:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      paymentState.selectedAddress.isNotEmpty 
                          ? paymentState.selectedAddress
                          : 'Custom location selected',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${paymentState.selectedLocation!.latitude.toStringAsFixed(6)}, '
                      'Lng: ${paymentState.selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, 
                         color: Colors.orange.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please select a delivery location to continue',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelection(PaymentState paymentState, PaymentNotifier paymentNotifier) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            
            // Razorpay option
            RadioListTile<String>(
              title: Row(
                children: [
                  Icon(Icons.payment, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  const Text('Online Payment'),
                ],
              ),
              subtitle: const Text('Pay securely with UPI, Cards, Net Banking & Wallets'),
              value: 'razorpay',
              groupValue: paymentState.selectedPaymentMethod,
              activeColor: Colors.green.shade600,
              onChanged: (value) {
                if (value != null) {
                  paymentNotifier.setSelectedPaymentMethod(value);
                }
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            const Divider(),
            
            // COD option
            RadioListTile<String>(
              title: Row(
                children: [
                  Icon(Icons.money, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  const Text('Cash on Delivery'),
                ],
              ),
              subtitle: const Text('Pay with cash when your order is delivered'),
              value: 'cod',
              groupValue: paymentState.selectedPaymentMethod,
              activeColor: Colors.green.shade600,
              onChanged: (value) {
                if (value != null) {
                  paymentNotifier.setSelectedPaymentMethod(value);
                }
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            if (paymentState.selectedPaymentMethod == 'razorpay') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Secure payment powered by Razorpay. All transactions are encrypted and protected.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(PaymentState paymentState) {
    // Use pricing from backend if available, otherwise show loading
    if (paymentState.pricingData == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('Loading pricing information...'),
              ),
            ],
          ),
        ),
      );
    }

    final pricing = paymentState.pricingData!['pricing'];
    final product = paymentState.pricingData!['product'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Station', widget.station.name),
            const SizedBox(height: 8),
            _buildInfoRow('Battery', product['batteryType']),
            const SizedBox(height: 8),
            _buildInfoRow('Price per unit', '₹${product['price'].toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildInfoRow('Quantity', '${widget.booking.quantity}'),
            const SizedBox(height: 8),
            _buildInfoRow('Delivery To', widget.booking.deliveryAddress),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Subtotal', '₹${pricing['subtotal'].toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _buildInfoRow('Delivery Fee', '₹${pricing['deliveryFee'].toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _buildInfoRow('Tax (18% GST)', '₹${pricing['tax'].toStringAsFixed(2)}'),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '₹${pricing['total'].toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  bool _validateLocation(PaymentState paymentState) {
    return paymentState.useCurrentLocation && paymentState.currentPosition != null ||
           paymentState.selectedLocation != null;
  }

  Widget _buildPaymentButton(PaymentState paymentState, PaymentNotifier paymentNotifier, BuildContext context) {
    if (paymentState.pricingData == null) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade400,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Loading...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    final pricing = paymentState.pricingData!['pricing'];
    final total = pricing['total'].toDouble();

    String buttonText = paymentState.selectedPaymentMethod == 'razorpay' 
        ? 'Pay ₹${total.toStringAsFixed(2)}'
        : 'Place Order ₹${total.toStringAsFixed(2)}';

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: paymentState.isProcessing ? null : () async {
          // Validate location selection
          if (!_validateLocation(paymentState)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Please select a delivery location first'),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }

          print('PAYMENT BUTTON: Starting payment process...');
          print('PAYMENT BUTTON: Payment method: ${paymentState.selectedPaymentMethod}');
          print('PAYMENT BUTTON: Total amount: ₹${total.toStringAsFixed(2)}');

          try {
            // Process payment
            final orderResult = await paymentNotifier.processPayment(
              station: widget.station,
              battery: widget.battery,
              booking: widget.booking,
            );
            
            print('PAYMENT BUTTON: Payment result: $orderResult');
            
            if (orderResult != null) {
              print('PAYMENT BUTTON: Payment successful, showing success dialog');
              _showSuccessDialog(orderResult, context);
            } else {
              print('PAYMENT BUTTON: Payment failed - no result returned');
              // Check if there's a specific error message
              final currentState = ref.read(paymentProvider);
              if (currentState.errorMessage != null) {
                // Error message is already handled by the error display widget
                print('PAYMENT BUTTON: Error message: ${currentState.errorMessage}');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            paymentState.selectedPaymentMethod == 'razorpay'
                                ? 'Payment was cancelled or failed. Please try again.'
                                : 'Order creation failed. Please try again.',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'Retry',
                      textColor: Colors.white,
                      onPressed: () {
                        // Clear any error and allow retry
                        paymentNotifier.clearError();
                      },
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            print('PAYMENT BUTTON: Exception during payment: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Payment error: ${e.toString()}'),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    paymentNotifier.clearError();
                  },
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: paymentState.isProcessing 
              ? Colors.grey.shade400 
              : Colors.green.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: paymentState.isProcessing ? 0 : 2,
        ),
        child: paymentState.isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> orderData, BuildContext context) {
    final order = orderData['data'];
    final orderId = order['orderNumber'] ?? order['id']?.toString() ?? 'Unknown';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text('Order Confirmed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your battery booking has been confirmed!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text('Order Details:'),
            const SizedBox(height: 8),
            _buildDialogInfoRow('Order ID', orderId),
            const SizedBox(height: 4),
            _buildDialogInfoRow('Station', widget.station.name),
            const SizedBox(height: 4),
            _buildDialogInfoRow('Battery', widget.battery.type),
            const SizedBox(height: 4),
            _buildDialogInfoRow('Quantity', '${widget.booking.quantity}'),
            const SizedBox(height: 4),
            _buildDialogInfoRow(
              'Payment',
              order['paymentMethod'] == 'razorpay' ? 'Paid Online' : 'Cash on Delivery',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will receive updates about your order via notifications.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to Home'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // You can navigate to order tracking or details here
              // Navigator.pushNamed(context, '/order-details', arguments: {'orderId': orderId});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Order'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}