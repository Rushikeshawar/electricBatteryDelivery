import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/models/booking_model.dart';
import 'package:electric_battery_delivery_frontend/providers/charging_booking_provider.dart';
import 'package:electric_battery_delivery_frontend/screens/booking_details_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/write_review_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/charging_providers_screen.dart';

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
      _loadBookingsData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Safe method to load bookings data
  Future<void> _loadBookingsData() async {
    if (!mounted) return;
    
    try {
      // Store the notifier reference to avoid using ref after disposal
      final bookingNotifier = ref.read(chargingBookingProvider.notifier);
      await bookingNotifier.loadUserBookings();
      
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
      }
    }
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
                onPressed: () => _contactProvider(booking),
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

  // Helper methods
  List<Booking> _getUpcomingBookings(List<Booking> bookings) {
    return bookings.where((booking) {
      return booking.status == 'CONFIRMED' && 
             booking.bookingDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
    }).toList()..sort((a, b) => a.bookingDate.compareTo(b.bookingDate));
  }

  List<Booking> _getActiveBookings(List<Booking> bookings) {
    return bookings.where((booking) {
      return booking.status == 'IN_PROGRESS' || booking.status == 'CHARGING';
    }).toList()..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
  }

  List<Booking> _getCompletedBookings(List<Booking> bookings) {
    return bookings.where((booking) {
      return booking.status == 'COMPLETED' || booking.status == 'CANCELLED';
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

  String _getStatusDisplayText(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return 'Confirmed';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'CHARGING':
        return 'Charging';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'PENDING':
        return 'Pending';
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

  void _getDirections(Booking booking) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening directions in maps app...'),
        duration: Duration(seconds: 2),
      ),
    );
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

  void _contactProvider(Booking booking) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calling provider...'),
        duration: Duration(seconds: 2),
      ),
    );
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