import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:electric_battery_delivery_frontend/models/charging_provider_model.dart';

class MapDirectionsScreen extends StatefulWidget {
  final ChargingProvider provider;
  final String providerName;
  final String providerAddress;

  const MapDirectionsScreen({
    super.key,
    required this.provider,
    required this.providerName,
    required this.providerAddress,
  });

  @override
  State<MapDirectionsScreen> createState() => _MapDirectionsScreenState();
}

class _MapDirectionsScreenState extends State<MapDirectionsScreen> {
  GoogleMapController? _controller;
  Position? _currentPosition;
  bool _isLoading = true;
  String? _error;
  
  // Google Maps API Key
  static const String _apiKey = 'AIzaSyBr_r8bq7m1A5aIh9-rkEIUB7chNfbwimM';
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Route information
  String _distance = '';
  String _duration = '';
  String _estimatedArrival = '';

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    if (_currentPosition != null) {
      await _setupMarkersAndRoute();
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check and request location permission
      final permission = await Permission.location.request();
      if (permission != PermissionStatus.granted) {
        setState(() {
          _error = 'Location permission is required for navigation';
        });
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled. Please enable them.';
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get current location: ${e.toString()}';
      });
    }
  }

  Future<void> _setupMarkersAndRoute() async {
    if (_currentPosition == null) return;

    // Create markers
    _markers = {
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Starting point',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: const MarkerId('provider_location'),
        position: LatLng(widget.provider.latitude, widget.provider.longitude),
        infoWindow: InfoWindow(
          title: widget.providerName,
          snippet: widget.providerAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    };

    // Get route from Google Directions API
    await _getDirections();
  }

  Future<void> _getDirections() async {
    if (_currentPosition == null) return;

    try {
      final String origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
      final String destination = '${widget.provider.latitude},${widget.provider.longitude}';
      
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=$origin&destination=$destination&key=$_apiKey&mode=driving';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Extract route information
          setState(() {
            _distance = leg['distance']['text'];
            _duration = leg['duration']['text'];
            _estimatedArrival = _calculateArrivalTime(leg['duration']['value']);
          });

          // Decode polyline points
          final points = _decodePolyline(route['overview_polyline']['points']);
          
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: Colors.blue,
                width: 5,
                patterns: [],
              ),
            };
          });
        }
      }
    } catch (e) {
      print('Error getting directions: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  String _calculateArrivalTime(int durationInSeconds) {
    final now = DateTime.now();
    final arrival = now.add(Duration(seconds: durationInSeconds));
    return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  }

  void _openInGoogleMaps() async {
    final String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&destination=${widget.provider.latitude},${widget.provider.longitude}'
        '&travelmode=driving';

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _centerMap() {
    if (_controller != null && _currentPosition != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _currentPosition!.latitude < widget.provider.latitude
              ? _currentPosition!.latitude
              : widget.provider.latitude,
          _currentPosition!.longitude < widget.provider.longitude
              ? _currentPosition!.longitude
              : widget.provider.longitude,
        ),
        northeast: LatLng(
          _currentPosition!.latitude > widget.provider.latitude
              ? _currentPosition!.latitude
              : widget.provider.latitude,
          _currentPosition!.longitude > widget.provider.longitude
              ? _currentPosition!.longitude
              : widget.provider.longitude,
        ),
      );
      
      _controller!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Directions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade600,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: _centerMap,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            onPressed: _currentPosition != null ? _openInGoogleMaps : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map and getting directions...'),
                ],
              ),
            )
          : _error != null
              ? Center(
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
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _initializeMap();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Route Information Card
                    if (_distance.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 0,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.navigation,
                                  color: Colors.green.shade600,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.providerName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildRouteInfo(
                                  Icons.straighten,
                                  'Distance',
                                  _distance,
                                ),
                                _buildRouteInfo(
                                  Icons.access_time,
                                  'Duration',
                                  _duration,
                                ),
                                _buildRouteInfo(
                                  Icons.schedule,
                                  'Arrival',
                                  _estimatedArrival,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    
                    // Map
                    Expanded(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentPosition != null
                              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                              : LatLng(widget.provider.latitude, widget.provider.longitude),
                          zoom: 14.0,
                        ),
                        markers: _markers,
                        polylines: _polylines,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        onMapCreated: (GoogleMapController controller) {
                          _controller = controller;
                          // Auto-fit the map to show both markers
                          Future.delayed(const Duration(milliseconds: 500), () {
                            _centerMap();
                          });
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _currentPosition != null
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openInGoogleMaps,
                      icon: const Icon(Icons.navigation, size: 20),
                      label: const Text('Start Navigation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green.shade600),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {
                       
                      },
                      icon: Icon(
                        Icons.phone,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildRouteInfo(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}