import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:electric_battery_delivery_frontend/location_map_screen1.dart';
import '../providers/payment_provider.dart';

class PaymentScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentState = ref.watch(paymentProvider);
    final paymentNotifier = ref.read(paymentProvider.notifier);

    final _formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: paymentState.isProcessing
          ? _buildProcessingView()
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOrderSummary(station, battery, booking),
                    const SizedBox(height: 24),
                    _buildLocationOptionWithMap(paymentState, paymentNotifier, context),
                    const SizedBox(height: 24),
                    _buildPaymentForm(paymentState, paymentNotifier),
                    const SizedBox(height: 32),
                    if (paymentState.errorMessage != null)
                      _buildErrorMessage(paymentState.errorMessage!),
                    _buildPaymentButton(
                      paymentState, 
                      paymentNotifier, 
                      _formKey, 
                      station, 
                      battery,
                      booking, 
                      context
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
          ),
          const SizedBox(height: 24),
          const Text(
            'Processing Payment...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please do not close this screen',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
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
                  // Show loading while getting location
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
                    // Set current location as selected location
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
                          // If user selects from map, disable current location toggle
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
              // Warning when no location is selected
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
            
            // Fallback address display
            if (!paymentState.useCurrentLocation && paymentState.selectedLocation == null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Default Address: ${booking.deliveryAddress}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Validation function for location
  bool _validateLocation(PaymentState paymentState) {
    return paymentState.useCurrentLocation && paymentState.currentPosition != null ||
           paymentState.selectedLocation != null;
  }

  Widget _buildOrderSummary(Station station, Battery battery, BatteryBooking booking) {
    const deliveryFee = 50.0;
    const taxRate = 0.18;

    final subtotal = booking.totalPrice;
    final tax = subtotal * taxRate;
    final total = subtotal + tax + deliveryFee;

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
            _buildInfoRow('Station', station.name),
            const SizedBox(height: 8),
            _buildInfoRow('Battery', battery.type),
            const SizedBox(height: 8),
            _buildInfoRow('Quantity', '${booking.quantity}'),
            const SizedBox(height: 8),
            _buildInfoRow('Delivery To', booking.deliveryAddress),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _buildInfoRow('Delivery Fee', '₹${deliveryFee.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _buildInfoRow('Tax (18% GST)', '₹${tax.toStringAsFixed(2)}'),
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
                  '₹${total.toStringAsFixed(2)}',
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

  Widget _buildPaymentForm(PaymentState paymentState, PaymentNotifier paymentNotifier) {
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
              'Card Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: paymentState.cardNumberController,
              decoration: InputDecoration(
                labelText: 'Card Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.credit_card),
                hintText: 'XXXX XXXX XXXX XXXX',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
                _CardNumberFormatter(),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter card number';
                }
                if (value.replaceAll(' ', '').length < 16) {
                  return 'Please enter a valid 16-digit card number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: paymentState.cardHolderController,
              decoration: InputDecoration(
                labelText: 'Card Holder Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter card holder name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: paymentState.expiryController,
                    decoration: InputDecoration(
                      labelText: 'Expiry (MM/YY)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.calendar_today),
                      hintText: 'MM/YY',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      _ExpiryDateFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length < 5) {
                        return 'Invalid format';
                      }

                      final parts = value.split('/');
                      if (parts.length != 2) {
                        return 'Invalid format';
                      }

                      final month = int.tryParse(parts[0]);
                      if (month == null || month < 1 || month > 12) {
                        return 'Invalid month';
                      }

                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: paymentState.cvvController,
                    decoration: InputDecoration(
                      labelText: 'CVV',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.security),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length < 3) {
                        return 'Invalid CVV';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Save card for future payments'),
              value: paymentState.saveCard,
              onChanged: (value) {
                paymentNotifier.setSaveCard(value ?? false);
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButton(
    PaymentState paymentState, 
    PaymentNotifier paymentNotifier, 
    GlobalKey<FormState> formKey, 
    Station station, 
    Battery battery,
    BatteryBooking booking, 
    BuildContext context
  ) {
    const deliveryFee = 50.0;
    const taxRate = 0.18;

    final subtotal = booking.totalPrice;
    final tax = subtotal * taxRate;
    final total = subtotal + tax + deliveryFee;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () async {
          // First validate the form
          if (!formKey.currentState!.validate()) {
            return;
          }
          
          // Then validate location selection
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

          // Proceed with payment if all validations pass
          final orderResult = await paymentNotifier.processPayment(
            station: station,
            battery: battery,
            booking: booking,
          );
          
          if (orderResult != null) {
            _showSuccessDialog(station, booking, orderResult, context);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Pay ₹${total.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(Station station, BatteryBooking booking, Map<String, dynamic> orderData, BuildContext context) {
    final order = orderData['data'];
    final orderId = order['orderNumber'] ?? 'Unknown';
    
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
            const Text('Payment Successful'),
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
            const Text('Booking Details:'),
            const SizedBox(height: 8),
            _buildDialogInfoRow('Order ID', orderId),
            const SizedBox(height: 4),
            _buildDialogInfoRow('Station', station.name),
            const SizedBox(height: 4),
            _buildDialogInfoRow('Battery', battery.type),
            const SizedBox(height: 4),
            _buildDialogInfoRow('Quantity', '${booking.quantity}'),
            const SizedBox(height: 4),
            _buildDialogInfoRow(
              'Delivery',
              'Within ${station.etaMinutes} minutes',
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
              _showOrderConfirmation(station, booking, order, context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Track Order'),
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

  void _showOrderConfirmation(Station station, BatteryBooking booking, dynamic order, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Order Confirmation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Thank you for your order!',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.green.shade600,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 4,
                                color: Colors.green.shade600,
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delivery_dining,
                                color: Colors.green.shade600,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 4,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.home,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Confirmed',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(
                              'On the way',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Delivered',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Estimated delivery: ${station.etaMinutes} minutes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Address',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          booking.deliveryAddress,
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (booking.deliveryNotes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Notes: ${booking.deliveryNotes}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom formatter for card number input - adds space after every 4 digits
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

// Custom formatter for expiry date input - adds / after 2 digits
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}