import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/models/order_model.dart';
import 'package:electric_battery_delivery_frontend/providers/order_history_provider.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  final String userName;
  final String userEmail;

  const OrderHistoryScreen({
    Key? key,
    required this.userName,
    required this.userEmail,
  }) : super(key: key);

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize provider and load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notifier = ref.read(orderHistoryProvider.notifier);
        notifier.setTabController(_tabController);
        notifier.loadOrders(refresh: true);
      }
    });

    // Setup optimized scroll listener
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted || _isLoadingMore) return;
    
    // Trigger pagination when near bottom (200px threshold)
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      await ref.read(orderHistoryProvider.notifier).loadMoreOrders();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Watch providers
    final orderHistoryState = ref.watch(orderHistoryProvider);
    final statusFilters = ref.watch(orderStatusFiltersProvider);
    final formatters = ref.watch(formattersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.green,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(orderHistoryProvider.notifier).loadOrders(refresh: true);
        },
        child: Column(
          children: [
            _buildSearchBar(orderHistoryState),
            _buildFilterBar(statusFilters, orderHistoryState),
            _buildTabBar(_tabController),
            Expanded(
              child: _buildOrderList(orderHistoryState, formatters),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.read(orderHistoryProvider.notifier).loadOrders(refresh: true);
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildSearchBar(OrderHistoryState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: TextField(
        controller: state.searchController,
        decoration: InputDecoration(
          hintText: 'Search orders...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: state.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    ref.read(orderHistoryProvider.notifier).clearSearch();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          ref.read(orderHistoryProvider.notifier).updateSearchQuery(value);
        },
      ),
    );
  }

  Widget _buildFilterBar(List<Map<String, String>> statusFilters, OrderHistoryState state) {
    return Container(
      height: 60,
      color: Colors.grey.shade50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: statusFilters.length,
        itemBuilder: (context, index) {
          final filter = statusFilters[index];
          final isSelected = filter['value'] == state.selectedStatus;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (selected) {
                ref.read(orderHistoryProvider.notifier)
                    .updateSelectedStatus(filter['value']!);
              },
              backgroundColor: Colors.white,
              selectedColor: Colors.green.shade100,
              checkmarkColor: Colors.green.shade700,
              labelStyle: TextStyle(
                color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.green.shade300 : Colors.grey.shade300,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar(TabController tabController) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: tabController,
        indicatorColor: Colors.green.shade600,
        labelColor: Colors.green.shade600,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Pending'),
          Tab(text: 'Completed'),
          Tab(text: 'In Progress'),
        ],
      ),
    );
  }

  Widget _buildOrderList(OrderHistoryState state, Map<String, dynamic> formatters) {
    // Show loading indicator for initial load
    if (state.isLoading && state.orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 16),
            Text('Loading orders...'),
          ],
        ),
      );
    }

    // Show error state
    if (state.errorMessage != null && state.orders.isEmpty) {
      return Center(
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
              'Error: ${state.errorMessage}',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(orderHistoryProvider.notifier).loadOrders(refresh: true);
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final dateFormat = formatters['date'] as DateFormat;
    final currencyFormat = formatters['currency'] as NumberFormat;

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOrderTab(state.pendingOrders, dateFormat, currencyFormat, state.isLoadingMore),
        _buildOrderTab(state.completedOrders, dateFormat, currencyFormat, state.isLoadingMore),
        _buildOrderTab(state.inProgressOrders, dateFormat, currencyFormat, state.isLoadingMore),
      ],
    );
  }

  Widget _buildOrderTab(List<Order> orders, DateFormat dateFormat, NumberFormat currencyFormat, bool isLoadingMore) {
    if (orders.isEmpty && !isLoadingMore) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No orders found',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) => _buildOrderCard(
            orders[index], 
            dateFormat, 
            currencyFormat
          ),
        ),
        // Loading indicator for pagination
        if (isLoadingMore)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderCard(Order order, DateFormat dateFormat, NumberFormat currencyFormat) {
    final statusColor = order.statusColor;
    final createdDate = DateTime.parse(order.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ID: ${order.id}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      order.formattedStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Battery info
              Text(
                '${order.batteryType} x${order.quantity}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              
              // Station and date
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.station.name,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(createdDate),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Price
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(order.totalPrice),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Optimized order details dialog
  Future<void> _showOrderDetails(Order order) async {
    try {
      // Show loading dialog first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Fetch latest order details
      final updatedOrder = await ref.read(orderHistoryProvider.notifier)
          .getOrderDetails(order.id);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show order details
      if (mounted && updatedOrder != null) {
        _showOrderDetailsDialog(updatedOrder);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show error and use current order
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch latest details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        _showOrderDetailsDialog(order);
      }
    }
  }

  void _showOrderDetailsDialog(Order order) {
    final formatters = ref.read(formattersProvider);
    final dateFormat = formatters['dateTime'] as DateFormat;
    final currencyFormat = formatters['currency'] as NumberFormat;

    final createdDate = DateTime.parse(order.createdAt);
    final updatedDate = DateTime.parse(order.updatedAt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildOrderHeader(order),
                    const SizedBox(height: 24),

                    // Order summary
                    _buildOrderSummary(order, currencyFormat, createdDate, updatedDate, dateFormat),
                    const SizedBox(height: 20),

                    // Battery details
                    _buildDetailSection(
                      'Battery Details',
                      Icons.battery_charging_full,
                      Colors.green,
                      [
                        _buildDetailRow('Battery Type', order.batteryType),
                        _buildDetailRow('Quantity', order.quantity.toString()),
                        _buildDetailRow('Price per Unit', currencyFormat.format(order.totalPrice / order.quantity)),
                        _buildDetailRow('Total Price', currencyFormat.format(order.totalPrice)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Station details
                    _buildDetailSection(
                      'Station Details',
                      Icons.charging_station,
                      Colors.blue,
                      [
                        _buildDetailRow('Station Name', order.station.name),
                        _buildDetailRow('Address', order.station.address),
                        if (order.station.phone != null)
                          _buildDetailRow('Contact', order.station.phone!),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Delivery details
                    _buildDetailSection(
                      'Delivery Details',
                      Icons.local_shipping,
                      Colors.orange,
                      [
                        _buildDetailRow('Delivery Address', order.deliveryAddress),
                        if (order.deliveryNotes != null && order.deliveryNotes!.isNotEmpty)
                          _buildDetailRow('Notes', order.deliveryNotes!),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Driver details if assigned
                    if (order.driver != null)
                      _buildDriverSection(order),

                    const SizedBox(height: 32),

                    // Action buttons
                    _buildActionButtons(order),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader(Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade200.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.receipt_outlined,
              color: Colors.green.shade700,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${order.id}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: order.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: order.statusColor.withOpacity(0.3),
              ),
            ),
            child: Text(
              order.formattedStatus,
              style: TextStyle(
                color: order.statusColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(Order order, NumberFormat currencyFormat, DateTime createdDate, DateTime updatedDate, DateFormat dateFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Amount',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 16,
                ),
              ),
              Text(
                currencyFormat.format(order.totalPrice),
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildDetailRow('Created', dateFormat.format(createdDate)),
          const SizedBox(height: 8),
          _buildDetailRow('Last Updated', dateFormat.format(updatedDate)),
        ],
      ),
    );
  }

  Widget _buildDriverSection(Order order) {
    return _buildDetailSection(
      'Driver Details',
      Icons.person,
      Colors.purple,
      [
        _buildDetailRow('Driver Name', order.driver!.name),
        _buildDetailRow('Phone Number', order.driver!.phone),
      ],
      actionButton: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.phone, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Calling ${order.driver!.name}...'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
        icon: const Icon(Icons.phone),
        label: const Text('Call Driver'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Order order) {
    if (order.status == 'PENDING' || order.status == 'CONFIRMED' || order.status == 'ASSIGNED') {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          _showCancelOrderDialog(order);
        },
        icon: const Icon(Icons.cancel),
        label: const Text('Cancel Order'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.red,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    if (order.status == 'DELIVERED') {
      return Column(
        children: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Download invoice feature coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('Download Invoice'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reorder feature coming soon'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.repeat),
            label: const Text('Reorder'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: BorderSide(color: Colors.green.shade300, width: 2),
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }

    if (order.status == 'IN_TRANSIT' || order.status == 'PICKED_UP') {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order tracking coming soon'),
              backgroundColor: Colors.blue,
            ),
          );
        },
        icon: const Icon(Icons.location_on),
        label: const Text('Track Order'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return Container();
  }

  Widget _buildDetailSection(
    String title,
    IconData icon,
    MaterialColor color,
    List<Widget> children,
    {Widget? actionButton}
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            height: 1,
            color: Colors.grey.shade200,
          ),
          ...children,
          if (actionButton != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: actionButton,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelOrderDialog(Order order) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade200.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Cancel Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to cancel this order?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Order summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${order.batteryType} x ${order.quantity}',
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Warning
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This action cannot be undone.',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Keep Order'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();

                              // Show loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cancelling order...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );

                              // Cancel order
                              final success = await ref.read(orderHistoryProvider.notifier)
                                  .cancelOrder(order.id);

                              // Show result
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          success ? Icons.check_circle : Icons.error,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            success 
                                                ? 'Order cancelled successfully'
                                                : 'Failed to cancel order',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: success ? Colors.green : Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel Order'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}