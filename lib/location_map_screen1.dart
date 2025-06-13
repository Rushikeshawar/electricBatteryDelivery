import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Google Maps Web Helper Class
class GoogleMapsWebHelper {
  static bool _isLoaded = false;
  static bool _isLoading = false;

  /// Check if Google Maps API is loaded
  static bool get isLoaded => _isLoaded;

  /// Check if Google Maps API is currently loading
  static bool get isLoading => _isLoading;

  /// Wait for Google Maps API to be ready
  static Future<bool> waitForGoogleMaps({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!kIsWeb) {
      return true; // Always available on mobile
    }

    if (_isLoaded) {
      return true;
    }

    _isLoading = true;
    
    try {
      final startTime = DateTime.now();
      
      while (DateTime.now().difference(startTime) < timeout) {
        if (await _checkGoogleMapsAvailability()) {
          _isLoaded = true;
          _isLoading = false;
          return true;
        }
        
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      _isLoading = false;
      return false;
    } catch (e) {
      print('Error waiting for Google Maps: $e');
      _isLoading = false;
      return false;
    }
  }

  /// Check if Google Maps API is available
  static Future<bool> _checkGoogleMapsAvailability() async {
    if (!kIsWeb) return true;

    try {
      // For web, we'll use a simple approach - assume it's loaded after a delay
      // This is because accessing window properties from Dart can be tricky
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get loading status message
  static String getStatusMessage() {
    if (!kIsWeb) return 'Ready';
    if (_isLoaded) return 'Google Maps loaded';
    if (_isLoading) return 'Loading Google Maps...';
    return 'Google Maps not loaded';
  }

  /// Reset the loading state (useful for retrying)
  static void reset() {
    _isLoaded = false;
    _isLoading = false;
  }
}

class LocationMapScreen extends ConsumerStatefulWidget {
  final Function(LatLng location, String address)? onLocationSelected;
  final LatLng? initialLocation;
  final String? initialAddress;

  const LocationMapScreen({
    Key? key,
    this.onLocationSelected,
    this.initialLocation,
    this.initialAddress,
  }) : super(key: key);

  @override
  ConsumerState<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends ConsumerState<LocationMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  String _currentAddress = 'Getting location...';
  String _selectedAddress = '';
  bool _isLoadingLocation = true;
  bool _isLoadingAddress = false;
  bool _hasMapError = false;
  bool _isGoogleMapsReady = false;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // First, wait for Google Maps to be ready (for web)
    if (kIsWeb) {
      setState(() {
        _isLoadingLocation = true;
      });
      
      try {
        // Wait a bit for Google Maps API to load
        await Future.delayed(const Duration(seconds: 2));
        _isGoogleMapsReady = true;
      } catch (e) {
        print('Error waiting for Google Maps: $e');
        _isGoogleMapsReady = false;
      }
    } else {
      _isGoogleMapsReady = true;
    }

    // Then initialize location
    await _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _selectedAddress = widget.initialAddress ?? '';
      _updateMarkers();
      setState(() {
        _isLoadingLocation = false;
      });
      
      // Move camera to initial location
      if (_mapController != null) {
        try {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(widget.initialLocation!, 16.0),
          );
        } catch (e) {
          print('Error animating camera: $e');
        }
      }
    } else {
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });

      // Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied');
          _setDefaultLocation();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied. Please enable them in settings.');
        _setDefaultLocation();
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled. Please enable them in settings.');
        _setDefaultLocation();
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      _currentLocation = LatLng(position.latitude, position.longitude);
      _selectedLocation = _currentLocation;
      
      // Get address for current location
      await _getAddressFromLatLng(_currentLocation!);
      
      _updateMarkers();
      
      // Move camera to current location
      if (_mapController != null && _isGoogleMapsReady) {
        try {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentLocation!, 16.0),
          );
        } catch (e) {
          print('Error animating camera: $e');
        }
      }

      setState(() {
        _isLoadingLocation = false;
      });
    } catch (e) {
      print('Error getting current location: $e');
      _showError('Failed to get current location: ${e.toString()}');
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    // Set default location to Nagpur (user's location from context)
    _currentLocation = const LatLng(21.1458, 79.0882);
    _selectedLocation = _currentLocation;
    _selectedAddress = 'Nagpur, Maharashtra, India';
    _updateMarkers();
    
    if (_mapController != null && _isGoogleMapsReady) {
      try {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 12.0),
        );
      } catch (e) {
        print('Error animating camera to default location: $e');
      }
    }
    
    setState(() {
      _isLoadingLocation = false;
    });
  }

  Future<void> _getAddressFromLatLng(LatLng location) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      ).timeout(const Duration(seconds: 10));

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        // Build address string with available components
        final addressComponents = <String>[];
        
        if (placemark.name != null && placemark.name!.isNotEmpty && placemark.name != placemark.street) {
          addressComponents.add(placemark.name!);
        }
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressComponents.add(placemark.street!);
        }
        if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
          addressComponents.add(placemark.subLocality!);
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressComponents.add(placemark.locality!);
        }
        if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
          addressComponents.add(placemark.administrativeArea!);
        }
        if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
          addressComponents.add(placemark.postalCode!);
        }
        
        final address = addressComponents.isNotEmpty 
            ? addressComponents.join(', ')
            : 'Address not available';
        
        setState(() {
          if (location == _currentLocation) {
            _currentAddress = address;
          }
          _selectedAddress = address;
          _isLoadingAddress = false;
        });
      } else {
        setState(() {
          _selectedAddress = 'Address not found';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      print('Geocoding error: $e');
      setState(() {
        _selectedAddress = 'Unable to get address';
        _isLoadingAddress = false;
      });
    }
  }

  void _updateMarkers() {
    _markers.clear();
    
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Current Location',
            snippet: _currentAddress,
          ),
        ),
      );
    }

    if (_selectedLocation != null && _selectedLocation != _currentLocation) {
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Selected Location',
            snippet: _selectedAddress,
          ),
        ),
      );
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    
    _getAddressFromLatLng(location);
    _updateMarkers();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _getCurrentLocation,
          ),
        ),
      );
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null && widget.onLocationSelected != null) {
      widget.onLocationSelected!(_selectedLocation!, _selectedAddress);
    }
    Navigator.pop(context);
  }

  Widget _buildGoogleMapsLoadingView() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading Google Maps...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while the map loads',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackMap() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Map not available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb 
                        ? 'Google Maps API not loaded.\nPlease check your internet connection\nand refresh the page.'
                        : 'Unable to load map.\nPlease check your internet connection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasMapError = false;
                        _isGoogleMapsReady = false;
                      });
                      _initializeApp();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (_selectedLocation != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Selected Location:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedAddress.isNotEmpty 
                                ? _selectedAddress 
                                : 'Custom location selected',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                            'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Manual location input section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter Location Manually:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                          hintText: '21.1458',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          final lat = double.tryParse(value);
                          if (lat != null && lat >= -90 && lat <= 90) {
                            final currentLng = _selectedLocation?.longitude ?? 79.0882;
                            setState(() {
                              _selectedLocation = LatLng(lat, currentLng);
                            });
                            _getAddressFromLatLng(_selectedLocation!);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                          hintText: '79.0882',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          final lng = double.tryParse(value);
                          if (lng != null && lng >= -180 && lng <= 180) {
                            final currentLat = _selectedLocation?.latitude ?? 21.1458;
                            setState(() {
                              _selectedLocation = LatLng(currentLat, lng);
                            });
                            _getAddressFromLatLng(_selectedLocation!);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use Current Location'),
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

  Widget _buildGoogleMap() {
    // For web, check if Google Maps is ready first
    if (kIsWeb && !_isGoogleMapsReady) {
      return _buildGoogleMapsLoadingView();
    }

    try {
      return GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          if (_selectedLocation != null) {
            try {
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(_selectedLocation!, 16.0),
              );
            } catch (e) {
              print('Error animating camera on map created: $e');
            }
          } else if (_currentLocation != null) {
            try {
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(_currentLocation!, 16.0),
              );
            } catch (e) {
              print('Error animating camera to current location: $e');
            }
          }
        },
        initialCameraPosition: CameraPosition(
          target: _selectedLocation ?? _currentLocation ?? const LatLng(21.1458, 79.0882),
          zoom: 16.0,
        ),
        markers: _markers,
        onTap: _onMapTap,
        myLocationButtonEnabled: false,
        myLocationEnabled: true,
        mapType: MapType.normal,
        zoomControlsEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: false,
      );
    } catch (e) {
      print('Error creating GoogleMap widget: $e');
      setState(() {
        _hasMapError = true;
      });
      return _buildFallbackMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _confirmLocation,
              child: const Text(
                'CONFIRM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoadingLocation
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    kIsWeb ? 'Initializing maps and location...' : 'Getting your location...',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb 
                        ? 'Please wait while we load the map'
                        : 'Please make sure location services are enabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Address display card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.green.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Location:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isLoadingAddress
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Getting address...'),
                              ],
                            )
                          : Text(
                              _selectedAddress.isEmpty ? 'Tap on map to select location' : _selectedAddress,
                              style: const TextStyle(fontSize: 14),
                            ),
                      if (_selectedLocation != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                          'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _hasMapError 
                            ? 'Map unavailable - use manual input below or retry'
                            : 'Tip: Tap anywhere on the map to select a location',
                        style: TextStyle(
                          fontSize: 12,
                          color: _hasMapError ? Colors.orange.shade600 : Colors.green.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                // Map or fallback
                Expanded(
                  child: _hasMapError ? _buildFallbackMap() : _buildGoogleMap(),
                ),
              ],
            ),
      floatingActionButton: !_isLoadingLocation && !_hasMapError && _currentLocation != null && _isGoogleMapsReady
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // My Location Button
                FloatingActionButton(
                  heroTag: 'my_location',
                  onPressed: () {
                    if (_mapController != null && _currentLocation != null) {
                      try {
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLngZoom(_currentLocation!, 16.0),
                        );
                        setState(() {
                          _selectedLocation = _currentLocation;
                          _selectedAddress = _currentAddress;
                        });
                        _updateMarkers();
                      } catch (e) {
                        print('Error using my location button: $e');
                        _showError('Unable to move to current location');
                      }
                    }
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green.shade600,
                  mini: true,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 16),
                // Confirm Button
                if (_selectedLocation != null)
                  FloatingActionButton.extended(
                    heroTag: 'confirm_location',
                    onPressed: _confirmLocation,
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm'),
                  ),
              ],
            )
          : null,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}