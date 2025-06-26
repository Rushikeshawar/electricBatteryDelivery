import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/provider_models.dart';
import '../providers/provider_providers.dart';
import '../components/app_theme.dart';
import '../screens/provider_status_screen.dart';

class BecomeProviderScreen extends ConsumerStatefulWidget {
  const BecomeProviderScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BecomeProviderScreen> createState() => _BecomeProviderScreenState();
}

class _BecomeProviderScreenState extends ConsumerState<BecomeProviderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();

  // Separate address controllers
  final _streetAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _villageController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _addressController = TextEditingController();

  final _hourlyRateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String _selectedChargerType = 'Type 2 AC';
  List<String> _selectedVehicleTypes = [];
  List<String> _selectedAmenities = [];

  static const String _googleMapsApiKey = 'AIzaSyBr_r8bq7m1A5aIh9-rkEIUB7chNfbwimM';

  final List<String> _chargerTypes = [
    'Type 2 AC',
    'CCS 2',
    'CHAdeMO',
    'Type 1',
    'CCS 1',
  ];

  final List<String> _vehicleTypes = [
    'Car',
    'Bike',
    'Scooter',
    'Bus',
    'Truck',
  ];

  final List<String> _amenities = [
    'Parking',
    'WiFi',
    'Restroom',
    'Coffee',
    'Waiting Area',
    'Security',
    'CCTV',
    '24/7 Access',
  ];

  bool _hasCheckedExistingRequest = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _streetAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _villageController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    _hourlyRateController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> geocodeAddress(String address) async {
    if (address.isEmpty) return;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_googleMapsApiKey'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];

          _latitudeController.text = lat.toString();
          _longitudeController.text = lng.toString();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Coordinates updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address not found. Please check the address.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting coordinates: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _buildFullAddress() {
    List<String> addressParts = [];

    if (_streetAddressController.text.isNotEmpty) {
      addressParts.add(_streetAddressController.text);
    }
    if (_villageController.text.isNotEmpty) {
      addressParts.add(_villageController.text);
    }
    if (_cityController.text.isNotEmpty) {
      addressParts.add(_cityController.text);
    }
    if (_stateController.text.isNotEmpty) {
      addressParts.add(_stateController.text);
    }
    if (_pincodeController.text.isNotEmpty) {
      addressParts.add(_pincodeController.text);
    }

    return addressParts.join(', ');
  }

  void _updateFullAddress() {
    final fullAddress = _buildFullAddress();
    _addressController.text = fullAddress;

    Future.delayed(const Duration(seconds: 3), () {
      if (_addressController.text == fullAddress && fullAddress.isNotEmpty) {
        geocodeAddress(fullAddress);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final registrationState = ref.watch(providerRegistrationProvider);
    final requestStatusAsync = ref.watch(providerRequestStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Provider'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: AppTheme.gradientBackground,
        ),
      ),
      body: requestStatusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildForm(registrationState),
        data: (requestStatus) {
          if (requestStatus != null && !_hasCheckedExistingRequest) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showExistingRequestDialog(requestStatus);
              _hasCheckedExistingRequest = true;
            });
          }

          if (requestStatus != null) {
            return _buildExistingRequestView(requestStatus);
          }

          return _buildForm(registrationState);
        },
      ),
    );
  }

  Widget _buildExistingRequestView(ProviderRequestStatus status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: _getStatusColor(status.status).withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(status.status),
                    size: 48,
                    color: _getStatusColor(status.status),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Provider Request Status',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Submitted on: ${_formatDate(status.createdAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (status.updatedAt != status.createdAt) ...[
                    Text(
                      'Last updated: ${_formatDate(status.updatedAt)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (status.status == 'PENDING') ...[
            _buildPendingStatusCard(),
            const SizedBox(height: 16),
            _buildActionButtons(status),
          ] else if (status.status == 'APPROVED') ...[
            _buildApprovedStatusCard(),
            const SizedBox(height: 16),
            _buildProviderActions(),
          ] else if (status.status == 'REJECTED') ...[
            _buildRejectedStatusCard(status),
            const SizedBox(height: 16),
            _buildRejectedActions(),
          ],

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProviderStatusScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingStatusCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Text(
                  'Request Under Review',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your provider request is currently being reviewed by our team. This process typically takes 2-3 business days.',
              style: TextStyle(color: Colors.orange.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              '• We will verify your information\n'
              '• Check your location and facility\n'
              '• Review your equipment specifications\n'
              '• You will receive an email notification once reviewed',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedStatusCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your provider request has been approved! You can now start managing your charging station and accepting bookings.',
              style: TextStyle(color: Colors.green.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedStatusCard(ProviderRequestStatus status) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text(
                  'Request Rejected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Unfortunately, your provider request was not approved. Please review the feedback and consider submitting a new request.',
              style: TextStyle(color: Colors.red.shade700),
            ),
            if (status.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejection Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status.rejectionReason!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ProviderRequestStatus status) {
    final registrationState = ref.watch(providerRegistrationProvider);

    return Column(
      children: [
        if (status.status == 'PENDING') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showUpdateRequestDialog(status),
              icon: const Icon(Icons.edit),
              label: const Text('Update Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: registrationState.isLoading ? null : () => _showCancelRequestDialog(),
            icon: registrationState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(registrationState.isLoading ? 'Cancelling...' : 'Cancel Request'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade600),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/provider-dashboard');
            },
            icon: const Icon(Icons.dashboard),
            label: const Text('Go to Dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/provider-profile');
            },
            icon: const Icon(Icons.person),
            label: const Text('Manage Profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade600,
              side: BorderSide(color: Colors.green.shade600),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRejectedActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _submitNewRequest(),
            icon: const Icon(Icons.refresh),
            label: const Text('Submit New Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showCancelRequestDialog(),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove Request'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade600),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AsyncValue<String?> registrationState) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.ev_station,
                      size: 48,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join Our Provider Network',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start earning by providing EV charging services in your area',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildSectionHeader('Business Information'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Business Name (Optional)',
                        hintText: 'e.g., Green Energy Hub',
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number *',
                        hintText: '+91 9876543210',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your contact number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildSectionHeader('Charging Equipment'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedChargerType,
                      decoration: const InputDecoration(
                        labelText: 'Charger Type *',
                        prefixIcon: Icon(Icons.electrical_services),
                      ),
                      items: _chargerTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedChargerType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Supported Vehicle Types *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _vehicleTypes.map((type) {
                        return FilterChip(
                          label: Text(type),
                          selected: _selectedVehicleTypes.contains(type),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedVehicleTypes.add(type);
                              } else {
                                _selectedVehicleTypes.remove(type);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_selectedVehicleTypes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Please select at least one vehicle type',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildSectionHeader('Location'),
            _buildAddressSection(),

            const SizedBox(height: 16),

            _buildSectionHeader('Pricing & Description'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _hourlyRateController,
                      decoration: const InputDecoration(
                        labelText: 'Hourly Rate (₹) *',
                        hintText: '50.00',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the hourly rate';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        hintText: 'Describe your charging facility, location benefits, etc.',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildSectionHeader('Amenities (Optional)'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select available amenities at your location',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _amenities.map((amenity) {
                        return FilterChip(
                          label: Text(amenity),
                          selected: _selectedAmenities.contains(amenity),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAmenities.add(amenity);
                              } else {
                                _selectedAmenities.remove(amenity);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: registrationState.isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: registrationState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Provider Request',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Important Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Your request will be reviewed within 2-3 business days\n'
                      '• You will be notified via email about the approval status\n'
                      '• Approved providers can start earning immediately\n'
                      '• We charge a small commission on each successful booking',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Charging Station Address Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _streetAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Street Address / Building Name *',
                    hintText: 'e.g., 123 Main Street, ABC Building',
                    prefixIcon: Icon(Icons.home),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter street address';
                    }
                    if (value.length < 2) {
                      return 'Please enter a valid address';
                    }
                    return null;
                  },
                  onChanged: (value) => _updateFullAddress(),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City *',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter city';
                          }
                          return null;
                        },
                        onChanged: (value) => _updateFullAddress(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State *',
                          prefixIcon: Icon(Icons.map),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter state';
                          }
                          return null;
                        },
                        onChanged: (value) => _updateFullAddress(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _villageController,
                        decoration: const InputDecoration(
                          labelText: 'Village / Area *',
                          prefixIcon: Icon(Icons.landscape),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter area';
                          }
                          return null;
                        },
                        onChanged: (value) => _updateFullAddress(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pincodeController,
                        decoration: const InputDecoration(
                          labelText: 'Pincode *',
                          prefixIcon: Icon(Icons.pin_drop),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter pincode';
                          }
                          if (value.length != 6) {
                            return 'Pincode should be 6 digits';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Enter a valid pincode';
                          }
                          return null;
                        },
                        onChanged: (value) => _updateFullAddress(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Address Preview:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildFullAddress().isEmpty
                          ? 'Address will appear here as you type...'
                          : _buildFullAddress(),
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontStyle: _buildFullAddress().isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coordinates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude *',
                          hintText: '12.9716',
                          prefixIcon: Icon(Icons.my_location),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        readOnly: true,
                        style: TextStyle(color: Colors.grey.shade700),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude *',
                          hintText: '77.5946',
                          prefixIcon: Icon(Icons.my_location),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        readOnly: true,
                        style: TextStyle(color: Colors.grey.shade700),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final fullAddress = _buildFullAddress();
                          if (fullAddress.isNotEmpty) {
                            geocodeAddress(fullAddress);
                          }
                        },
                        icon: const Icon(Icons.gps_fixed),
                        label: const Text('Get Coordinates'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use Current Location'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange.shade600;
      case 'APPROVED':
        return Colors.green.shade600;
      case 'REJECTED':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  void _getCurrentLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location feature will be implemented with geolocator package'),
      ),
    );
  }

  void _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedVehicleTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one vehicle type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final request = ProviderRegistrationRequest(
      businessName: _businessNameController.text.isEmpty ? null : _businessNameController.text,
      chargerType: _selectedChargerType,
      vehicleTypes: _selectedVehicleTypes,
      address: _addressController.text,
      latitude: double.parse(_latitudeController.text),
      longitude: double.parse(_longitudeController.text),
      hourlyRate: double.parse(_hourlyRateController.text),
      description: _descriptionController.text,
      amenities: _selectedAmenities.isEmpty ? null : _selectedAmenities,
      contactNumber: _contactController.text,
    );

    final success = await ref.read(providerRegistrationProvider.notifier).submitProviderRequest(request);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provider request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(providerRequestStatusProvider);
      Navigator.pop(context);
    } else if (mounted) {
      final state = ref.read(providerRegistrationProvider);
      state.whenOrNull(
        error: (error, stack) {
          if (error.toString().contains('already have a provider request') ||
              error.toString().contains('409') ||
              error.toString().contains('Conflict')) {
            _showConflictDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to submit request: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    }
  }

  void _submitNewRequest() async {
    final cancelSuccess = await ref.read(providerRegistrationProvider.notifier).cancelProviderRequest();

    if (cancelSuccess) {
      setState(() {
        _hasCheckedExistingRequest = false;
        _businessNameController.clear();
        _streetAddressController.clear();
        _cityController.clear();
        _stateController.clear();
        _villageController.clear();
        _pincodeController.clear();
        _addressController.clear();
        _hourlyRateController.clear();
        _descriptionController.clear();
        _contactController.clear();
        _latitudeController.clear();
        _longitudeController.clear();
        _selectedChargerType = 'Type 2 AC';
        _selectedVehicleTypes.clear();
        _selectedAmenities.clear();
      });

      ref.invalidate(providerRequestStatusProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Previous request removed. You can now submit a new request.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove previous request. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showExistingRequestDialog(ProviderRequestStatus status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getStatusIcon(status.status),
              color: _getStatusColor(status.status),
            ),
            const SizedBox(width: 8),
            const Text('Existing Request Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You already have a provider request with status: ${status.status}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text('Submitted on: ${_formatDate(status.createdAt)}'),
            const SizedBox(height: 8),
            if (status.status == 'PENDING')
              Text(
                'Your request is currently under review. You can check the status or make updates if needed.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else if (status.status == 'REJECTED')
              Text(
                'Your previous request was rejected. You can submit a new request after removing the old one.',
                style: TextStyle(color: Colors.red.shade600),
              )
            else if (status.status == 'APPROVED')
              Text(
                'Congratulations! Your request has been approved. You can access your provider dashboard.',
                style: TextStyle(color: Colors.green.shade600),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('View Status'),
          ),
        ],
      ),
    );
  }

  void _showConflictDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: Colors.orange.shade600,
            ),
            const SizedBox(width: 8),
            const Text('Request Already Exists'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You already have a provider request in our system.',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please refresh the page to see your current request status.',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.invalidate(providerRequestStatusProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _showUpdateRequestDialog(ProviderRequestStatus status) {
    final hourlyRateController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You can update limited fields while your request is pending.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: hourlyRateController,
              decoration: const InputDecoration(
                labelText: 'New Hourly Rate (₹)',
                hintText: '50.00',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Updated Description',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updates = <String, dynamic>{};

              if (hourlyRateController.text.isNotEmpty) {
                final rate = double.tryParse(hourlyRateController.text);
                if (rate != null) updates['hourlyRate'] = rate;
              }

              if (descriptionController.text.isNotEmpty) {
                updates['description'] = descriptionController.text;
              }

              if (updates.isNotEmpty) {
                final success = await ref.read(providerRegistrationProvider.notifier).updateProviderRequest(updates);

                Navigator.pop(context);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  ref.invalidate(providerRequestStatusProvider);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update request'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showCancelRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Cancel Request'),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel your provider request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await ref.read(providerRegistrationProvider.notifier).cancelProviderRequest();

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Provider request cancelled successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                ref.invalidate(providerRequestStatusProvider);
                Navigator.pop(context);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to cancel request'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
