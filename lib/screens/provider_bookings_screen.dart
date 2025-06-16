// lib/screens/provider_bookings_screen.dart - Fixed widget lifecycle issues
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/provider_models.dart';
import '../providers/provider_providers.dart';
import '../components/app_theme.dart';

class ProviderBookingsScreen extends ConsumerStatefulWidget {
  const ProviderBookingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProviderBookingsScreen> createState() => _ProviderBookingsScreenState();
}

class _ProviderBookingsScreenState extends ConsumerState<ProviderBookingsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedDate;
  int _currentPage = 1;
  final int _limit = 10;
  
  // Status filter options
  final List<Map<String, String>> _statusFilters = [
    {'value': '', 'label': 'All'},
    {'value': 'PENDING', 'label': 'Pending'},
    {'value': 'CONFIRMED', 'label': 'Confirmed'},
    {'value': 'COMPLETED', 'label': 'Completed'},
    {'value': 'CANCELLED', 'label': 'Cancelled'},
    {'value': 'NO_SHOW', 'label': 'No Show'},
  ];

  // Store current parameters to prevent re-creation
  late BookingsParameters _currentParams;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _updateCurrentParams('');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper method to create stable parameters
  void _updateCurrentParams(String? status) {
    _currentParams = BookingsParameters(
      page: _currentPage,
      limit: _limit,
      status: status?.isEmpty == true ? null : status,
      date: _selectedDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: AppTheme.gradientBackground,
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (index) {
            // Update parameters when tab changes
            _updateCurrentParams(_statusFilters[index]['value']);
          },
          tabs: _statusFilters.map((filter) => Tab(text: filter['label'])).toList(),
        ),
        actions: [
          IconButton(
            onPressed: _showDateFilter,
            icon: const Icon(Icons.date_range, color: Colors.white),
          ),
          if (_selectedDate != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                  _updateCurrentParams(_statusFilters[_tabController.index]['value']);
                });
              },
              icon: const Icon(Icons.clear, color: Colors.white),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Filtered by: $_selectedDate',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _statusFilters.map((filter) => _buildBookingsList(filter['value'])).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(String? status) {
    // Create stable parameters for this specific status
    final params = BookingsParameters(
      page: _currentPage,
      limit: _limit,
      status: status?.isEmpty == true ? null : status,
      date: _selectedDate,
    );

    final bookingsAsync = ref.watch(providerBookingsProvider(params));

    return bookingsAsync.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return _buildEmptyState(status);
        }
        return RefreshIndicator(
          onRefresh: () async {
            // Create fresh parameters for refresh
            final refreshParams = BookingsParameters(
              page: _currentPage,
              limit: _limit,
              status: status?.isEmpty == true ? null : status,
              date: _selectedDate,
            );
            ref.invalidate(providerBookingsProvider(refreshParams));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              return _buildBookingCard(bookings[index]);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString(), status),
    );
  }

  Widget _buildEmptyState(String? status) {
    String message = 'No bookings found';
    if (status != null && status.isNotEmpty) {
      message = 'No ${status.toLowerCase()} bookings';
    }
    if (_selectedDate != null) {
      message += ' for $_selectedDate';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_online,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookings will appear here when customers book your charging station.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, String? status) {
    return Center(
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
            'Failed to load bookings',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Create fresh parameters for retry
              final retryParams = BookingsParameters(
                page: _currentPage,
                limit: _limit,
                status: status?.isEmpty == true ? null : status,
                date: _selectedDate,
              );
              ref.invalidate(providerBookingsProvider(retryParams));
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(ProviderBooking booking) {
    Color statusColor = _getStatusColor(booking.status);
    IconData statusIcon = _getStatusIcon(booking.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: statusColor.withOpacity(0.1),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          booking.userPhone,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    booking.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Booking details
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    Icons.electric_bike,
                    'Vehicle',
                    booking.vehicleType,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    Icons.schedule,
                    'Time Slot',
                    booking.timeSlot,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    Icons.calendar_today,
                    'Date',
                    _formatDate(booking.bookingDate),
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    Icons.currency_rupee,
                    'Amount',
                    '₹${booking.actualAmount?.toStringAsFixed(0) ?? booking.estimatedAmount.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons based on status
            _buildActionButtons(booking),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(ProviderBooking booking) {
    switch (booking.status) {
      case 'PENDING':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateBookingStatus(booking.id, 'CANCELLED'),
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('Decline'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateBookingStatus(booking.id, 'CONFIRMED'),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      case 'CONFIRMED':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateBookingStatus(booking.id, 'NO_SHOW'),
                icon: const Icon(Icons.person_off, size: 16),
                label: const Text('No Show'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showCompleteBookingDialog(booking),
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
      case 'NO_SHOW':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'CONFIRMED':
        return Icons.check_circle_outline;
      case 'COMPLETED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      case 'NO_SHOW':
        return Icons.person_off;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDateFilter() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    ).then((date) {
      if (date != null && mounted) {
        setState(() {
          _selectedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          _updateCurrentParams(_statusFilters[_tabController.index]['value']);
        });
      }
    });
  }

  void _updateBookingStatus(String bookingId, String status) async {
    // Check if widget is still mounted before starting
    if (!mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await ref.read(providerManagementProvider.notifier).updateBookingStatus(bookingId, status);
      
      // Check if widget is still mounted before accessing context
      if (!mounted) return;
      
      // Hide loading indicator
      Navigator.of(context).pop();
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking ${status.toLowerCase()} successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh current tab data after successful update
        final currentStatus = _statusFilters[_tabController.index]['value'];
        final refreshParams = BookingsParameters(
          page: _currentPage,
          limit: _limit,
          status: currentStatus?.isEmpty == true ? null : currentStatus,
          date: _selectedDate,
        );
        ref.invalidate(providerBookingsProvider(refreshParams));
        
        // Also refresh recent bookings and pending count
        ref.invalidate(recentProviderBookingsProvider);
        ref.invalidate(pendingBookingsCountProvider);
      } else {
        final error = ref.read(providerManagementProvider).asError?.error.toString() ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update booking: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Check if widget is still mounted before accessing context
      if (!mounted) return;
      
      // Hide loading indicator if it's still showing
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCompleteBookingDialog(ProviderBooking booking) {
    if (!mounted) return;
    
    final amountController = TextEditingController(text: booking.estimatedAmount.toString());
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Complete the booking for ${booking.userName}?'),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Final Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final finalAmount = double.tryParse(amountController.text);
              if (finalAmount != null) {
                Navigator.pop(dialogContext); // Close dialog first
                
                // Check if original widget is still mounted
                if (!mounted) return;
                
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                try {
                  final success = await ref.read(providerManagementProvider.notifier).updateBookingStatus(
                    booking.id,
                    'COMPLETED',
                    actualAmount: finalAmount,
                  );
                  
                  // Check if widget is still mounted before accessing context
                  if (!mounted) return;
                  
                  // Hide loading
                  Navigator.of(context).pop();
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Booking completed successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    // Refresh data
                    final currentStatus = _statusFilters[_tabController.index]['value'];
                    final refreshParams = BookingsParameters(
                      page: _currentPage,
                      limit: _limit,
                      status: currentStatus?.isEmpty == true ? null : currentStatus,
                      date: _selectedDate,
                    );
                    ref.invalidate(providerBookingsProvider(refreshParams));
                    ref.invalidate(recentProviderBookingsProvider);
                    ref.invalidate(pendingBookingsCountProvider);
                  } else {
                    final error = ref.read(providerManagementProvider).asError?.error.toString() ?? 'Unknown error';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to complete booking: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  // Check if widget is still mounted before accessing context
                  if (!mounted) return;
                  
                  // Hide loading indicator if it's still showing
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}