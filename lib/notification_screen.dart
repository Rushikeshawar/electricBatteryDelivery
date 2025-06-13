// enhanced_notification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:electric_battery_delivery_frontend/providers/notification_provider.dart';
import 'package:electric_battery_delivery_frontend/services/websocket_notification_service.dart';

class EnhancedNotificationScreen extends ConsumerStatefulWidget {
  const EnhancedNotificationScreen({super.key});

  @override
  ConsumerState<EnhancedNotificationScreen> createState() => _EnhancedNotificationScreenState();
}

class _EnhancedNotificationScreenState extends ConsumerState<EnhancedNotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showDebugInfo = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Fetch notifications when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(enhancedNotificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(enhancedNotificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
  icon: const Icon(Icons.arrow_back, color: Colors.white),
  onPressed: () {
    Navigator.pop(context);
  },
),
        actions: [
          // WebSocket status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: notificationState.isWebSocketConnected
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  notificationState.isWebSocketConnected
                      ? Icons.wifi
                      : Icons.wifi_off,
                  size: 16,
                  color: notificationState.isWebSocketConnected
                      ? Colors.white
                      : Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  notificationState.isWebSocketConnected ? 'Live' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: notificationState.isWebSocketConnected
                        ? Colors.white
                        : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // More options menu
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: (value) {
              switch (value) {
                case 'mark_all_read':
                  ref.read(enhancedNotificationProvider.notifier).markAllAsRead();
                  break;
                case 'refresh':
                  ref.read(enhancedNotificationProvider.notifier).fetchNotifications();
                  break;
                case 'reconnect':
                  ref.read(enhancedNotificationProvider.notifier).reconnectWebSocket();
                  break;
                case 'test':
                  ref.read(enhancedNotificationProvider.notifier).testWebSocketConnection();
                  break;
                case 'debug':
                  setState(() {
                    _showDebugInfo = !_showDebugInfo;
                  });
                  break;
                case 'clear_realtime':
                  ref.read(enhancedNotificationProvider.notifier).clearRealtimeNotifications();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all),
                    SizedBox(width: 8),
                    Text('Mark All Read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reconnect',
                child: Row(
                  children: [
                    Icon(Icons.wifi),
                    SizedBox(width: 8),
                    Text('Reconnect WebSocket'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'test',
                child: Row(
                  children: [
                    Icon(Icons.bug_report),
                    SizedBox(width: 8),
                    Text('Test Notification'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'debug',
                child: Row(
                  children: [
                    Icon(Icons.info),
                    SizedBox(width: 8),
                    Text('Debug Info'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_realtime',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Real-time'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'All (${notificationState.notifications.length})',
              icon: const Icon(Icons.notifications),
            ),
            Tab(
              text: 'Live (${notificationState.realtimeNotifications.length})',
              icon: const Icon(Icons.wifi),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Connection status banner
          if (!notificationState.isWebSocketConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Real-time notifications unavailable: ${notificationState.webSocketStatus}',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(enhancedNotificationProvider.notifier).reconnectWebSocket();
                    },
                    child: Text(
                      'Reconnect',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),

          // Debug info panel
          if (_showDebugInfo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'WebSocket Status: ${notificationState.webSocketStatus}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Connected: ${notificationState.isWebSocketConnected}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Unread Count: ${notificationState.unreadCount}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    'API Notifications: ${notificationState.notifications.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Real-time Notifications: ${notificationState.realtimeNotifications.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

          // Main content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Notifications Tab
                _buildAllNotificationsTab(notificationState),
                // Real-time Notifications Tab
                _buildRealtimeNotificationsTab(notificationState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllNotificationsTab(EnhancedNotificationState notificationState) {
    if (notificationState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 16),
            Text('Loading notifications...'),
          ],
        ),
      );
    }

    if (notificationState.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading notifications',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                notificationState.errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(enhancedNotificationProvider.notifier).fetchNotifications(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (notificationState.notifications.isEmpty) {
      return _buildEmptyState('No notifications yet', 'We\'ll notify you when there\'s something new');
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(enhancedNotificationProvider.notifier).fetchNotifications();
      },
      color: Colors.green.shade600,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: notificationState.notifications.length,
        itemBuilder: (context, index) {
          final notification = notificationState.notifications[index];
          return _buildNotificationCard(
            notification.id ?? 0, // Provide default value for null ID
            notification.title ?? 'Notification',
            notification.message ?? '',
            notification.type,
            notification.createdAt,
            notification.isRead,
            notification.data,
            false, // isRealtime
          );
        },
      ),
    );
  }

  Widget _buildRealtimeNotificationsTab(EnhancedNotificationState notificationState) {
    if (notificationState.realtimeNotifications.isEmpty) {
      return _buildEmptyState(
        'No real-time notifications',
        notificationState.isWebSocketConnected
            ? 'Real-time notifications will appear here instantly'
            : 'Connect to WebSocket to receive real-time notifications',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: notificationState.realtimeNotifications.length,
      itemBuilder: (context, index) {
        final notification = notificationState.realtimeNotifications[index];
        return _buildNotificationCard(
          notification.id,
          notification.title,
          notification.message,
          notification.type,
          notification.createdAt,
          notification.isRead,
          notification.data,
          true, // isRealtime
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    int id,
    String title,
    String message,
    String type,
    DateTime createdAt,
    bool isRead,
    Map<String, dynamic> data,
    bool isRealtime,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    // Get icon and color based on notification type
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'ORDER_STATUS':
        icon = Icons.local_shipping_outlined;
        iconColor = Colors.blue;
        break;
      case 'NEW_ORDER':
        icon = Icons.shopping_bag_outlined;
        iconColor = Colors.green;
        break;
      case 'NEW_ASSIGNMENT':
        icon = Icons.assignment_outlined;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.notifications_outlined;
        iconColor = Colors.purple;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      
      child: InkWell(
        onTap: () {
          _handleNotificationTap(id, type, data);
        },
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Notification details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateFormat.format(createdAt),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            if (isRealtime)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
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
            // Real-time indicator
            if (isRealtime)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap(int id, String type, Map<String, dynamic> data) async {
    // Mark notification as read
    ref.read(enhancedNotificationProvider.notifier).markAsRead(id);

    // Navigate based on notification type
    if (type == 'ORDER_STATUS' &&
        data['orderId'] != null) {
      Navigator.pushNamed(
        context,
        '/order-detail',
        arguments: {'orderId': data['orderId']},
      );
    } else if (type == 'NEW_ASSIGNMENT' &&
               data['orderId'] != null) {
      Navigator.pushNamed(
        context,
        '/order-detail',
        arguments: {'orderId': data['orderId']},
      );
    }
  }
}