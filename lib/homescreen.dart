// Updated homescreen.dart with enhanced notifications and charging services - FIXED OVERFLOW
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:electric_battery_delivery_frontend/notification_screen.dart';
import 'package:electric_battery_delivery_frontend/in_transit_orders_screen.dart';
import 'package:electric_battery_delivery_frontend/providers/dashboard_provider.dart';
import 'package:electric_battery_delivery_frontend/providers/notification_provider.dart';
import 'package:electric_battery_delivery_frontend/station_detail_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/charging_providers_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/my_bookings_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/become_provider_screen.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).initDashboard(this);
      ref.read(enhancedNotificationProvider.notifier).fetchUnreadCount();
    });
  }

  Future<void> _refreshLocationOnly() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref.read(dashboardProvider.notifier).getUserLocation();
      if (ref.read(dashboardProvider).userLocation != null) {
        await ref.read(dashboardProvider.notifier).loadStations();
      }
    } catch (e) {
      print('Error refreshing location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _navigateToInTransitOrders() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const InTransitOrdersScreen(),
        ),
      );
    } catch (e) {
      print('Error navigating to in-transit orders: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error navigating to in-transit orders: $e'),
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

  void _goToNotificationScreen() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const EnhancedNotificationScreen(),
        ),
      ).then((_) {
        if (mounted) {
          ref.read(enhancedNotificationProvider.notifier).fetchUnreadCount();
        }
      });
    } catch (e) {
      print('Error navigating to notification screen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final filters = ref.watch(filtersProvider);
    final userInfo = ref.watch(userInfoProvider);
    final enhancedNotificationState = ref.watch(enhancedNotificationProvider);

    return Scaffold(
      body: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: AppTheme.gradientBackground,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome,',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            userInfo['userName'] ?? 'User',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (dashboardState.userLocation != null)
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '📍 ${_formatLocation(dashboardState.userLocation!)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: _refreshLocationOnly,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.refresh,
                                      size: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // WebSocket status indicator (new)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: enhancedNotificationState.isWebSocketConnected
                                ? Colors.green.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                enhancedNotificationState.isWebSocketConnected
                                    ? Icons.wifi
                                    : Icons.wifi_off,
                                size: 10,
                                color: enhancedNotificationState.isWebSocketConnected
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                enhancedNotificationState.isWebSocketConnected ? 'Live' : 'Off',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: enhancedNotificationState.isWebSocketConnected
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: _navigateToInTransitOrders,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.local_shipping,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _goToNotificationScreen,
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Stack(
                                children: [
                                  Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.green.shade700,
                                    size: 24,
                                  ),
                                  // Enhanced notification badge with real-time count
                                  if (enhancedNotificationState.unreadCount > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: enhancedNotificationState.realtimeNotifications.isNotEmpty
                                              ? Colors.red
                                              : Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Center(
                                          child: Text(
                                            enhancedNotificationState.unreadCount > 9
                                                ? '9+'
                                                : enhancedNotificationState.unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Real-time indicator dot
                                  if (enhancedNotificationState.realtimeNotifications.isNotEmpty)
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.5),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile clicked')),
                            );
                          },
                          child: Hero(
                            tag: 'profile_avatar',
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.green.shade100,
                              child: Text(
                                userInfo['userName']?.isNotEmpty == true
                                  ? userInfo['userName']![0].toUpperCase()
                                  : 'U',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Enhanced notification status banner
              if (!enhancedNotificationState.isWebSocketConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.orange.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.orange.shade800, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Real-time notifications offline: ${enhancedNotificationState.webSocketStatus}',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(enhancedNotificationProvider.notifier).reconnectWebSocket();
                        },
                        child: Text(
                          'Reconnect',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Real-time notification banner (new feature)
              if (enhancedNotificationState.realtimeNotifications.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${enhancedNotificationState.realtimeNotifications.length} new live notification(s)',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _goToNotificationScreen,
                        child: Text(
                          'View',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: InkWell(
                  onTap: _navigateToInTransitOrders,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_shipping,
                        size: 18,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have orders in transit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.orange.shade800,
                      ),
                    ],
                  ),
                ),
              ),

              // FIXED: Wrap remaining content in Expanded and SingleChildScrollView
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NEW: Charging Services Section
                      _buildChargingServicesSection(context),

                      Container(
                        height: 32,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.zero,
                          itemCount: filters.length,
                          itemBuilder: (context, index) {
                            final filter = filters[index];
                            final isSelected = filter == dashboardState.selectedFilter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  ref.read(dashboardProvider.notifier).updateSelectedFilter(filter);
                                },
                                backgroundColor: Colors.white,
                                selectedColor: Colors.green.shade100,
                                checkmarkColor: Colors.green.shade700,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              ),
                            );
                          },
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: dashboardState.searchController,
                            decoration: InputDecoration(
                              hintText: 'Search stations...',
                              hintStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.search, size: 16),
                              suffixIcon: dashboardState.searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        ref.read(dashboardProvider.notifier).clearSearch();
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 12),
                            onChanged: (value) {
                              ref.read(dashboardProvider.notifier).updateSearchQuery(value);
                            },
                          ),
                        ),
                      ),

                      if (dashboardState.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dashboardState.errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    ref.read(dashboardProvider.notifier).state =
                                      ref.read(dashboardProvider.notifier).state.copyWith(clearError: true);
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (dashboardState.userLocation == null || dashboardState.errorMessage?.contains('location') == true)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ElevatedButton.icon(
                            onPressed: _refreshLocationOnly,
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text('Refresh Location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),

                      if (dashboardState.availableStations.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Available Stations',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    ref.read(dashboardProvider.notifier).updateSelectedFilter('Available');
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Text(
                                      'View All',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // FIXED: Give stations list a proper height constraint
                      SizedBox(
                        height: 400,
                        child: RefreshIndicator(
                          onRefresh: () async {
                            await ref.read(dashboardProvider.notifier).refreshStations();
                            await ref.read(enhancedNotificationProvider.notifier).fetchUnreadCount();
                          },
                          color: Colors.green.shade600,
                          child: dashboardState.isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                                ),
                              )
                            : dashboardState.filteredStations.isEmpty
                                ? _buildEmptyState()
                                : _buildStationsList(dashboardState),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced notification FAB
              FloatingActionButton(
                onPressed: _goToNotificationScreen,
                backgroundColor: enhancedNotificationState.realtimeNotifications.isNotEmpty
                    ? Colors.red.shade600
                    : Colors.blue.shade600,
                heroTag: 'notification_button',
                mini: true,
                child: Stack(
                  children: [
                    const Icon(Icons.notifications, color: Colors.white),
                    if (enhancedNotificationState.realtimeNotifications.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.yellow,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: _navigateToInTransitOrders,
                backgroundColor: Colors.orange.shade600,
                heroTag: 'transit_button',
                mini: true,
                child: const Icon(Icons.local_shipping, color: Colors.white),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: _refreshLocationOnly,
                backgroundColor: Colors.green.shade600,
                heroTag: 'refresh_button',
                mini: true,
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FIXED: Charging Services Section with proper constraints
  Widget _buildChargingServicesSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.ev_station,
                color: Colors.green.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Charging Services',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _navigateToChargingProviders(context),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildServiceCard(
                  'Find Providers',
                  'Discover nearby charging stations',
                  Icons.ev_station,
                  Colors.blue,
                  () => _navigateToChargingProviders(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildServiceCard(
                  'My Bookings',
                  'View charging bookings',
                  Icons.book_online,
                  Colors.purple,
                  () => _navigateToMyBookings(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildServiceCard(
                  'Quick Book',
                  'Book nearest available slot',
                  Icons.flash_on,
                  Colors.orange,
                  () => _quickBookChargingSlot(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildServiceCard(
                  'Become Provider',
                  'Start earning with your charger',
                  Icons.add_business,
                  Colors.green,
                  () => _navigateToBecomeProvider(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FIXED: More compact service card
  Widget _buildServiceCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigation methods for charging services
  void _navigateToChargingProviders(BuildContext context) {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChargingProvidersScreen(
            userName: ref.read(userInfoProvider)['userName'] ?? 'User',
            userEmail: ref.read(userInfoProvider)['userEmail'] ?? '',
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to charging providers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error navigating to charging providers'),
          backgroundColor: Colors.red.shade600,
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

  void _navigateToMyBookings(BuildContext context) {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyBookingsScreen(
            userName: ref.read(userInfoProvider)['userName'] ?? 'User',
            userEmail: ref.read(userInfoProvider)['userEmail'] ?? '',
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to my bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error navigating to bookings'),
          backgroundColor: Colors.red.shade600,
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

  void _quickBookChargingSlot(BuildContext context) {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Show quick booking modal
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildQuickBookingModal(context),
      );
    } catch (e) {
      print('Error showing quick booking: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _navigateToBecomeProvider(BuildContext context) {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BecomeProviderScreen(),
        ),
      );
    } catch (e) {
      print('Error navigating to become provider screen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error navigating to become provider screen'),
          backgroundColor: Colors.red.shade600,
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

  Widget _buildQuickBookingModal(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: Colors.orange.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Book Charging Slot',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Vehicle Type Selection
                  _buildQuickBookingSection(
                    'Select Vehicle Type',
                    Icons.directions_car,
                    [
                      _buildVehicleTypeChip('Car', Icons.directions_car),
                      _buildVehicleTypeChip('Bike', Icons.two_wheeler),
                      _buildVehicleTypeChip('Scooter', Icons.electric_scooter),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Charger Type Selection
                  _buildQuickBookingSection(
                    'Charger Type',
                    Icons.electrical_services,
                    [
                      _buildChargerTypeChip('Fast Charging', Icons.flash_on),
                      _buildChargerTypeChip('Normal', Icons.battery_charging_full),
                      _buildChargerTypeChip('Any Available', Icons.help_outline),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Time Selection
                  _buildQuickBookingSection(
                    'Preferred Time',
                    Icons.access_time,
                    [
                      _buildTimeChip('Now', Icons.schedule),
                      _buildTimeChip('1 Hour', Icons.schedule),
                      _buildTimeChip('Custom', Icons.edit_calendar),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showBookingConfirmation(context);
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Find Slots'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBookingSection(String title, IconData icon, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }

  Widget _buildVehicleTypeChip(String label, IconData icon) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: false,
      onSelected: (selected) {
        // Handle selection
      },
    );
  }

  Widget _buildChargerTypeChip(String label, IconData icon) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: false,
      onSelected: (selected) {
        // Handle selection
      },
    );
  }

  Widget _buildTimeChip(String label, IconData icon) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: false,
      onSelected: (selected) {
        // Handle selection
      },
    );
  }

  void _showBookingConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 8),
            const Text('Searching...'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            const Text('Finding the best charging slots for you...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to full providers screen when implemented
              _navigateToChargingProviders(context);
            },
            child: const Text('View All Providers'),
          ),
        ],
      ),
    );
  }

  String _formatLocation(Position position) {
    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }
  
  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.battery_alert,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No stations found',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Try adjusting your search or filters to find more options',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Material(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {
                        ref.read(dashboardProvider.notifier).refreshStations();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Refresh Stations',
                              style: TextStyle(
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: _refreshLocationOnly,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Update Location',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.orange.shade600,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _navigateToInTransitOrders,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_shipping, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'View In-Transit Orders',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStationsList(DashboardState dashboardState) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: dashboardState.filteredStations.length,
      itemBuilder: (context, index) {
        final station = dashboardState.filteredStations[index];
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: dashboardState.animationController!,
            curve: Interval(
              (index / dashboardState.filteredStations.length),
              ((index + 1) / dashboardState.filteredStations.length),
              curve: Curves.easeOut,
            ),
          )),
          child: _buildStationCard(station),
        );
      },
    );
  }

  Widget _buildStationCard(Station station) {
    final isAvailable = station.status.toLowerCase() == 'available';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _showStationDetails(station);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                image: station.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(station.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: station.imageUrl.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.battery_charging_full,
                        size: 40,
                        color: Colors.green.shade600,
                      ),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          station.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.getStatusColor(station.status)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          station.status,
                          style: TextStyle(
                            color: AppTheme.getStatusColor(station.status),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          station.address,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${station.etaMinutes} mins',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.battery_5_bar,
                                size: 12,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${station.availableBatteries} Available',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${station.price}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Material(
                        color: isAvailable ? Colors.green.shade600 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          onTap: isAvailable
                            ? () {
                                _showStationDetails(station);
                              }
                            : null,
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 100,
                            height: 28,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.flash_on,
                                  size: 12,
                                  color: Colors.white
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Swap Now',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  )
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStationDetails(Station station) {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StationDetailScreen(station: station),
        ),
      );
    } catch (e) {
      print('Error navigating to station details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}