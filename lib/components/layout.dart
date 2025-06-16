// layout.dart - Enhanced with real provider status checking
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core screens (keep existing imports as per your structure)
import 'package:electric_battery_delivery_frontend/homescreen.dart';
import 'package:electric_battery_delivery_frontend/order_history_screen.dart';
import 'package:electric_battery_delivery_frontend/profile_screen.dart';

// Customer charging screens
import 'package:electric_battery_delivery_frontend/screens/charging_providers_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/my_bookings_screen.dart';

// Provider screens (for approved providers)
import 'package:electric_battery_delivery_frontend/screens/provider_dashboard_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_bookings_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_slots_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_profile_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_analytics_screen.dart';

// Provider status and become provider screens
import 'package:electric_battery_delivery_frontend/screens/become_provider_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_status_screen.dart';

// Import your provider status provider
import 'package:electric_battery_delivery_frontend/providers/provider_providers.dart';
import 'package:electric_battery_delivery_frontend/models/provider_models.dart';

class Layout extends ConsumerStatefulWidget {
  final String userName;
  final String userEmail;
  final String phoneNumber;
  final int initialIndex;

  const Layout({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.phoneNumber,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<Layout> createState() => _LayoutState();
}

class _LayoutState extends ConsumerState<Layout> with TickerProviderStateMixin {
  late int _selectedIndex;
  late PageController _pageController;
  late AnimationController _modeToggleController;
  late AnimationController _tabChangeController;
  
  bool _isProviderMode = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    
    _modeToggleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _tabChangeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _modeToggleController.dispose();
    _tabChangeController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    _tabChangeController.forward().then((_) {
      _tabChangeController.reset();
    });
    
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _toggleProviderMode() {
    _modeToggleController.forward().then((_) {
      _modeToggleController.reset();
    });
    
    setState(() {
      _isProviderMode = !_isProviderMode;
      _selectedIndex = 0; // Reset to first tab
    });
    
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerStatusAsync = ref.watch(providerRequestStatusProvider);

    return providerStatusAsync.when(
      data: (status) => _buildMainLayout(status),
      loading: () => _buildLoadingScreen(),
      error: (error, stack) => _buildMainLayout(null), // Show customer layout on error
    );
  }

  Widget _buildMainLayout(ProviderRequestStatus? providerStatus) {
    final providerState = _getProviderState(providerStatus);
    final navigationConfig = _getNavigationConfig(providerState);
    
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: navigationConfig.pages,
      ),
      bottomNavigationBar: _buildBottomNavigation(navigationConfig, providerState),
      floatingActionButton: _buildFloatingActionButton(navigationConfig, providerState),
      floatingActionButtonLocation: _getFABLocation(navigationConfig),
    );
  }

  ProviderState _getProviderState(ProviderRequestStatus? status) {
    if (status == null) {
      return ProviderState(
        hasRequest: false,
        isApproved: false,
        isPending: false,
        isRejected: false,
        canToggleMode: false,
        shouldShowProviderCTA: true,
      );
    }

    switch (status.status.toUpperCase()) {
      case 'APPROVED':
        return ProviderState(
          hasRequest: true,
          isApproved: true,
          isPending: false,
          isRejected: false,
          canToggleMode: true,
          shouldShowProviderCTA: false,
          requestStatus: status,
        );
      case 'PENDING':
        return ProviderState(
          hasRequest: true,
          isApproved: false,
          isPending: true,
          isRejected: false,
          canToggleMode: false,
          shouldShowProviderCTA: false,
          requestStatus: status,
        );
      case 'REJECTED':
        return ProviderState(
          hasRequest: true,
          isApproved: false,
          isPending: false,
          isRejected: true,
          canToggleMode: false,
          shouldShowProviderCTA: true,
          requestStatus: status,
        );
      default:
        return ProviderState(
          hasRequest: false,
          isApproved: false,
          isPending: false,
          isRejected: false,
          canToggleMode: false,
          shouldShowProviderCTA: true,
        );
    }
  }

  NavigationConfig _getNavigationConfig(ProviderState providerState) {
    if (_isProviderMode && providerState.isApproved) {
      return _getProviderNavigation();
    }
    return _getCustomerNavigation(providerState);
  }

  NavigationConfig _getCustomerNavigation(ProviderState providerState) {
    return NavigationConfig(
      mode: NavigationMode.customer,
      tabs: [
        NavigationTab(
          index: 0,
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'Home',
          color: Colors.green,
        ),
        NavigationTab(
          index: 1,
          icon: Icons.ev_station_outlined,
          activeIcon: Icons.ev_station,
          label: 'Charging',
          color: Colors.blue,
        ),
        NavigationTab(
          index: 2,
          icon: Icons.book_outlined,
          activeIcon: Icons.book,
          label: 'Bookings',
          color: Colors.purple,
        ),
        NavigationTab(
          index: 3,
          icon: Icons.history_outlined,
          activeIcon: Icons.history,
          label: 'Orders',
          color: Colors.orange,
        ),
        NavigationTab(
          index: 4,
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Profile',
          color: Colors.grey,
        ),
      ],
      pages: [
        const DashboardScreen(),
        ChargingProvidersScreen(
          userName: widget.userName,
          userEmail: widget.userEmail,
        ),
        MyBookingsScreen(
          userName: widget.userName,
          userEmail: widget.userEmail,
        ),
        OrderHistoryScreen(
          userName: widget.userName,
          userEmail: widget.userEmail,
        ),
        const ProfileScreen(),
      ],
      providerState: providerState,
      fabType: FABType.qrScanner,
    );
  }

  NavigationConfig _getProviderNavigation() {
    return NavigationConfig(
      mode: NavigationMode.provider,
      tabs: [
        NavigationTab(
          index: 0,
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'Dashboard',
          color: Colors.green,
        ),
        NavigationTab(
          index: 1,
          icon: Icons.book_online_outlined,
          activeIcon: Icons.book_online,
          label: 'Bookings',
          color: Colors.blue,
        ),
        NavigationTab(
          index: 2,
          icon: Icons.schedule_outlined,
          activeIcon: Icons.schedule,
          label: 'Slots',
          color: Colors.orange,
        ),
        NavigationTab(
          index: 3,
          icon: Icons.analytics_outlined,
          activeIcon: Icons.analytics,
          label: 'Analytics',
          color: Colors.purple,
        ),
        NavigationTab(
          index: 4,
          icon: Icons.business_outlined,
          activeIcon: Icons.business,
          label: 'Profile',
          color: Colors.grey,
        ),
      ],
      pages: [
        const ProviderDashboardScreen(),
        const ProviderBookingsScreen(),
        const ProviderSlotsScreen(),
        const ProviderAnalyticsScreen(),
        const ProviderProfileScreen(),
      ],
      providerState: ProviderState(
        hasRequest: true,
        isApproved: true,
        isPending: false,
        isRejected: false,
        canToggleMode: true,
        shouldShowProviderCTA: false,
      ),
      fabType: FABType.providerActions,
    );
  }

  Widget _buildBottomNavigation(NavigationConfig config, ProviderState providerState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Provider status banner (for pending/rejected requests)
            if (providerState.isPending)
              _buildProviderStatusBanner(
                'Provider Request Pending',
                'Your application is being reviewed',
                Colors.orange,
                Icons.hourglass_empty,
                () => _navigateToProviderStatus(),
              ),
            
            if (providerState.isRejected)
              _buildProviderStatusBanner(
                'Provider Request Rejected',
                'Tap to view details and reapply',
                Colors.red,
                Icons.error_outline,
                () => _navigateToProviderStatus(),
              ),

            // Provider CTA (for users without requests)
            if (providerState.shouldShowProviderCTA && !providerState.hasRequest)
              _buildProviderCTA(),
            
            // Mode toggle (only for approved providers)
            if (providerState.canToggleMode)
              _buildModeToggle(),
            
            // Navigation tabs
            _buildNavigationTabs(config.tabs),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderStatusBanner(String title, String subtitle, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCTA() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToBecomeProvider(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade400],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.business_center,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Become a Provider',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Start earning by offering charging services',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeButton(
              'Customer',
              Icons.person,
              !_isProviderMode,
              'Browse and book services',
            ),
            _buildModeButton(
              'Provider',
              Icons.business,
              _isProviderMode,
              'Manage your station',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, IconData icon, bool isSelected, String subtitle) {
    return GestureDetector(
      onTap: isSelected ? null : _toggleProviderMode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTabs(List<NavigationTab> tabs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs.map((tab) => _buildNavItem(tab)).toList(),
      ),
    );
  }

  Widget _buildNavItem(NavigationTab tab) {
    final isSelected = _selectedIndex == tab.index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(tab.index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? tab.color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? tab.activeIcon : tab.icon,
                  key: ValueKey('${tab.index}_${isSelected}'),
                  color: isSelected ? tab.color : Colors.grey.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? tab.color : Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(NavigationConfig config, ProviderState providerState) {
    switch (config.fabType) {
      case FABType.qrScanner:
        return FloatingActionButton(
          onPressed: _showQRScanner,
          backgroundColor: Colors.green.shade600,
          heroTag: 'qr_scanner',
          tooltip: 'Scan QR Code',
          child: const Icon(Icons.qr_code_scanner, color: Colors.white),
        );
      
      case FABType.providerActions:
        return FloatingActionButton(
          onPressed: _showProviderQuickActions,
          backgroundColor: Colors.blue.shade600,
          heroTag: 'provider_actions',
          tooltip: 'Quick Actions',
          child: const Icon(Icons.add, color: Colors.white),
        );
      
      case FABType.none:
        return const SizedBox.shrink();
    }
  }

  FloatingActionButtonLocation _getFABLocation(NavigationConfig config) {
    return config.tabs.length > 4 
        ? FloatingActionButtonLocation.centerDocked 
        : FloatingActionButtonLocation.endFloat;
  }

  // Navigation methods
  void _navigateToBecomeProvider() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BecomeProviderScreen(),
      ),
    );
  }

  void _navigateToProviderStatus() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProviderStatusScreen(),
      ),
    );
  }

  void _showQRScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildQRScannerModal(),
    );
  }

  void _showProviderQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildProviderActionsModal(),
    );
  }

  Widget _buildQRScannerModal() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: Colors.green.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        'Point camera at station QR code',
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
          ),
          
          // Scanner area placeholder
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green.shade400, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                          color: Colors.green.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Position QR code within the frame',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showManualEntryDialog();
                    },
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Enter Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderActionsModal() {
    final actions = [
      ProviderAction('Toggle Station', Icons.power_settings_new, Colors.orange, 'Turn on/off'),
      ProviderAction('Add Time Slot', Icons.add_circle_outline, Colors.green, 'Set availability'),
      ProviderAction('View Analytics', Icons.analytics, Colors.purple, 'See performance'),
      ProviderAction('Update Profile', Icons.edit, Colors.blue, 'Edit details'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.flash_on, color: Colors.blue.shade600, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: actions.map((action) => _buildActionTile(action)).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(ProviderAction action) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _handleProviderAction(action);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: action.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: action.color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: action.color, size: 28),
            const SizedBox(height: 8),
            Text(
              action.title,
              style: TextStyle(
                color: action.color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              action.subtitle,
              style: TextStyle(
                color: action.color.withOpacity(0.7),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Station Code'),
        content: const TextField(
          decoration: InputDecoration(
            hintText: 'Enter QR code manually...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _handleProviderAction(ProviderAction action) {
    switch (action.title) {
      case 'Toggle Station':
        // Handle station toggle
        break;
      case 'Add Time Slot':
        _onItemTapped(2); // Go to slots tab
        break;
      case 'View Analytics':
        _onItemTapped(3); // Go to analytics tab
        break;
      case 'Update Profile':
        _onItemTapped(4); // Go to profile tab
        break;
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
            const SizedBox(height: 20),
            Text(
              'Checking your provider status...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Supporting classes and enums
class NavigationConfig {
  final NavigationMode mode;
  final List<NavigationTab> tabs;
  final List<Widget> pages;
  final ProviderState providerState;
  final FABType fabType;

  NavigationConfig({
    required this.mode,
    required this.tabs,
    required this.pages,
    required this.providerState,
    required this.fabType,
  });
}

class NavigationTab {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  NavigationTab({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

class ProviderState {
  final bool hasRequest;
  final bool isApproved;
  final bool isPending;
  final bool isRejected;
  final bool canToggleMode;
  final bool shouldShowProviderCTA;
  final ProviderRequestStatus? requestStatus;

  ProviderState({
    required this.hasRequest,
    required this.isApproved,
    required this.isPending,
    required this.isRejected,
    required this.canToggleMode,
    required this.shouldShowProviderCTA,
    this.requestStatus,
  });
}

class ProviderAction {
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;

  ProviderAction(this.title, this.icon, this.color, this.subtitle);
}

enum NavigationMode { customer, provider }
enum FABType { qrScanner, providerActions, none }