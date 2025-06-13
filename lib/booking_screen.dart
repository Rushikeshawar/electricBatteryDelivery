import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:electric_battery_delivery_frontend/payment_screen.dart';
import '../providers/booking_provider.dart';

class BookingScreen extends ConsumerWidget {
  final Station station;
  final Battery battery;

  const BookingScreen({
    Key? key,
    required this.station,
    required this.battery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Create a tuple to use with family provider
    final params = (station, battery);
    
    // Watch the state
    final bookingState = ref.watch(bookingProvider(params));
    final priceSummary = ref.watch(priceSummaryProvider(params));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Battery'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: bookingState.formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBookingSummary(bookingState),
              const SizedBox(height: 24),
              _buildQuantitySelector(context, ref, bookingState),
              const SizedBox(height: 24),
              _buildDeliveryForm(bookingState),
              const SizedBox(height: 32),
              _buildPriceSummary(bookingState, priceSummary),
              const SizedBox(height: 24),
              _buildBookButton(context, ref, params),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBookingSummary(BookingState state) {
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
              'Booking Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Station', state.station.name),
            const SizedBox(height: 8),
            _buildInfoRow('Battery Type', state.battery.type),
            const SizedBox(height: 8),
            _buildInfoRow('Voltage', '${state.battery.voltage}V'),
            const SizedBox(height: 8),
            _buildInfoRow('Capacity', '${state.battery.capacity} kWh'),
            const SizedBox(height: 8),
            _buildInfoRow('Price', '₹${state.battery.price.toStringAsFixed(0)} per unit'),
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
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  Widget _buildQuantitySelector(BuildContext context, WidgetRef ref, BookingState state) {
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
              'Select Quantity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: state.quantity > 1
                      ? () => ref.read(bookingProvider((station, battery)).notifier).decrementQuantity()
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.green.shade600,
                  iconSize: 32,
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${state.quantity}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: state.quantity < state.battery.availableQuantity
                      ? () => ref.read(bookingProvider((station, battery)).notifier).incrementQuantity()
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.green.shade600,
                  iconSize: 32,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Available: ${state.battery.availableQuantity}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDeliveryForm(BookingState state) {
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
              'Delivery Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: state.addressController,
              decoration: InputDecoration(
                labelText: 'Delivery Address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.location_on),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a delivery address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: state.notesController,
              decoration: InputDecoration(
                labelText: 'Delivery Notes (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPriceSummary(BookingState state, PriceSummary priceSummary) {
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
              'Price Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Subtotal (${state.battery.price.toStringAsFixed(0)} × ${state.quantity})',
              '₹${priceSummary.subtotal.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Delivery Fee', '₹${priceSummary.deliveryFee.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildInfoRow('Tax (18% GST)', '₹${priceSummary.tax.toStringAsFixed(2)}'),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '₹${priceSummary.total.toStringAsFixed(2)}',
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
  
  Widget _buildBookButton(BuildContext context, WidgetRef ref, (Station, Battery) params) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () => _handleBooking(context, ref, params),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Proceed to Payment',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  void _handleBooking(BuildContext context, WidgetRef ref, (Station, Battery) params) {
    final notifier = ref.read(bookingProvider(params).notifier);
    
    if (notifier.validateForm()) {
      // Create booking object
      final booking = notifier.createBooking();
      
      // Navigate to payment screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            station: station,
            battery: battery,
            booking: booking,
          ),
        ),
      );
    }
  }
}