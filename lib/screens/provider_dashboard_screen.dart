// lib/screens/provider_dashboard_screen.dart - Enhanced with debug information and better error handling
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/provider_models.dart';
import '../providers/provider_providers.dart';
import '../components/app_theme.dart';
import 'provider_bookings_screen.dart';
import 'provider_slots_screen.dart';
import 'provider_profile_screen.dart';
import 'provider_analytics_screen.dart';

class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(providerAnalyticsProvider);
    final profileAsync = ref.watch(providerProfileProvider);
    final pendingBookingsAsync = ref.watch(pendingBookingsCountProvider);

    // Debug: Print provider states
    print('=== PROVIDER DASHBOARD DEBUG ===');
    print('Analytics State: ${analyticsAsync.runtimeType}');
    print('Profile State: ${profileAsync.runtimeType}');
    print('Pending Bookings State: ${pendingBookingsAsync.runtimeType}');
    
    analyticsAsync.when(
      data: (data) => print('Analytics Data: $data'),
      loading: () => print('Analytics: Loading...'),
      error: (error, stack) => print('Analytics Error: $error'),
    );
    
    profileAsync.when(
      data: (data) => print('Profile Data: ${data?.businessName ?? 'No name'} - Active: ${data?.isActive}'),
      loading: () => print('Profile: Loading...'),
      error: (error, stack) => print('Profile Error: $error'),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, profileAsync),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Debug Information Card (only in debug mode)
                  if (true) // Set to false in production
                    _buildDebugCard(analyticsAsync, profileAsync, pendingBookingsAsync),
                  
                  // Quick Stats
                  _buildQuickStatsSection(context, analyticsAsync, pendingBookingsAsync),
                  
                  const SizedBox(height: 16),
                  
                  // Quick Actions
                  _buildQuickActions(context),
                  
                  const SizedBox(height: 16),
                  
                  // Recent Activity
                  _buildRecentActivitySection(context, ref),
                  
                  const SizedBox(height: 16),
                  
                  // Station Status
                  _buildStationStatus(profileAsync),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProviderSlotsScreen(),
            ),
          );
        },
        backgroundColor: Colors.green.shade600,
        icon: const Icon(Icons.schedule, color: Colors.white),
        label: const Text(
          'Manage Slots',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDebugCard(
    AsyncValue<ProviderAnalytics?> analyticsAsync,
    AsyncValue<ProviderProfile?> profileAsync,
    AsyncValue<int> pendingBookingsAsync,
  ) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Debug Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDebugRow('Analytics', _getStateDescription(analyticsAsync)),
            _buildDebugRow('Profile', _getStateDescription(profileAsync)),
            _buildDebugRow('Pending Bookings', _getStateDescription(pendingBookingsAsync)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      return ElevatedButton.icon(
                        onPressed: () {
                          // Refresh all providers
                          ref.invalidate(providerAnalyticsProvider);
                          ref.invalidate(providerProfileProvider);
                          ref.invalidate(pendingBookingsCountProvider);
                          ref.invalidate(recentProviderBookingsProvider);
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh All', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _getStateDescription(AsyncValue<dynamic> state) {
    return state.when(
      data: (data) {
        if (data == null) return 'Data: null';
        if (data is ProviderAnalytics) {
          return 'Data: ${data.totalBookings} bookings, ₹${data.totalEarnings.toStringAsFixed(0)}';
        }
        if (data is ProviderProfile) {
          return 'Data: ${data.businessName ?? 'No name'} (${data.isActive ? 'Active' : 'Inactive'})';
        }
        if (data is int) {
          return 'Data: $data';
        }
        return 'Data: ${data.toString()}';
      },
      loading: () => 'Loading...',
      error: (error, stack) => 'Error: ${error.toString().substring(0, 50)}...',
    );
  }

  Widget _buildAppBar(BuildContext context, AsyncValue<ProviderProfile?> profileAsync) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: AppTheme.gradientBackground,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.ev_station,
                    size: 40,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                profileAsync.when(
                  data: (profile) => Column(
                    children: [
                      Text(
                        profile?.businessName ?? 'My Charging Station',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Provider Dashboard',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Text(
                    'Loading Profile...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  error: (error, __) => Column(
                    children: [
                      const Text(
                        'Provider Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Error loading profile',
                        style: TextStyle(
                          color: Colors.red.shade200,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProviderProfileScreen(),
              ),
            );
          },
          icon: const Icon(Icons.settings, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildQuickStatsSection(
    BuildContext context, 
    AsyncValue<ProviderAnalytics?> analyticsAsync, 
    AsyncValue<int> pendingBookingsAsync
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProviderAnalyticsScreen(),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: analyticsAsync.when(
                    data: (analytics) {
                      print('Building analytics stat card with data: $analytics');
                      return _buildStatCard(
                        'Total Bookings',
                        analytics?.totalBookings.toString() ?? '0',
                        Icons.book_online,
                        Colors.blue,
                      );
                    },
                    loading: () {
                      print('Building loading stat card for analytics');
                      return _buildLoadingStatCard('Analytics');
                    },
                    error: (error, __) {
                      print('Building error stat card for analytics: $error');
                      return _buildErrorStatCard('Analytics Error');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: pendingBookingsAsync.when(
                    data: (count) {
                      print('Building pending bookings stat card with count: $count');
                      return _buildStatCard(
                        'Pending',
                        count.toString(),
                        Icons.hourglass_empty,
                        Colors.orange,
                        urgent: count > 0,
                      );
                    },
                    loading: () {
                      print('Building loading stat card for pending bookings');
                      return _buildLoadingStatCard('Pending');
                    },
                    error: (error, __) {
                      print('Building error stat card for pending bookings: $error');
                      return _buildErrorStatCard('Pending Error');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: analyticsAsync.when(
                    data: (analytics) => _buildStatCard(
                      'Total Earnings',
                      '₹${analytics?.totalEarnings.toStringAsFixed(0) ?? '0'}',
                      Icons.currency_rupee,
                      Colors.green,
                    ),
                    loading: () => _buildLoadingStatCard('Earnings'),
                    error: (error, __) => _buildErrorStatCard('Earnings Error'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: analyticsAsync.when(
                    data: (analytics) => _buildStatCard(
                      'Rating',
                      '${analytics?.averageRating.toStringAsFixed(1) ?? '0.0'} ⭐',
                      Icons.star,
                      Colors.amber,
                    ),
                    loading: () => _buildLoadingStatCard('Rating'),
                    error: (error, __) => _buildErrorStatCard('Rating Error'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool urgent = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: urgent ? color.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: urgent ? color : Colors.grey.shade200,
          width: urgent ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon, 
            color: color, 
            size: urgent ? 28 : 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: urgent ? 22 : 20,
              fontWeight: FontWeight.bold,
              color: urgent ? color : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStatCard([String? subtitle]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 8),
          Text(subtitle ?? 'Loading...'),
        ],
      ),
    );
  }

  Widget _buildErrorStatCard([String? subtitle]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error, color: Colors.red.shade400, size: 24),
          const SizedBox(height: 8),
          Text(
            subtitle ?? 'Error',
            style: TextStyle(color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'View Bookings',
                    Icons.calendar_today,
                    Colors.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProviderBookingsScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Manage Slots',
                    Icons.schedule,
                    Colors.green,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProviderSlotsScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Edit Profile',
                    Icons.edit,
                    Colors.orange,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProviderProfileScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Analytics',
                    Icons.analytics,
                    Colors.purple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProviderAnalyticsScreen(),
                      ),
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

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, WidgetRef ref) {
    final recentBookingsAsync = ref.watch(recentProviderBookingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProviderBookingsScreen(),
                    ),
                  ),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            recentBookingsAsync.when(
              data: (bookings) {
                print('Recent bookings data: ${bookings.length} bookings');
                if (bookings.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No recent activity',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: bookings.take(3).map((booking) => _buildActivityTile(booking)).toList(),
                );
              },
              loading: () {
                print('Recent bookings: Loading...');
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              },
              error: (error, stack) {
                print('Recent bookings error: $error');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load recent activity',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          error.toString(),
                          style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(ProviderBooking booking) {
    Color statusColor = _getStatusColor(booking.status);
    IconData statusIcon = _getStatusIcon(booking.status);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.1),
        child: Icon(statusIcon, color: statusColor, size: 20),
      ),
      title: Text(booking.userName),
      subtitle: Text('${booking.vehicleType} • ${booking.timeSlot}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${booking.estimatedAmount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            booking.status,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationStatus(AsyncValue<ProviderProfile?> profileAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Station Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            profileAsync.when(
              data: (profile) {
                if (profile == null) {
                  print('Profile is null in station status');
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Profile data not available',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  );
                }
                
                print('Profile data available: ${profile.businessName}, Active: ${profile.isActive}');
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        profile.isActive ? Icons.check_circle : Icons.cancel,
                        color: profile.isActive ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        profile.isActive ? 'Station Active' : 'Station Inactive',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: profile.isActive ? Colors.green : Colors.red,
                        ),
                      ),
                      subtitle: Text(
                        profile.isActive ? 'Accepting new bookings' : 'Not accepting bookings',
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.location_on,
                        color: Colors.blue.shade600,
                      ),
                      title: Text(profile.address),
                      subtitle: Text('${profile.chargerType} • ${profile.vehicleTypes.join(", ")}'),
                    ),
                  ],
                );
              },
              loading: () {
                print('Profile loading in station status');
                return const Center(child: CircularProgressIndicator());
              },
              error: (error, stack) {
                print('Profile error in station status: $error');
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load station status',
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error.toString(),
                        style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
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
}