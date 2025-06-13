// location_search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:electric_battery_delivery_frontend/providers/dashboard_provider.dart';
import 'package:electric_battery_delivery_frontend/services/maps_service.dart';

class LocationSearchScreen extends ConsumerStatefulWidget {
  const LocationSearchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends ConsumerState<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    _searchFocus.requestFocus();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  // Search for places based on query
  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
    });
    
    try {
      // Get user location for nearby search
      final userLocation = ref.read(dashboardProvider).userLocation;
      if (userLocation == null) {
        throw Exception('User location not available');
      }
      
      // Search nearby places
      final places = await MapsService.searchNearbyPlaces(
        LatLng(userLocation.latitude, userLocation.longitude),
        query,
        50000, // 50km radius
      );
      
      setState(() {
        _searchResults = places;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    }
  }
  
  // Handle address selection and update user location
  Future<void> _selectAddress(Map<String, dynamic> place) async {
    try {
      final geometry = place['geometry'];
      if (geometry == null || geometry['location'] == null) {
        throw Exception('Invalid place data');
      }
      
      final location = geometry['location'];
      final latitude = location['lat'];
      final longitude = location['lng'];
      
      // Create a new Position object
      final newPosition = Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      
      // Update user location in the dashboard provider
      await ref.read(dashboardProvider.notifier).getUserLocation();
      
      // Go back to the previous screen
      Navigator.pop(context, {
        'position': newPosition,
        'address': place['vicinity'] ?? 'Selected Location',
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting location: $e')),
      );
    }
  }
  
  // Handle manual location selection on map
  void _selectCurrentLocation() async {
    final dashboardState = ref.read(dashboardProvider);
    if (dashboardState.userLocation != null) {
      Navigator.pop(context, {
        'position': dashboardState.userLocation,
        'address': 'Current Location',
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Location'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade600,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: 'Search for a location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                // Debounce search to avoid too many API calls
                if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                  _searchPlaces(value);
                });
              },
            ),
          ),
          
          // Current location button
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Icon(
                Icons.my_location,
                color: Colors.green.shade700,
              ),
            ),
            title: const Text('Use current location'),
            onTap: _selectCurrentLocation,
          ),
          
          const Divider(),
          
          // Loading indicator
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          
          // Search results
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'Search for a location'
                          : 'No results found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final place = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(
                            Icons.location_on,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        title: Text(place['name'] ?? 'Unnamed Location'),
                        subtitle: Text(
                          place['vicinity'] ?? 'No address',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectAddress(place),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}