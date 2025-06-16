// lib/screens/provider_slots_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/provider_models.dart';
import '../providers/provider_providers.dart';
import '../components/app_theme.dart';

class ProviderSlotsScreen extends ConsumerStatefulWidget {
  const ProviderSlotsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProviderSlotsScreen> createState() => _ProviderSlotsScreenState();
}

class _ProviderSlotsScreenState extends ConsumerState<ProviderSlotsScreen> {
  List<ProviderSlot> _slots = [];
  bool _isEditing = false;

  final List<String> _daysOfWeek = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  final List<String> _timeSlots = [
    '09:00', '10:00', '11:00', '12:00', '13:00', '14:00',
    '15:00', '16:00', '17:00', '18:00', '19:00', '20:00',
  ];

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(providerSlotsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Time Slots'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: AppTheme.gradientBackground,
        ),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _saveSlots,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          else
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit, color: Colors.white),
            ),
        ],
      ),
      body: slotsAsync.when(
        data: (slots) {
          if (_slots.isEmpty) {
            _slots = List.from(slots);
          }
          
          return Column(
            children: [
              // Header Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Available Time Slots',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isEditing 
                          ? 'Toggle slots to set your availability. Save when done.'
                          : 'Manage when customers can book your charging station.',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              if (_isEditing)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _enableAllSlots,
                          icon: const Icon(Icons.check_box),
                          label: const Text('Enable All'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _disableAllSlots,
                          icon: const Icon(Icons.check_box_outline_blank),
                          label: const Text('Disable All'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addNewSlot,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Slot'),
                        ),
                      ),
                    ],
                  ),
                ),

              // Slots Grid
              Expanded(
                child: _buildSlotsGrid(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
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
                'Failed to load slots',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red.shade500,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(providerSlotsProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isEditing
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                });
              },
              backgroundColor: Colors.grey.shade600,
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildSlotsGrid() {
    if (_slots.isEmpty) {
      return _buildEmptyState();
    }

    // Group slots by day
    Map<String, List<ProviderSlot>> slotsByDay = {};
    for (String day in _daysOfWeek) {
      slotsByDay[day] = _slots.where((slot) => slot.dayOfWeek == day).toList();
      slotsByDay[day]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _daysOfWeek.map((day) {
          final daySlots = slotsByDay[day] ?? [];
          return _buildDaySection(day, daySlots);
        }).toList(),
      ),
    );
  }

  Widget _buildDaySection(String day, List<ProviderSlot> daySlots) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDayName(day),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (_isEditing)
                  TextButton.icon(
                    onPressed: () => _addSlotForDay(day),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (daySlots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No slots available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: daySlots.map((slot) => _buildSlotChip(slot)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotChip(ProviderSlot slot) {
    Color backgroundColor = slot.isAvailable 
        ? Colors.green.shade100 
        : Colors.red.shade100;
    Color textColor = slot.isAvailable 
        ? Colors.green.shade700 
        : Colors.red.shade700;
    Color borderColor = slot.isAvailable 
        ? Colors.green.shade300 
        : Colors.red.shade300;

    return InkWell(
      onTap: _isEditing ? () => _toggleSlot(slot) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isEditing)
              Icon(
                slot.isAvailable ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: textColor,
              )
            else
              Icon(
                slot.isAvailable ? Icons.access_time : Icons.block,
                size: 16,
                color: textColor,
              ),
            const SizedBox(width: 4),
            Text(
              '${slot.startTime} - ${slot.endTime}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _deleteSlot(slot),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Time Slots Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add time slots to let customers know when your charging station is available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNewSlot,
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Slot'),
          ),
        ],
      ),
    );
  }

  String _formatDayName(String day) {
    return day.substring(0, 1) + day.substring(1).toLowerCase();
  }

  void _toggleSlot(ProviderSlot slot) {
    setState(() {
      final index = _slots.indexWhere((s) => s.id == slot.id);
      if (index != -1) {
        _slots[index] = ProviderSlot(
          id: slot.id,
          dayOfWeek: slot.dayOfWeek,
          startTime: slot.startTime,
          endTime: slot.endTime,
          isAvailable: !slot.isAvailable,
        );
      }
    });
  }

  void _deleteSlot(ProviderSlot slot) {
    setState(() {
      _slots.removeWhere((s) => s.id == slot.id);
    });
  }

  void _enableAllSlots() {
    setState(() {
      _slots = _slots.map((slot) => ProviderSlot(
        id: slot.id,
        dayOfWeek: slot.dayOfWeek,
        startTime: slot.startTime,
        endTime: slot.endTime,
        isAvailable: true,
      )).toList();
    });
  }

  void _disableAllSlots() {
    setState(() {
      _slots = _slots.map((slot) => ProviderSlot(
        id: slot.id,
        dayOfWeek: slot.dayOfWeek,
        startTime: slot.startTime,
        endTime: slot.endTime,
        isAvailable: false,
      )).toList();
    });
  }

  void _addSlotForDay(String day) {
    _showAddSlotDialog(day);
  }

  void _addNewSlot() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Day'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _daysOfWeek.map((day) {
            return ListTile(
              title: Text(_formatDayName(day)),
              onTap: () {
                Navigator.pop(context);
                _showAddSlotDialog(day);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddSlotDialog(String day) {
    String selectedStartTime = '09:00';
    String selectedEndTime = '10:00';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add Slot for ${_formatDayName(day)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStartTime,
                decoration: const InputDecoration(
                  labelText: 'Start Time',
                  prefixIcon: Icon(Icons.access_time),
                ),
                items: _timeSlots.map((time) {
                  return DropdownMenuItem(value: time, child: Text(time));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedStartTime = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedEndTime,
                decoration: const InputDecoration(
                  labelText: 'End Time',
                  prefixIcon: Icon(Icons.access_time_filled),
                ),
                items: _timeSlots.map((time) {
                  return DropdownMenuItem(value: time, child: Text(time));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedEndTime = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_isValidTimeSlot(selectedStartTime, selectedEndTime)) {
                  _addSlot(day, selectedStartTime, selectedEndTime);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End time must be after start time'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidTimeSlot(String startTime, String endTime) {
    final start = TimeOfDay(
      hour: int.parse(startTime.split(':')[0]),
      minute: int.parse(startTime.split(':')[1]),
    );
    final end = TimeOfDay(
      hour: int.parse(endTime.split(':')[0]),
      minute: int.parse(endTime.split(':')[1]),
    );
    
    return (end.hour > start.hour) || (end.hour == start.hour && end.minute > start.minute);
  }

  void _addSlot(String day, String startTime, String endTime) {
    final newSlot = ProviderSlot(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID
      dayOfWeek: day,
      startTime: startTime,
      endTime: endTime,
      isAvailable: true,
    );

    setState(() {
      _slots.add(newSlot);
      _isEditing = true;
    });
  }

  void _saveSlots() async {
    final success = await ref.read(providerManagementProvider.notifier).updateProviderSlots(_slots);
    
    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slots updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh the slots data
      ref.invalidate(providerSlotsProvider);
    } else if (mounted) {
      final error = ref.read(providerManagementProvider).asError?.error.toString() ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update slots: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}