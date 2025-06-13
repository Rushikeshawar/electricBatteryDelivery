import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/booking_screen.dart';
import 'package:electric_battery_delivery_frontend/providers/station_detail_provider.dart';
import 'package:electric_battery_delivery_frontend/components/battery_detail_modal.dart';

class StationDetailScreen extends ConsumerStatefulWidget {
  final Station station;

  const StationDetailScreen({
    Key? key,
    required this.station,
  }) : super(key: key);

  @override
  ConsumerState<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends ConsumerState<StationDetailScreen> {
  
  @override
  void initState() {
    super.initState();
    // Initialize the provider
    Future.microtask(() => 
      ref.read(stationDetailProvider(widget.station).notifier).initialize()
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the state
    final stationDetailState = ref.watch(stationDetailProvider(widget.station));
    final canBook = ref.watch(canBookProvider(widget.station));
    
    // For convenience, create local variables
    final station = stationDetailState.station;
    final selectedBattery = stationDetailState.selectedBattery;
    final errorMessage = stationDetailState.errorMessage;
    
    return Scaffold(
      body: stationDetailState.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : CustomScrollView(
            slivers: [
              _buildAppBar(station),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show error message if any
                      if (errorMessage != null)
                        _buildErrorMessage(errorMessage),
                      _buildStationInfo(station),
                      const SizedBox(height: 16),
                      _buildAvailableBatteries(station, selectedBattery),
                    ],
                  ),
                ),
              ),
            ],
          ),
      bottomNavigationBar: _buildBottomButton(selectedBattery, canBook),
    );
  }

  // Widget to display error messages
  Widget _buildErrorMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Station station) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          station.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Color.fromARGB(150, 0, 0, 0),
              ),
            ],
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 46, bottom: 16),
        background: Stack(
          fit: StackFit.expand,
          children: [
            station.imageUrl.isNotEmpty
                ? Image.network(
                    station.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if image loading fails
                      return Container(
                        color: Colors.green.shade100,
                        child: Center(
                          child: Icon(
                            Icons.battery_charging_full,
                            size: 60,
                            color: Colors.green.shade600,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.green.shade100,
                    child: Center(
                      child: Icon(
                        Icons.battery_charging_full,
                        size: 60,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationInfo(Station station) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on,
              color: Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                station.address,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildInfoCard(
              title: 'Status',
              value: station.status,
              icon: Icons.info_outline,
              color: AppTheme.getStatusColor(station.status),
            ),
            _buildInfoCard(
              title: 'ETA',
              value: '${station.etaMinutes} mins',
              icon: Icons.timer_outlined,
              color: Colors.blue.shade700,
            ),
            _buildInfoCard(
              title: 'Batteries',
              value: '${station.availableBatteries}',
              icon: Icons.battery_full,
              color: station.availableBatteries > 0 ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Station Manager',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  station.managerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  station.email,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  station.phone,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableBatteries(Station station, Battery? selectedBattery) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Battery',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (station.availableBatteryTypes.isEmpty)
          // Enhanced empty state with a more prominent message
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.battery_alert,
                  size: 48,
                  color: Colors.red.shade500,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Batteries Available',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This station currently has no batteries available for swap. Please try another station or check back later.',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // Refresh the station details
                    ref.read(stationDetailProvider(widget.station).notifier).initialize();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade700),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: station.availableBatteryTypes.length,
            itemBuilder: (context, index) {
              final battery = station.availableBatteryTypes[index];
              final isSelected = selectedBattery?.id == battery.id;
              return _buildBatteryCard(battery, isSelected);
            },
          ),
      ],
    );
  }

  Widget _buildBatteryCard(Battery battery, bool isSelected) {
    final isAvailable = battery.availableQuantity > 0;

    return GestureDetector(
      onTap: isAvailable ? () {
        ref.read(stationDetailProvider(widget.station).notifier).selectBattery(battery);
      } : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.green.shade600 : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                      image: battery.imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(battery.imageUrl),
                              fit: BoxFit.cover,
                              onError: (exception, stackTrace) {
                                // Handle image loading errors
                              },
                            )
                          : null,
                    ),
                    child: battery.imageUrl.isEmpty
                        ? Icon(
                            Icons.battery_full,
                            size: 32,
                            color: Colors.green.shade600,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                battery.type,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade600,
                                size: 22,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          battery.description,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildBatterySpec(
                              label: 'Voltage',
                              value: '${battery.voltage}V',
                            ),
                            const SizedBox(width: 16),
                            _buildBatterySpec(
                              label: 'Capacity',
                              value: '${battery.capacity} kWh',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 14,
                            color: isAvailable
                                ? Colors.green.shade600
                                : Colors.red.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${battery.availableQuantity} Available',
                            style: TextStyle(
                              color: isAvailable
                                  ? Colors.green.shade600
                                  : Colors.red.shade400,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${battery.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // View Battery Button
                      SizedBox(
                        height: 32,
                        child: TextButton(
                          onPressed: () {
                            _showBatteryDetails(battery, isSelected);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'View Battery',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Select Button
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: isAvailable && !isSelected ? () {
                            ref.read(stationDetailProvider(widget.station).notifier).selectBattery(battery);
                          } : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(color: Colors.green.shade700),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(
                            isSelected ? 'Selected' : 'Select',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showBatteryDetails(Battery battery, bool isSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: BatteryDetailModal(
            battery: battery,
            isSelected: isSelected,
            onClose: () => Navigator.pop(context),
            onSelect: () {
              ref.read(stationDetailProvider(widget.station).notifier).selectBattery(battery);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  Widget _buildBatterySpec({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(Battery? selectedBattery, bool canBook) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedBattery != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Selected: ',
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              selectedBattery.type,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _showBatteryDetails(selectedBattery, true);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'View Details',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${selectedBattery.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: canBook
                    ? () {
                        _navigateToBookingScreen(widget.station, selectedBattery!);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canBook ? Colors.green.shade600 : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  widget.station.availableBatteryTypes.isEmpty 
                    ? 'No Batteries Available' 
                    : (canBook ? 'Book Now' : 'Select a Battery'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBookingScreen(Station station, Battery battery) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          station: station,
          battery: battery,
        ),
      ),
    );
  }
}