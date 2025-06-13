// location_map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:electric_battery_delivery_frontend/station_detail_screen.dart';

class LocationMapScreen extends StatefulWidget {
  final List<Station> stations;
  final Position userLocation;
  
  const LocationMapScreen({
    Key? key, 
    required this.stations,
    required this.userLocation,
  }) : super(key: key);

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  
  @override
  void initState() {
    super.initState();
    _updateMarkers();
  }
  
  void _updateMarkers() {
    Set<Marker> markers = {};
    
    // Add user location marker
    markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(
          widget.userLocation.latitude,
          widget.userLocation.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location'),
        zIndex: 2,
      ),
    );
    
    // Add station markers
    for (var station in widget.stations) {
      markers.add(
        Marker(
          markerId: MarkerId('station_${station.id}'),
          position: LatLng(station.latitude, station.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: station.name,
            snippet: '${station.availableBatteries} batteries | ₹${station.price}',
            onTap: () => _navigateToStationDetail(station),
          ),
          onTap: () {
            _showStationBottomSheet(station);
          },
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }

  void _navigateToStationDetail(Station station) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StationDetailScreen(station: station),
      ),
    );
  }

  void _showStationBottomSheet(Station station) {
    final isAvailable = station.status.toLowerCase() == 'available';
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      station.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      station.status,
                      style: TextStyle(
                        color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      station.address,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.battery_charging_full, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            '${station.availableBatteries} Batteries Available',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.timer, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            'ETA: ${station.etaMinutes} mins',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '₹${station.price}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isAvailable ? () => _navigateToStationDetail(station) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View Details & Swap Battery'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Stations'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(
            widget.userLocation.latitude,
            widget.userLocation.longitude,
          ),
          zoom: 14.0,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.my_location),
        onPressed: () async {
          final GoogleMapController controller = await _controller.future;
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(
                  widget.userLocation.latitude,
                  widget.userLocation.longitude,
                ),
                zoom: 14.0,
              ),
            ),
          );
        },
      ),
    );
  }
}