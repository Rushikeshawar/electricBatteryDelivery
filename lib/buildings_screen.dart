import 'package:flutter/material.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/components/dummy.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';

class BuildingsScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const BuildingsScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isLoading = true;
  List<Building> _buildings = [];

  // Sort options
  String _sortBy = 'distance'; // distance, price, availability
  final List<String> _filters = ['All', 'Available', 'Near Me', 'Premium'];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    setState(() => _isLoading = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _buildings = DummyData.buildings;
      _isLoading = false;
    });
    _animationController.forward();
  }

  List<Building> get _filteredBuildings {
    List<Building> buildings = [..._buildings];

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      buildings = buildings.where((building) {
        final query = _searchQuery.toLowerCase();
        return building.name.toLowerCase().contains(query) ||
            building.address.toLowerCase().contains(query);
      }).toList();
    }

    // Apply filters
    if (_selectedFilter != 'All') {
      buildings = buildings.where((building) {
        switch (_selectedFilter) {
          case 'Available':
            return building.availableSlots > 0;
          case 'Near Me':
            return building.distance <= 5.0;
          case 'Premium':
            return building.features['security'] == 'CCTV Monitored';
          default:
            return true;
        }
      }).toList();
    }

    // Apply sorting
    buildings.sort((a, b) {
      switch (_sortBy) {
        case 'distance':
          return a.distance.compareTo(b.distance);
        case 'price':
          return a.price.compareTo(b.price);
        case 'availability':
          return b.availableSlots.compareTo(a.availableSlots);
        default:
          return 0;
      }
    });

    return buildings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(context),
            _buildSearchBar(),
            _buildFilterBar(),
          ];
        },
        body: _buildBuildingsList(),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
                  Text(
                    'Charging Buildings',
                    style: AppTheme.headingStyle.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find secure charging locations near you',
                    style: AppTheme.subheadingStyle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          onSelected: (value) {
            setState(() => _sortBy = value);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'distance',
              child: Text('Sort by Distance'),
            ),
            const PopupMenuItem(
              value: 'price',
              child: Text('Sort by Price'),
            ),
            const PopupMenuItem(
              value: 'availability',
              child: Text('Sort by Availability'),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search buildings...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
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
                },
                backgroundColor: Colors.white,
                selectedColor: Colors.green.shade100,
                checkmarkColor: Colors.green.shade700,
                labelStyle: TextStyle(
                  color:
                      isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBuildingsList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
        ),
      );
    }

    final buildings = _filteredBuildings;
    if (buildings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apartment,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No buildings found',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: buildings.length,
      itemBuilder: (context, index) {
        final building = buildings[index];
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              (index / buildings.length),
              ((index + 1) / buildings.length),
              curve: Curves.easeOut,
            ),
          )),
          child: _buildBuildingCard(building),
        );
      },
    );
  }

  Widget _buildBuildingCard(Building building) {
    final hasAvailableSlots = building.availableSlots > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // Navigate to building details
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                image: building.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(building.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: building.imageUrl.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.apartment,
                        size: 64,
                        color: Colors.green.shade600,
                      ),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              building.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    building.address,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hasAvailableSlots
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hasAvailableSlots ? 'Available' : 'Full',
                          style: TextStyle(
                            color: hasAvailableSlots
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildFeatureChip(
                        icon: Icons.ev_station,
                        label:
                            '${building.availableSlots}/${building.totalSlots} slots',
                      ),
                      const SizedBox(width: 8),
                      _buildFeatureChip(
                        icon: Icons.route,
                        label: '${building.distance.toStringAsFixed(1)} km',
                      ),
                      if (building.features['security'] ==
                          'CCTV Monitored') ...[
                        const SizedBox(width: 8),
                        _buildFeatureChip(
                          icon: Icons.security,
                          label: 'CCTV',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${building.price}/slot',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'per day',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: hasAvailableSlots
                            ? () {
                                // Handle booking
                              }
                            : null,
                        icon: const Icon(Icons.flash_on),
                        label: const Text('Book Slot'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade700,
          ),
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

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
