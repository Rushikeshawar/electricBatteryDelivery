import 'package:flutter/material.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:intl/intl.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Order order;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  );

  OrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order.id}'),
        actions: [
          if (order.status.toLowerCase() == 'completed')
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                // Handle invoice download
              },
              tooltip: 'Download Invoice',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatusHeader(),
            _buildOrderDetails(),
            if (order.status.toLowerCase() == 'ongoing')
              _buildTrackingSection(),
            _buildLocationSection(),
            _buildPaymentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final statusColor = _getStatusColor(order.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(order.status),
              color: statusColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusMessage(order.status),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Location', order.locationName),
            _buildDetailRow(
                'Date', _dateFormat.format(DateTime.parse(order.date))),
            _buildDetailRow('Type', order.type.toUpperCase()),
            if (order.type == 'station')
              _buildDetailRow(
                  'Battery Capacity', order.details['battery_capacity']),
            if (order.type == 'building')
              _buildDetailRow('Duration', order.details['duration']),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Tracking',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0.6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status: Charging',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '60% Complete',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.map,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.locationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Handle navigation
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigate'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Amount', _currencyFormat.format(order.amount)),
            _buildDetailRow('Payment Method', order.details['payment_method']),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currencyFormat.format(order.amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'ongoing':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'ongoing':
        return Icons.electric_bolt;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Your charging session is complete';
      case 'ongoing':
        return 'Your charging session is in progress';
      case 'cancelled':
        return 'This order was cancelled';
      default:
        return 'Order status unknown';
    }
  }
}
