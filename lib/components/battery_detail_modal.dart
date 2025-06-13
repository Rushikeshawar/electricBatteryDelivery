import 'package:flutter/material.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';

class BatteryDetailModal extends StatelessWidget {
  final Battery battery;
  final Function() onClose;
  final Function() onSelect;
  final bool isSelected;

  const BatteryDetailModal({
    Key? key,
    required this.battery,
    required this.onClose,
    required this.onSelect,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Battery Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                color: Colors.grey.shade600,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Battery image and basic info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Battery image
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                  image: battery.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(battery.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                ),
                child: battery.imageUrl.isEmpty
                  ? Icon(
                      Icons.battery_full,
                      size: 48,
                      color: Colors.green.shade600,
                    )
                  : null,
              ),
              const SizedBox(width: 16),
              
              // Battery information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      battery.type,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      battery.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 16,
                          color: battery.availableQuantity > 0
                              ? Colors.green.shade600
                              : Colors.red.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${battery.availableQuantity} Available',
                          style: TextStyle(
                            color: battery.availableQuantity > 0
                                ? Colors.green.shade600
                                : Colors.red.shade400,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${battery.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Technical specifications
          Text(
            'Technical Specifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildSpecRow(
                  label: 'Voltage',
                  value: '${battery.voltage}V',
                  icon: Icons.bolt,
                ),
                const Divider(height: 24),
                _buildSpecRow(
                  label: 'Capacity',
                  value: '${battery.capacity} kWh',
                  icon: Icons.battery_charging_full,
                ),
                const Divider(height: 24),
                _buildSpecRow(
                  label: 'Estimated Range',
                  value: '${(battery.capacity * 5).toInt()} km',
                  icon: Icons.directions_car,
                ),
                const Divider(height: 24),
                _buildSpecRow(
                  label: 'Charging Time',
                  value: '${(battery.capacity * 0.5).toStringAsFixed(1)} hours',
                  icon: Icons.access_time,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: battery.availableQuantity > 0 ? onSelect : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(isSelected ? 'Selected' : 'Select Battery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  Widget _buildSpecRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.green.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}