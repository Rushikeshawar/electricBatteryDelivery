import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/models/booking_model.dart';
import 'package:electric_battery_delivery_frontend/models/charging_provider_model.dart';
import 'package:electric_battery_delivery_frontend/providers/charging_booking_provider.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';
import 'package:electric_battery_delivery_frontend/screens/booking_details_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/write_review_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/charging_providers_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/map_directions_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MyBookingsScreen extends ConsumerStatefulWidget {
  final String userName;
  final String userEmail;

  const MyBookingsScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  String _searchQuery = '';
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController();
    
    // Load bookings when screen initializes with proper mounted check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookingsData().then((_) {
        // Uncomment next line for debugging
        // _debugBookings();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingsData() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isInitialLoading = true;
      });
      
      final bookingNotifier = ref.read(chargingBookingProvider.notifier);
      
      // Load all bookings without status filter to get complete data
      await bookingNotifier.loadUserBookings(
        page: 1,
        limit: 200, // Increase limit to get more bookings in single request
        refresh: true,
      );
      
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      print('Error loading bookings: $e');
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bookings: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadBookingsData,
            ),
          ),
        );
      }
    }
  }

  // Add debug method to see what bookings are being loaded
  void _debugBookings() {
    final bookingState = ref.read(chargingBookingProvider);
    print('=== BOOKING DEBUG ===');
    print('Total bookings: ${bookingState.bookings.length}');
    
    for (final booking in bookingState.bookings) {
      print('Booking ${booking.id}: ${booking.status} - ${booking.bookingDate} ${booking.startTime}');
    }
    
    print('Upcoming: ${_getUpcomingBookings(bookingState.bookings).length}');
    print('Active: ${_getActiveBookings(bookingState.bookings).length}');
    print('History: ${_getCompletedBookings(bookingState.bookings).length}');
    print('=====================');
  }

  // Method to navigate to charging providers screen
  void _navigateToChargingProviders() {
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChargingProvidersScreen(
          userName: widget.userName,
          userEmail: widget.userEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(chargingBookingProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Upcoming',
              icon: Badge(
                isLabelVisible: _getUpcomingBookings(bookingState.bookings).isNotEmpty,
                label: Text('${_getUpcomingBookings(bookingState.bookings).length}'),
                child: const Icon(Icons.schedule),
              ),
            ),
            Tab(
              text: 'Active',
              icon: Badge(
                isLabelVisible: _getActiveBookings(bookingState.bookings).isNotEmpty,
                label: Text('${_getActiveBookings(bookingState.bookings).length}'),
                child: const Icon(Icons.electric_bolt),
              ),
            ),
            Tab(
              text: 'History',
              icon: Badge(
                isLabelVisible: _getCompletedBookings(bookingState.bookings).isNotEmpty,
                label: Text('${_getCompletedBookings(bookingState.bookings).length}'),
                child: const Icon(Icons.history),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBookingsList(_getUpcomingBookings(bookingState.bookings), 'upcoming'),
                _buildBookingsList(_getActiveBookings(bookingState.bookings), 'active'),
                _buildBookingsList(_getCompletedBookings(bookingState.bookings), 'history'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToChargingProviders,
        backgroundColor: Colors.green.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search bookings...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    if (!mounted) return;
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        onChanged: (value) {
          if (!mounted) return;
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildBookingsList(List<Booking> bookings, String type) {
    final bookingState = ref.watch(chargingBookingProvider);
    
    // Show initial loading only on first load
    if (_isInitialLoading || (bookingState.isLoading && bookingState.bookings.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your bookings...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Show error state
    if (bookingState.errorMessage != null && bookingState.bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading bookings',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bookingState.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (!mounted) return;
                _loadBookingsData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final filteredBookings = _getFilteredBookings(bookings);
    
    // Show empty state
    if (filteredBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIconForType(type),
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyTitleForType(type),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptyMessageForType(type),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
            if (type == 'upcoming') ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _navigateToChargingProviders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                ),
                child: const Text('Book a Slot', style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      );
    }

    // Show bookings list with pull-to-refresh
    return RefreshIndicator(
      onRefresh: () async {
        if (!mounted) return;
        await _loadBookingsData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredBookings.length,
        itemBuilder: (context, index) {
          final booking = filteredBookings[index];
          return _buildBookingCard(booking, type);
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, String type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingDetailsScreen(
                bookingId: booking.id,
                userName: widget.userName,
                userEmail: widget.userEmail,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with booking ID and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Booking #${booking.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(booking.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(booking.status).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getStatusDisplayText(booking.status),
                      style: TextStyle(
                        color: _getStatusColor(booking.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Provider info
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.ev_station,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.providerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          booking.providerAddress,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Booking details
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      'Date',
                      _formatDate(booking.bookingDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.access_time,
                      'Time',
                      '${booking.startTime} - ${booking.endTime}',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.directions_car,
                      'Vehicle',
                      booking.vehicleType,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.currency_rupee,
                      'Amount',
                      '₹${booking.totalAmount.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action buttons based on status and type
              _buildActionButtons(booking, type),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
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
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Booking booking, String type) {
    switch (type) {
      case 'upcoming':
        return Row(
          children: [
            if (_canCancelBooking(booking)) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showCancelDialog(booking),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade600),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _getDirections(booking),
                icon: const Icon(Icons.directions, size: 16),
                label: const Text('Directions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      
      case 'active':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _trackCharging(booking),
                icon: const Icon(Icons.electric_bolt, size: 16),
                label: const Text('Track Charging'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _callProvider(booking),
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('Call'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade600,
                  side: BorderSide(color: Colors.blue.shade600),
                ),
              ),
            ),
          ],
        );
      
      case 'history':
        return Row(
          children: [
            if (booking.status == 'COMPLETED' && !booking.hasReview) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _writeReview(booking),
                  icon: const Icon(Icons.star, size: 16),
                  label: const Text('Write Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _rebookSlot(booking),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Book Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade600,
                  side: BorderSide(color: Colors.green.shade600),
                ),
              ),
            ),
          ],
        );
      
      default:
        return const SizedBox.shrink();
    }
  }

  // Helper methods with improved filtering logic
  List<Booking> _getUpcomingBookings(List<Booking> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return bookings.where((booking) {
      // Check if booking is confirmed or pending
      final isValidStatus = ['CONFIRMED', 'PENDING'].contains(booking.status.toUpperCase());
      
      // Check if booking date is today or future
      final bookingDateOnly = DateTime(
        booking.bookingDate.year, 
        booking.bookingDate.month, 
        booking.bookingDate.day
      );
      final isFutureOrToday = bookingDateOnly.isAtSameMomentAs(today) || 
                             bookingDateOnly.isAfter(today);
      
      // For today's bookings, also check if the time hasn't passed
      if (bookingDateOnly.isAtSameMomentAs(today)) {
        try {
          final slotDateTime = DateTime(
            booking.bookingDate.year,
            booking.bookingDate.month,
            booking.bookingDate.day,
            int.parse(booking.startTime.split(':')[0]),
            int.parse(booking.startTime.split(':')[1]),
          );
          return isValidStatus && slotDateTime.isAfter(now);
        } catch (e) {
          print('Error parsing time for booking ${booking.id}: $e');
          return isValidStatus && isFutureOrToday;
        }
      }
      
      return isValidStatus && isFutureOrToday;
    }).toList()..sort((a, b) => a.bookingDate.compareTo(b.bookingDate));
  }

  List<Booking> _getActiveBookings(List<Booking> bookings) {
    // Include all possible active statuses
    final activeStatuses = [
      'IN_PROGRESS', 
      'CHARGING', 
      'STARTED', 
      'ONGOING',
      'ACTIVE'
    ];
    
    return bookings.where((booking) {
      return activeStatuses.contains(booking.status.toUpperCase());
    }).toList()..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
  }

  List<Booking> _getCompletedBookings(List<Booking> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return bookings.where((booking) {
      final completedStatuses = ['COMPLETED', 'CANCELLED', 'EXPIRED', 'FAILED'];
      final isCompletedStatus = completedStatuses.contains(booking.status.toUpperCase());
      
      // Also include past confirmed bookings that are overdue
      if (booking.status.toUpperCase() == 'CONFIRMED') {
        final bookingDateOnly = DateTime(
          booking.bookingDate.year, 
          booking.bookingDate.month, 
          booking.bookingDate.day
        );
        
        // If booking date is in the past, consider it history
        if (bookingDateOnly.isBefore(today)) {
          return true;
        }
        
        // If booking is today but time has passed, consider it history
        if (bookingDateOnly.isAtSameMomentAs(today)) {
          try {
            final slotDateTime = DateTime(
              booking.bookingDate.year,
              booking.bookingDate.month,
              booking.bookingDate.day,
              int.parse(booking.endTime.split(':')[0]),
              int.parse(booking.endTime.split(':')[1]),
            );
            return slotDateTime.isBefore(now);
          } catch (e) {
            print('Error parsing end time for booking ${booking.id}: $e');
            return false;
          }
        }
      }
      
      return isCompletedStatus;
    }).toList()..sort((a, b) => b.bookingDate.compareTo(a.bookingDate)); // Most recent first
  }

  List<Booking> _getFilteredBookings(List<Booking> bookings) {
    if (_searchQuery.isEmpty) return bookings;
    
    final query = _searchQuery.toLowerCase();
    return bookings.where((booking) {
      return booking.id.toString().contains(query) ||
             booking.providerName.toLowerCase().contains(query) ||
             booking.providerAddress.toLowerCase().contains(query) ||
             booking.vehicleType.toLowerCase().contains(query);
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return Colors.green.shade600;
      case 'IN_PROGRESS':
      case 'CHARGING':
      case 'STARTED':
      case 'ONGOING':
      case 'ACTIVE':
        return Colors.orange.shade600;
      case 'COMPLETED':
        return Colors.blue.shade600;
      case 'CANCELLED':
      case 'FAILED':
        return Colors.red.shade600;
      case 'PENDING':
        return Colors.grey.shade600;
      case 'EXPIRED':
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return 'Confirmed';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'CHARGING':
        return 'Charging';
      case 'STARTED':
        return 'Started';
      case 'ONGOING':
        return 'Ongoing';
      case 'ACTIVE':
        return 'Active';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'PENDING':
        return 'Pending';
      case 'FAILED':
        return 'Failed';
      case 'EXPIRED':
        return 'Expired';
      default:
        return status;
    }
  }

  IconData _getEmptyIconForType(String type) {
    switch (type) {
      case 'upcoming':
        return Icons.schedule;
      case 'active':
        return Icons.electric_bolt;
      case 'history':
        return Icons.history;
      default:
        return Icons.ev_station;
    }
  }

  String _getEmptyTitleForType(String type) {
    switch (type) {
      case 'upcoming':
        return 'No upcoming bookings';
      case 'active':
        return 'No active charging sessions';
      case 'history':
        return 'No booking history';
      default:
        return 'No bookings found';
    }
  }

  String _getEmptyMessageForType(String type) {
    switch (type) {
      case 'upcoming':
        return 'Book a charging slot to see it here';
      case 'active':
        return 'Start charging to track your session';
      case 'history':
        return 'Your completed bookings will appear here';
      default:
        return 'No bookings available';
    }
  }

  bool _canCancelBooking(Booking booking) {
    if (booking.status != 'CONFIRMED') return false;
    
    try {
      final slotDateTime = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
        int.parse(booking.startTime.split(':')[0]),
        int.parse(booking.startTime.split(':')[1]),
      );
      
      final now = DateTime.now();
      final timeDifference = slotDateTime.difference(now);
      
      return timeDifference.inHours >= 2;
    } catch (e) {
      print('Error checking cancel booking: $e');
      return false;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  void _showCancelDialog(Booking booking) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this booking?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking #${booking.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(booking.providerName),
                  Text('${_formatDate(booking.bookingDate)} at ${booking.startTime}'),
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
            onPressed: () {
              Navigator.pop(context);
              _performCancelBooking(booking);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Cancel Booking', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancelBooking(Booking booking) async {
    if (!mounted) return;
    
    try {
      // Store the notifier reference
      final bookingNotifier = ref.read(chargingBookingProvider.notifier);
      final success = await bookingNotifier.cancelBooking(booking.id);
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking cancelled successfully'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Enhanced _getDirections method that uses real coordinates when available
  Future<void> _getDirections(Booking booking) async {
    if (!mounted) return;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Getting directions to ${booking.providerName}...'),
              ),
            ],
          ),
        ),
      );

      ChargingProvider? provider;

      // Check if booking already has coordinates
      if (booking.hasCoordinates) {
        // Use coordinates from booking - FIXED: Removed reviewCount parameter
        
      } else {
        // Try to get the real provider data from API
        try {
          provider = await _fetchProviderDetails(booking.providerId);
        } catch (e) {
          print('Failed to fetch provider details: $e');
        }

        // If still no provider data, create one with estimated coordinates
        if (provider == null) {
          final coordinates = await _getCoordinatesFromAddress(booking.providerAddress);
          
          // FIXED: Removed reviewCount parameter
          
        }
      }
      
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
        
        // FIXED: Ensure provider is not null before navigation
        if (provider != null) {
          // Navigate to MapDirectionsScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MapDirectionsScreen(
                provider: provider!, // FIXED: Added non-null assertion
                providerName: booking.providerName,
                providerAddress: booking.providerAddress,
              ),
            ),
          );
        } else {
          // If provider is still null, show error and fallback to external maps
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load provider details. Opening external maps...'),
              backgroundColor: Colors.orange,
            ),
          );
          _openExternalMaps(booking.providerAddress);
        }
      }
      
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
        
        print('Error navigating to directions: $e');
        
        // Show error message and offer fallback
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Navigation Error'),
            content: const Text('Could not load directions. Would you like to open in external maps?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openExternalMaps(booking.providerAddress);
                },
                child: const Text('Open External Maps'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Method to fetch real provider details from API
  Future<ChargingProvider?> _fetchProviderDetails(int providerId) async {
    try {
      // Get auth token
      final loginState = ref.read(loginProvider);
      final token = loginState.user.token;

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Fetch provider details from your API
      final url = Uri.parse('${ApiConfig.baseUrl}/providers/$providerId');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return ChargingProvider.fromJson(data['data']);
        }
      }
    } catch (e) {
      print('Error fetching provider details: $e');
    }
    return null;
  }

  // Method to get coordinates from address using geocoding service
  Future<Map<String, double?>> _getCoordinatesFromAddress(String address) async {
    try {
      // Basic address-based coordinate mapping
      final Map<String, Map<String, double>> cityCoordinates = {
        'pune': {'lat': 18.5204, 'lng': 73.8567},
        'mumbai': {'lat': 19.0760, 'lng': 72.8777},
        'delhi': {'lat': 28.7041, 'lng': 77.1025},
        'bangalore': {'lat': 12.9716, 'lng': 77.5946},
        'chennai': {'lat': 13.0827, 'lng': 80.2707},
        'hyderabad': {'lat': 17.3850, 'lng': 78.4867},
        'kolkata': {'lat': 22.5726, 'lng': 88.3639},
        'ahmedabad': {'lat': 23.0225, 'lng': 72.5714},
      };

      final addressLower = address.toLowerCase();
      
      for (final city in cityCoordinates.keys) {
        if (addressLower.contains(city)) {
          return {
            'latitude': cityCoordinates[city]!['lat'],
            'longitude': cityCoordinates[city]!['lng'],
          };
        }
      }

      // Default to Pune coordinates
      return {
        'latitude': 18.5204,
        'longitude': 73.8567,
      };
    } catch (e) {
      print('Error getting coordinates from address: $e');
      return {
        'latitude': 18.5204,
        'longitude': 73.8567,
      };
    }
  }

  // Helper method to get default latitude based on address
  double _getDefaultLatitude(String address) {
    // Basic city coordinate mapping
    if (address.toLowerCase().contains('pune')) {
      return 18.5204;
    } else if (address.toLowerCase().contains('mumbai')) {
      return 19.0760;
    } else if (address.toLowerCase().contains('delhi')) {
      return 28.7041;
    } else if (address.toLowerCase().contains('bangalore')) {
      return 12.9716;
    }
    // Default to Pune
    return 18.5204;
  }

  // Helper method to get default longitude based on address
  double _getDefaultLongitude(String address) {
    // Basic city coordinate mapping
    if (address.toLowerCase().contains('pune')) {
      return 73.8567;
    } else if (address.toLowerCase().contains('mumbai')) {
      return 72.8777;
    } else if (address.toLowerCase().contains('delhi')) {
      return 77.1025;
    } else if (address.toLowerCase().contains('bangalore')) {
      return 77.5946;
    }
    // Default to Pune
    return 73.8567;
  }

  // Fallback method to open external maps app with address
  void _openExternalMaps(String address) {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
      
      launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open maps. Please check the address manually.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _trackCharging(Booking booking) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening charging tracker...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _callProvider(Booking booking) {
    if (!mounted) return;
    
    // Try to call provider if phone number is available
    if (booking.providerPhone != null && booking.providerPhone!.isNotEmpty) {
      try {
        launchUrl(Uri.parse('tel:${booking.providerPhone}'));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not initiate call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contact ${booking.providerName} for assistance'),
          backgroundColor: Colors.blue.shade600,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _writeReview(Booking booking) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteReviewScreen(
          booking: booking,
          userName: widget.userName,
          userEmail: widget.userEmail,
        ),
      ),
    );
  }

  void _rebookSlot(Booking booking) {
    if (!mounted) return;
    _navigateToChargingProviders();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redirecting to booking screen...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}