import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/models/booking_model.dart';
import 'package:electric_battery_delivery_frontend/providers/charging_booking_provider.dart';
import 'package:electric_battery_delivery_frontend/screens/write_review_screen.dart';

class BookingDetailsScreen extends ConsumerStatefulWidget {
  final int bookingId;
  final String userName;
  final String userEmail;

  const BookingDetailsScreen({
    super.key,
    required this.bookingId,
    required this.userName,
    required this.userEmail,
  });

  @override
  ConsumerState<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Booking? _booking;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final booking = await ref.read(chargingBookingProvider.notifier).getBookingDetails(widget.bookingId);
      
      if (mounted) {
        setState(() {
          _booking = booking;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (_booking != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareBooking,
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _booking != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading booking details...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading booking',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBookingDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_booking == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Booking not found',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadBookingDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildBookingInfoCard(),
              const SizedBox(height: 16),
              _buildProviderInfoCard(),
              const SizedBox(height: 16),
              _buildVehicleInfoCard(),
              const SizedBox(height: 16),
              _buildPaymentInfoCard(),
              if (_booking!.specialNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildNotesCard(),
              ],
              const SizedBox(height: 16),
              _buildTimelineCard(),
              const SizedBox(height: 100), // Space for bottom bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusColor = _getStatusColor(_booking!.status);
    final statusIcon = _getStatusIcon(_booking!.status);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            statusIcon,
            size: 48,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            _getStatusDisplayText(_booking!.status),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Booking #${_booking!.id}',
            style: TextStyle(
              fontSize: 16,
              color: statusColor.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingInfoCard() {
    return _buildInfoCard(
      title: 'Booking Information',
      icon: Icons.event,
      children: [
        _buildInfoRow('Date', _formatDate(_booking!.bookingDate)),
        _buildInfoRow('Time', '${_booking!.startTime} - ${_booking!.endTime}'),
        _buildInfoRow('Duration', _calculateDuration()),
        _buildInfoRow('Booked on', _formatDateTime(_booking!.createdAt)),
        if (_booking!.updatedAt != _booking!.createdAt)
          _buildInfoRow('Last updated', _formatDateTime(_booking!.updatedAt)),
      ],
    );
  }

  Widget _buildProviderInfoCard() {
    return _buildInfoCard(
      title: 'PowerPoint Provider',
      icon: Icons.business,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.ev_station,
                color: Colors.green.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _booking!.providerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _booking!.providerAddress,
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _getDirections,
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('Directions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade600,
                  side: BorderSide(color: Colors.blue.shade600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _callProvider,
                icon: const Icon(Icons.phone, size: 18),
                label: const Text('Call'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade600,
                  side: BorderSide(color: Colors.green.shade600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVehicleInfoCard() {
    return _buildInfoCard(
      title: 'Vehicle Information',
      icon: Icons.directions_car,
      children: [
        _buildInfoRow('Vehicle Type', _booking!.vehicleType),
        if (_booking!.vehicleNumber.isNotEmpty)
          _buildInfoRow('Vehicle Number', _booking!.vehicleNumber),
      ],
    );
  }

  Widget _buildPaymentInfoCard() {
    return _buildInfoCard(
      title: 'Payment Information',
      icon: Icons.payment,
      children: [
        _buildInfoRow('Total Amount', '₹${_booking!.totalAmount.toStringAsFixed(2)}'),
        _buildInfoRow('Payment Status', _booking!.paymentStatus),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Payment can be made on arrival or through the app',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return _buildInfoCard(
      title: 'Special Notes',
      icon: Icons.note,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            _booking!.specialNotes,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard() {
    return _buildInfoCard(
      title: 'Booking Timeline',
      icon: Icons.timeline,
      children: [
        _buildTimelineItem(
          'Booking Created',
          _formatDateTime(_booking!.createdAt),
          Icons.add_circle,
          Colors.blue.shade600,
          isCompleted: true,
        ),
        if (_booking!.status == 'CONFIRMED' || _booking!.status == 'COMPLETED' || _booking!.status == 'CANCELLED')
          _buildTimelineItem(
            'Booking Confirmed',
            _booking!.status == 'CONFIRMED' ? 'Confirmed' : 'Processed',
            Icons.check_circle,
            Colors.green.shade600,
            isCompleted: true,
          ),
        if (_booking!.status == 'COMPLETED')
          _buildTimelineItem(
            'Charging Completed',
            'Session finished',
            Icons.battery_full,
            Colors.orange.shade600,
            isCompleted: true,
          ),
        if (_booking!.status == 'CANCELLED')
          _buildTimelineItem(
            'Booking Cancelled',
            _formatDateTime(_booking!.updatedAt),
            Icons.cancel,
            Colors.red.shade600,
            isCompleted: true,
          ),
      ],
    );
  }

  Widget _buildTimelineItem(
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    bool isCompleted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted ? color : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.grey.shade800 : Colors.grey.shade500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.green.shade600, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canCancelBooking()) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showCancelDialog,
                  icon: const Icon(Icons.cancel_outlined, size: 20),
                  label: const Text('Cancel Booking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade600),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            if (_booking!.status == 'COMPLETED' && !_booking!.hasReview) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _writeReview,
                  icon: const Icon(Icons.star, size: 20),
                  label: const Text('Write Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyBookingId,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy ID'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade600,
                      side: BorderSide(color: Colors.green.shade600),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareBooking,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return Colors.green.shade600;
      case 'IN_PROGRESS':
      case 'CHARGING':
        return Colors.orange.shade600;
      case 'COMPLETED':
        return Colors.blue.shade600;
      case 'CANCELLED':
        return Colors.red.shade600;
      case 'PENDING':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return Icons.check_circle;
      case 'IN_PROGRESS':
      case 'CHARGING':
        return Icons.electric_bolt;
      case 'COMPLETED':
        return Icons.done_all;
      case 'CANCELLED':
        return Icons.cancel;
      case 'PENDING':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return 'Booking Confirmed';
      case 'IN_PROGRESS':
        return 'Charging in Progress';
      case 'CHARGING':
        return 'Currently Charging';
      case 'COMPLETED':
        return 'Charging Completed';
      case 'CANCELLED':
        return 'Booking Cancelled';
      case 'PENDING':
        return 'Booking Pending';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final date = _formatDate(dateTime);
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }

  String _calculateDuration() {
    try {
      final start = _parseTime(_booking!.startTime);
      final end = _parseTime(_booking!.endTime);
      
      int hours = end.hour - start.hour;
      int minutes = end.minute - start.minute;
      
      if (minutes < 0) {
        hours -= 1;
        minutes += 60;
      }
      
      if (hours < 0) {
        hours += 24; // Handle next day scenario
      }
      
      if (hours == 0) {
        return '$minutes minutes';
      } else if (minutes == 0) {
        return '$hours hour${hours > 1 ? 's' : ''}';
      } else {
        return '$hours hour${hours > 1 ? 's' : ''} $minutes minutes';
      }
    } catch (e) {
      return 'Duration not available';
    }
  }

  DateTime _parseTime(String timeString) {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2024, 1, 1, hour, minute);
  }

  bool _canCancelBooking() {
    if (_booking!.status != 'CONFIRMED') return false;
    
    try {
      final slotDateTime = DateTime(
        _booking!.bookingDate.year,
        _booking!.bookingDate.month,
        _booking!.bookingDate.day,
        int.parse(_booking!.startTime.split(':')[0]),
        int.parse(_booking!.startTime.split(':')[1]),
      );
      
      final now = DateTime.now();
      final timeDifference = slotDateTime.difference(now);
      
      return timeDifference.inHours >= 2;
    } catch (e) {
      return false;
    }
  }

  // Action methods
  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this booking?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking #${_booking!.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_booking!.providerName),
                  Text('${_formatDate(_booking!.bookingDate)} at ${_booking!.startTime}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cancellation is free up to 2 hours before your slot time.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelBooking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking() async {
    try {
      final success = await ref.read(chargingBookingProvider.notifier).cancelBooking(_booking!.id);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Booking cancelled successfully'),
              backgroundColor: Colors.green.shade600,
            ),
          );
          // Reload booking details to show updated status
          _loadBookingDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel booking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _writeReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteReviewScreen(
          booking: _booking!,
          userName: widget.userName,
          userEmail: widget.userEmail,
        ),
      ),
    ).then((result) {
      // If review was written successfully, reload booking details
      if (result == true) {
        _loadBookingDetails();
      }
    });
  }

  void _copyBookingId() {
    Clipboard.setData(ClipboardData(text: '#${_booking!.id}'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Booking ID copied to clipboard'),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareBooking() {
    final bookingDetails = '''
🔋 BatteryWala PowerPoint Booking

📋 Booking ID: #${_booking!.id}
📊 Status: ${_getStatusDisplayText(_booking!.status)}
🏢 Provider: ${_booking!.providerName}
📍 Location: ${_booking!.providerAddress}
📅 Date: ${_formatDate(_booking!.bookingDate)}
⏰ Time: ${_booking!.startTime} - ${_booking!.endTime}
🚗 Vehicle: ${_booking!.vehicleType}
💰 Amount: ₹${_booking!.totalAmount.toStringAsFixed(2)}

Powered by BatteryWala - Your Electric Mobility Partner
    ''';
    
    // In a real app, you would use a sharing plugin here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening share options...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _getDirections() {
    // Implement navigation to maps app
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening directions in maps app...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _callProvider() {
    // Implement call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calling provider...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}