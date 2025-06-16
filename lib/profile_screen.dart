// Updated ProfileScreen with provider functionality
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/login_screen.dart';
import '../providers/profile_provider.dart';
import '../providers/provider_providers.dart';
import '../screens/become_provider_screen.dart';
import '../screens/provider_status_screen.dart';
import '../screens/charging_providers_screen.dart';
import '../screens/provider_dashboard_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the user info from provider
    final userInfo = ref.watch(userInfoProvider);
    
    // Create params tuple for the family provider
    final params = (
      userInfo['userName'] ?? '', 
      userInfo['userEmail'] ?? '', 
      userInfo['phoneNumber'] ?? ''
    );
    
    // Watch the profile state
    final profileState = ref.watch(profileProvider(params));
    
    // Watch profile stats
    final profileStats = ref.watch(profileStatsProvider);
    
    // Watch provider status
    final isProvider = ref.watch(isProviderProvider);
    final hasPendingRequest = ref.watch(hasPendingProviderRequestProvider);
    
    return Scaffold(
      body: profileState.isLoading
        ? const Center(child: CircularProgressIndicator())
        : CustomScrollView(
          slivers: [
            _buildAppBar(profileState),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Error message if any
                  if (profileState.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              profileState.errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildProfileInfo(context, ref, params, profileState),
                  _buildQuickStats(profileStats),
                  // Provider Section - NEW
                  _buildProviderSection(context, ref, isProvider, hasPendingRequest),
                  _buildPreferences(context, ref, params, profileState),
                  _buildVehicles(context, ref, params, profileState),
                  _buildAbout(context),
                  _buildLogoutButton(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      // Add refresh button
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(profileProvider(params).notifier).fetchProfileData(),
        backgroundColor: Colors.green.shade600,
        mini: true,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  // NEW: Provider Section
  // Add this enhanced provider section to your ProfileScreen

// Replace ONLY the _buildProviderSection method in your ProfileScreen
// Do NOT add the _buildQuickAccessCard method since it already exists

Widget _buildProviderSection(BuildContext context, WidgetRef ref, bool isProvider, bool hasPendingRequest) {
  return Card(
    margin: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.ev_station,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Charging Services',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        
        // Quick Access Cards for Charging Services (using existing method)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
           Expanded(
  child: _buildQuickAccessCard(
    context,
    'Find Stations',
    'Discover nearby charging points',
    Icons.search,
    Colors.blue,
    () {
      // Get user info from the provider
      final userInfo = ref.read(userInfoProvider);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChargingProvidersScreen(
            userName: userInfo['userName'] ?? 'User',
            userEmail: userInfo['userEmail'] ?? 'user@email.com',
          ),
        ),
      ).catchError((e) {
        print('Navigation error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening charging providers: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      });
    },
  ),
),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickAccessCard(
                  context,
                  'My Bookings',
                  'View charging bookings',
                  Icons.book_online,
                  Colors.purple,
                  () {
                    // Navigate using route name instead of direct import
                    Navigator.pushNamed(
                      context,
                      '/my-bookings',
                      arguments: {
                        'userName': 'User', // Get from your user provider
                        'userEmail': 'user@email.com', // Get from your user provider
                      },
                    ).catchError((e) {
                      // Show placeholder message if route doesn't exist
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('My bookings feature coming soon!'),
                          backgroundColor: Colors.purple.shade600,
                        ),
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Provider Status Section
        if (isProvider) ...[
          // User is an approved provider
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are an approved provider!',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.dashboard,
              color: Colors.blue.shade600,
            ),
            title: const Text('Provider Dashboard'),
            subtitle: const Text('Manage your charging station and bookings'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, '/provider-dashboard').catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Provider dashboard coming soon!'),
                    backgroundColor: Colors.blue.shade600,
                  ),
                );
              });
            },
          ),
          ListTile(
            leading: Icon(
              Icons.analytics,
              color: Colors.purple.shade600,
            ),
            title: const Text('View Provider Status'),
            subtitle: const Text('Check your provider profile and settings'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, '/provider-status');
            },
          ),
        ] else if (hasPendingRequest) ...[
          // User has a pending provider request
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your provider request is under review',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.visibility,
              color: Colors.orange.shade600,
            ),
            title: const Text('Check Request Status'),
            subtitle: const Text('View your provider request details and status'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, '/provider-status');
            },
          ),
        ] else ...[
          // User is not a provider and has no pending request
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Earn Money with Your EV Charger',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Join our provider network and start earning by offering EV charging services to other users.',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.add_business,
              color: Colors.green.shade600,
            ),
            title: const Text('Become a Provider'),
            subtitle: const Text('Start earning by providing EV charging services'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/become-provider');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: Colors.grey.shade600,
            ),
            title: const Text('Provider Benefits'),
            subtitle: const Text('Learn about earnings and benefits'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showProviderBenefitsDialog(context),
          ),
        ],
        const SizedBox(height: 8),
      ],
    ),
  );
}
// Add this helper method for quick access cards
Widget _buildQuickAccessCard(
  BuildContext context,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildAppBar(ProfileState state) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,

      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: AppTheme.gradientBackground,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Text(
                  state.userName.isNotEmpty 
                      ? state.userName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(
    BuildContext context, 
    WidgetRef ref, 
    (String, String, String) params, 
    ProfileState state
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            state.userName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.userEmail,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.phoneNumber,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          if (state.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  state.address,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              _showEditProfileDialog(context, ref, params, state);
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Edit Profile'),
          ),
        ],
      ),
    );
  }

Widget _buildQuickStats(ProfileStats stats) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard(
            'Total Swaps',
            stats.formattedTotalSwaps,
            Icons.battery_charging_full,
            Colors.blue,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Total Spent',
            stats.formattedTotalSpent,
            Icons.payments,
            Colors.green,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Active Bookings',
            stats.formattedActiveBookings,
            Icons.calendar_today,
            Colors.orange,
          ),
        ],
      ),
    ),
  );
}


  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 100,
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildPreferences(
      BuildContext context, WidgetRef ref, (String, String, String) params, ProfileState state) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          SwitchListTile(
            value: state.notificationsEnabled,
            onChanged: (value) {
              ref.read(profileProvider(params).notifier).toggleNotifications(value);
            },
            title: const Text('Notifications'),
            subtitle: const Text('Receive updates and alerts'),
            secondary: const Icon(Icons.notifications),
          ),
          SwitchListTile(
            value: state.locationEnabled,
            onChanged: (value) {
              ref.read(profileProvider(params).notifier).toggleLocation(value);
            },
            title: const Text('Location Services'),
            subtitle: const Text('Enable location tracking'),
            secondary: const Icon(Icons.location_on),
          ),
          SwitchListTile(
            value: state.darkModeEnabled,
            onChanged: (value) {
              ref.read(profileProvider(params).notifier).toggleDarkMode(value);
            },
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme'),
            secondary: const Icon(Icons.dark_mode),
          ),
          ListTile(
            title: const Text('Language'),
            subtitle: Text(state.selectedLanguage),
            leading: const Icon(Icons.language),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showLanguageSelector(context, ref, params, state),
          ),
          const Divider(),
          ListTile(
            title: const Text('Payment Methods'),
            leading: const Icon(Icons.payment),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to payment methods
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVehicles(
      BuildContext context, WidgetRef ref, (String, String, String) params, ProfileState state) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Vehicles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddVehicleDialog(context, ref, params),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = state.vehicles[index];
              return ListTile(
                leading: const Icon(Icons.electric_bike),
                title: Text(vehicle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditVehicleDialog(context, ref, params, index, vehicle),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _showDeleteVehicleDialog(context, ref, params, index),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAbout(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            title: const Text('About BatteryWala'),
            leading: const Icon(Icons.info),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Show about page
            },
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            leading: const Icon(Icons.privacy_tip),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Show privacy policy
            },
          ),
          ListTile(
            title: const Text('Terms of Service'),
            leading: const Icon(Icons.description),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Show terms of service
            },
          ),
          ListTile(
            title: const Text('Help & Support'),
            leading: const Icon(Icons.help),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Show help & support
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: () => _handleLogout(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red,
        ),
        child: const Text('Logout'),
      ),
    );
  }

  void _showProviderBenefitsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.ev_station, color: Colors.green.shade600),
            const SizedBox(width: 8),
            const Text('Provider Benefits'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBenefitItem('💰', 'Earn Money', 'Get paid for every charging session'),
            _buildBenefitItem('📅', 'Flexible Schedule', 'Set your own availability'),
            _buildBenefitItem('🎯', 'Easy Management', 'Simple dashboard to track earnings'),
            _buildBenefitItem('⭐', 'Build Reputation', 'Get rated by customers'),
            _buildBenefitItem('🔒', 'Secure Payments', 'Guaranteed payments through our platform'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BecomeProviderScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String emoji, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // All the existing methods remain the same...
  void _showLanguageSelector(
      BuildContext context, WidgetRef ref, (String, String, String) params, ProfileState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Select Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              state.languages.length,
              (index) => ListTile(
                title: Text(state.languages[index]),
                trailing: state.selectedLanguage == state.languages[index]
                    ? Icon(
                        Icons.check,
                        color: Colors.green.shade600,
                      )
                    : null,
                onTap: () {
                  ref.read(profileProvider(params).notifier).setLanguage(state.languages[index]);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVehicleDialog(
      BuildContext context, WidgetRef ref, (String, String, String) params) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Vehicle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Vehicle Name',
            hintText: 'e.g. Ather 450X',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(profileProvider(params).notifier).addVehicle(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditVehicleDialog(
      BuildContext context, WidgetRef ref, (String, String, String) params, int index, String currentVehicle) {
    final TextEditingController controller = TextEditingController(text: currentVehicle);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Vehicle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Vehicle Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(profileProvider(params).notifier).editVehicle(index, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

void _showDeleteVehicleDialog(
      BuildContext context, WidgetRef ref, (String, String, String) params, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: const Text('Are you sure you want to delete this vehicle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(profileProvider(params).notifier).removeVehicle(index);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    (String, String, String) params,
    ProfileState state,
  ) {
    // Controllers for form fields
    final nameController = TextEditingController(text: state.userName);
    final emailController = TextEditingController(text: state.userEmail);
    final phoneController = TextEditingController(text: state.phoneNumber);
    final addressController = TextEditingController(text: state.address);
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    
    // Form key for validation
    final formKey = GlobalKey<FormState>();
    
    // Show loading state
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        icon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        icon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        icon: Icon(Icons.phone),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        icon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Change Password (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: oldPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        icon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        // Only validate if new password is provided
                        if (newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        icon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (value) {
                        // Only validate if old password is provided
                        if (oldPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                          return 'Please enter a new password';
                        }
                        if (value != null && value.isNotEmpty && value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        // Set loading state
                        setState(() {
                          isLoading = true;
                        });

                        // Call the update profile method
                        final success = await ref.read(profileProvider(params).notifier).updateProfile(
                          name: nameController.text,
                          email: emailController.text,
                          phone: phoneController.text,
                          address: addressController.text,
                          oldPassword: oldPasswordController.text.isEmpty ? null : oldPasswordController.text,
                          newPassword: newPasswordController.text.isEmpty ? null : newPasswordController.text,
                        );

                        // Handle success/failure
                        if (success) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setState(() {
                            isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(state.errorMessage ?? 'Failed to update profile'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}