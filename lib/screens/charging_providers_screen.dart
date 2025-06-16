// Complete Fixed Charging Providers Screen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/models/charging_provider_model.dart';
import 'package:electric_battery_delivery_frontend/providers/live_charging_provider.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_details_screen.dart';

class ChargingProvidersScreen extends ConsumerStatefulWidget {
  final String userName;
  final String userEmail;

  const ChargingProvidersScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  ConsumerState<ChargingProvidersScreen> createState() => _ChargingProvidersScreenState();
}

class _ChargingProvidersScreenState extends ConsumerState<ChargingProvidersScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late TextEditingController _searchController;
  late ScrollController _scrollController;
  
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isLoadingLocation = false;
  Position? _currentPosition;
  double _searchRadius = 10.0;
  String _selectedChargerType = 'All';
  String _selectedVehicleType = 'All';
  double _minRating = 0.0;
  double _maxRate = 500.0; // FIXED: Changed from 1000.0 to 500.0 to match slider max
  List<String> _selectedAmenities = [];

  final List<String> _filters = ['All', 'Available Now'];
  final List<String> _chargerTypes = ['All', 'Type 2 AC', 'CCS DC', 'CHAdeMO', 'Tesla Supercharger'];
  final List<String> _vehicleTypes = ['All', 'Car', 'Bike', 'Scooter', 'Bus'];
  final List<String> _availableAmenities = ['WiFi', 'Parking', 'Restroom', 'Cafe', 'ATM', 'Food Court', 'Shopping', 'Garden'];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _scrollController.addListener(_onScroll);
    
    // Enhanced listener for debugging
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen<ChargingProviderState>(chargingProviderProvider, (previous, next) {
        print('🔄 Provider state changed:');
        print('   - Loading: ${next.isLoading}');
        print('   - Providers count: ${next.providers.length}');
        print('   - Error: ${next.errorMessage}');
        print('   - Authenticated: ${next.isAuthenticated}');
        
        // Log each provider details
        if (next.providers.isNotEmpty) {
          print('📋 Provider details:');
          for (int i = 0; i < next.providers.length; i++) {
            final provider = next.providers[i];
            print('   ${i + 1}. ${provider.businessName ?? 'Unknown'}');
            print('      - Address: ${provider.address ?? 'No address'}');
            print('      - Slots: ${provider.availableSlots ?? 0}/${provider.totalSlots ?? 0}');
            print('      - Rate: ₹${provider.ratePerHour ?? 0}/hr');
            print('      - Distance: ${provider.distance ?? 0} km');
            print('      - Rating: ${provider.rating ?? 0}');
            print('      - Amenities: ${provider.amenities ?? []}');
          }
        }
        
        if (next.errorMessage != null) {
          print('❌ Error details: ${next.errorMessage}');
        }
      });
    });
    
    _getCurrentLocation();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(chargingProviderProvider.notifier).loadMoreProviders();
    }
  }

  Future<void> _getCurrentLocation() async {
    print('🔍 Getting current location...');
    setState(() => _isLoadingLocation = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      print('📍 Current Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

      if (_currentPosition != null) {
        await _loadProviders();
      }
    } catch (e) {
      print('❌ Location Error: $e');
      if (mounted) {
        _showLocationError(e.toString());
      }
    } finally {
      setState(() => _isLoadingLocation = false);
      _animationController.forward();
    }
  }

  Future<void> _loadProviders({bool refresh = false}) async {
    print('🔍 _loadProviders called - refresh: $refresh');
    
    if (_currentPosition == null) {
      print('❌ No current position available');
      return;
    }

    print('📍 Current position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

    // Check authentication status first
    final loginState = ref.read(loginProvider);
    print('🔐 Login state - token empty: ${loginState.user.token.isEmpty}');
    
    if (loginState.user.token.isEmpty) {
      print('❌ No auth token, showing auth dialog');
      _showAuthenticationDialog();
      return;
    }

    print('✅ Auth token present, proceeding with API call');

    try {
      print('🚀 Starting API call with params:');
      print('   - Latitude: ${_currentPosition!.latitude}');
      print('   - Longitude: ${_currentPosition!.longitude}');
      print('   - Radius: $_searchRadius');
      
      await ref.read(chargingProviderProvider.notifier).loadProvidersNearLocation(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radius: _searchRadius,
        chargerType: _selectedChargerType != 'All' ? _selectedChargerType : null,
        vehicleType: _selectedVehicleType != 'All' ? _selectedVehicleType : null,
        minRating: _minRating > 0 ? _minRating : null,
        maxRate: _maxRate < 500 ? _maxRate : null, // FIXED: Changed from 1000 to 500
        amenities: _selectedAmenities.isNotEmpty ? _selectedAmenities : null,
        refresh: refresh,
      );
      
      // Check the state after the call
      final providerState = ref.read(chargingProviderProvider);
      print('📊 Provider state after API call:');
      print('   - Loading: ${providerState.isLoading}');
      print('   - Providers count: ${providerState.providers.length}');
      print('   - Error: ${providerState.errorMessage}');
      print('   - Authenticated: ${providerState.isAuthenticated}');
      
      if (providerState.providers.isNotEmpty) {
        print('👥 First provider: ${providerState.providers.first.businessName}');
      }
      
    } catch (e) {
      print('💥 Error in _loadProviders: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading providers: $e');
      }
    }
  }

  void _showLocationError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location Error: $error'),
        backgroundColor: Colors.orange.shade600,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _getCurrentLocation,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  void _showAuthenticationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Authentication Required'),
          ],
        ),
        content: const Text(
          'You need to be logged in to view charging providers. Please login to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Go to Login'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadProviders(refresh: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    _loadProviders(refresh: true);
  }

  void _copyCoordinates() {
    if (_currentPosition != null) {
      final coordinates = '${_currentPosition!.latitude}, ${_currentPosition!.longitude}';
      Clipboard.setData(ClipboardData(text: coordinates));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coordinates copied: $coordinates'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(chargingProviderProvider);
    final loginState = ref.watch(loginProvider);
    
    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(context, loginState),
            _buildLocationBar(),
            _buildSearchBar(),
            _buildFilterBar(),
          ];
        },
        body: _buildProvidersList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _loadProviders(refresh: true),
        backgroundColor: Colors.green.shade600,
        child: _isLoadingLocation 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, dynamic loginState) {
    final isLoggedIn = loginState.user.token.isNotEmpty;
    
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: AppTheme.gradientBackground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PowerPoint Providers',
                              style: AppTheme.headingStyle.copyWith(fontSize: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Find charging stations near you',
                              style: AppTheme.subheadingStyle,
                            ),
                          ],
                        ),
                      ),
                      // FIXED: Removed "Logged In" text - show only icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isLoggedIn 
                              ? Colors.green.shade600 
                              : Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isLoggedIn ? Icons.verified_user : Icons.warning,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showAdvancedFilters,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLocationBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPosition != null
                        ? 'Searching within ${_searchRadius.toInt()}km of your location'
                        : 'Getting your location...',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_currentPosition != null)
                  TextButton(
                    onPressed: () => _showRadiusSelector(),
                    child: Text(
                      'Change',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
              ],
            ),
            if (_currentPosition != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.gps_fixed, color: Colors.grey.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Coordinates: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _copyCoordinates(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name, location, amenities...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _applyFilters();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
          onSubmitted: (value) {
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final isSelected = filter == _selectedFilter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedFilter = filter);
                  _applyFilters();
                },
                backgroundColor: Colors.white,
                selectedColor: Colors.green.shade100,
                checkmarkColor: Colors.green.shade700,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProvidersList() {
    final providerState = ref.watch(chargingProviderProvider);
    final loginState = ref.watch(loginProvider);
    final isLoggedIn = loginState.user.token.isNotEmpty;
    
    print('🎨 Building providers list:');
    print('   - Loading: ${providerState.isLoading}');
    print('   - Providers count: ${providerState.providers.length}');
    print('   - Error: ${providerState.errorMessage}');
    print('   - Is logged in: $isLoggedIn');
    
    if (providerState.providers.isNotEmpty) {
      print('📋 Provider list:');
      for (int i = 0; i < providerState.providers.length; i++) {
        final provider = providerState.providers[i];
        print('   ${i + 1}. ${provider.businessName ?? 'Unknown'} - Slots: ${provider.availableSlots ?? 0}/${provider.totalSlots ?? 0} - Rate: ₹${provider.ratePerHour ?? 0}');
      }
    }
    
    if (providerState.isLoading && providerState.providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              isLoggedIn 
                  ? 'Finding charging providers near you...' 
                  : 'Checking authentication...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_currentPosition != null) ...[
              const SizedBox(height: 8),
              Text(
                'Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (providerState.errorMessage != null && 
        (providerState.errorMessage!.contains('Authentication') || 
         providerState.errorMessage!.contains('login'))) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.orange.shade400),
            const SizedBox(height: 16),
            Text(
              'Authentication Required',
              style: TextStyle(
                color: Colors.orange.shade600,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Please login to view charging providers and make bookings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            if (_currentPosition != null) ...[
              const SizedBox(height: 8),
              Text(
                'Your location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => _loadProviders(refresh: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (providerState.errorMessage != null && providerState.providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading providers',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                providerState.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade500),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadProviders(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredProviders = _getFilteredProviders(providerState.providers);
    
    if (filteredProviders.isEmpty && !providerState.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ev_station, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No charging providers found',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search filters or location',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            if (_currentPosition != null) ...[
              const SizedBox(height: 8),
              Text(
                'Searching near: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadProviders(refresh: true),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadProviders(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredProviders.length + (providerState.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filteredProviders.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final provider = filteredProviders[index];
          
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    (index / (filteredProviders.length.clamp(1, 10))).clamp(0.0, 1.0),
                    ((index + 1) / (filteredProviders.length.clamp(1, 10))).clamp(0.0, 1.0),
                    curve: Curves.easeOut,
                  ),
                )),
                child: _buildProviderCard(provider),
              );
            },
          );
        },
      ),
    );
  }

  List<ChargingProvider> _getFilteredProviders(List<ChargingProvider> providers) {
    List<ChargingProvider> filtered = [...providers];

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((provider) {
        return (provider.businessName ?? '').toLowerCase().contains(query) ||
            (provider.address ?? '').toLowerCase().contains(query) ||
            (provider.amenities ?? []).any((amenity) => amenity.toLowerCase().contains(query));
      }).toList();
    }

    switch (_selectedFilter) {
      case 'Available Now':
        filtered = filtered.where((p) => (p.availableSlots ?? 0) > 0).toList();
        break;
    }

    return filtered;
  }

  Widget _buildProviderCard(ChargingProvider provider) {
    final businessName = provider.businessName ?? 'Unknown Provider';
    final address = provider.address ?? 'Address not available';
    final rating = provider.rating ?? 0.0;
    final distance = provider.distance ?? 0.0;
    final ratePerHour = provider.ratePerHour ?? 0.0;
    final availableSlots = provider.availableSlots ?? 0;
    final totalSlots = provider.totalSlots ?? 0;
    final amenities = provider.amenities ?? [];
    final images = provider.images ?? [];
    
    final isMockData = businessName.contains('Mock') || 
                      (provider.description ?? '').contains('mock') ||
                      (provider.description ?? '').contains('testing');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProviderDetailsScreen(
                providerId: provider.id,
                userName: widget.userName,
                userEmail: widget.userEmail,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                image: images.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(images.first),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {
                          print('Image loading error: $exception');
                        },
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (images.isEmpty)
                    Center(
                      child: Icon(
                        Icons.ev_station,
                        size: 64,
                        color: Colors.green.shade600,
                      ),
                    ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: availableSlots > 0 
                            ? Colors.green.shade600 
                            : Colors.red.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        availableSlots > 0 ? 'Available' : 'Full',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (isMockData)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'DEMO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            businessName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.orange.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.orange.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    SizedBox(
                      height: 32,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFeatureChip(
                              icon: Icons.ev_station,
                              label: totalSlots > 0 
                                  ? '$availableSlots/$totalSlots slots'
                                  : 'Available',
                            ),
                            const SizedBox(width: 8),
                            _buildFeatureChip(
                              icon: Icons.route,
                              label: '${distance.toStringAsFixed(1)} km',
                            ),
                            const SizedBox(width: 8),
                            _buildFeatureChip(
                              icon: Icons.flash_on,
                              label: provider.fastCharging ? 'DC Fast' : 'AC Charging',
                            ),
                            if (amenities.contains('WiFi')) ...[
                              const SizedBox(width: 8),
                              _buildFeatureChip(
                                icon: Icons.wifi,
                                label: 'WiFi',
                              ),
                            ],
                            if (amenities.contains('Parking')) ...[
                              const SizedBox(width: 8),
                              _buildFeatureChip(
                                icon: Icons.local_parking,
                                label: 'Parking',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${ratePerHour.toStringAsFixed(0)}/hour',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Base rate',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final loginState = ref.read(loginProvider);
                              if (loginState.user.token.isEmpty) {
                                _showAuthenticationDialog();
                                return;
                              }
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProviderDetailsScreen(
                                    providerId: provider.id,
                                    userName: widget.userName,
                                    userEmail: widget.userEmail,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text(
                              'Book',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Advanced Filters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterSection('Charger Type', _chargerTypes, _selectedChargerType, (value) {
                      setState(() => _selectedChargerType = value);
                    }),
                    _buildFilterSection('Vehicle Type', _vehicleTypes, _selectedVehicleType, (value) {
                      setState(() => _selectedVehicleType = value);
                    }),
                    _buildAmenitiesFilter(),
                    _buildRatingFilter(),
                    _buildRateFilter(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedChargerType = 'All';
                                _selectedVehicleType = 'All';
                                _minRating = 0.0;
                                _maxRate = 500.0; // FIXED: Reset to 500.0
                                _selectedAmenities = [];
                              });
                              Navigator.pop(context);
                              _applyFilters();
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _applyFilters();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                            ),
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, String selected, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final isSelected = option == selected;
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (bool selected) {
                if (selected) onChanged(option);
              },
              backgroundColor: Colors.grey.shade100,
              selectedColor: Colors.green.shade100,
              checkmarkColor: Colors.green.shade700,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAmenitiesFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amenities',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _availableAmenities.map((amenity) {
            final isSelected = _selectedAmenities.contains(amenity);
            return FilterChip(
              label: Text(amenity),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedAmenities.add(amenity);
                  } else {
                    _selectedAmenities.remove(amenity);
                  }
                });
              },
              backgroundColor: Colors.grey.shade100,
              selectedColor: Colors.green.shade100,
              checkmarkColor: Colors.green.shade700,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Minimum Rating: ${_minRating.toStringAsFixed(1)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Slider(
          value: _minRating,
          min: 0.0,
          max: 5.0,
          divisions: 10,
          activeColor: Colors.green.shade600,
          onChanged: (value) {
            setState(() => _minRating = value);
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maximum Rate: ₹${_maxRate.toInt()}/hour',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Slider(
          value: _maxRate,
          min: 10.0,
          max: 500.0, // FIXED: Ensuring this matches the initial value
          divisions: 49,
          activeColor: Colors.green.shade600,
          onChanged: (value) {
            setState(() => _maxRate = value);
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showRadiusSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Radius'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current radius: ${_searchRadius.toInt()} km'),
              Slider(
                value: _searchRadius,
                min: 1.0,
                max: 50.0,
                divisions: 49,
                activeColor: Colors.green.shade600,
                onChanged: (value) {
                  setStateDialog(() => _searchRadius = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
              _applyFilters();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}