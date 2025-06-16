// lib/screens/provider_status_screen.dart - Fixed for current model structure
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/provider_models.dart';
import '../providers/provider_providers.dart';
import '../components/app_theme.dart';

class ProviderStatusScreen extends ConsumerStatefulWidget {
  const ProviderStatusScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProviderStatusScreen> createState() => _ProviderStatusScreenState();
}

class _ProviderStatusScreenState extends ConsumerState<ProviderStatusScreen> {
  @override
  Widget build(BuildContext context) {
    final requestStatusAsync = ref.watch(providerRequestStatusProvider);
    final managementState = ref.watch(providerManagementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: AppTheme.gradientBackground,
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(autoRefreshProviderStatusProvider.notifier).refreshProviderStatus();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(autoRefreshProviderStatusProvider.notifier).forceRefresh();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: requestStatusAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading provider status...'),
              ],
            ),
          ),
          error: (error, stack) => _buildErrorView(error.toString()),
          data: (requestStatus) {
            if (requestStatus == null) {
              return _buildNoRequestView();
            }
            return _buildStatusView(requestStatus, managementState);
          },
        ),
      ),
    );
  }

  Widget _buildNoRequestView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 50),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 64,
                    color: Colors.blue.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Provider Request Found',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You haven\'t submitted a provider request yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/become-provider');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Submit Provider Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 50),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Status',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ref.read(autoRefreshProviderStatusProvider.notifier).forceRefresh();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Try Again'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusView(ProviderRequestStatus status, AsyncValue<String?> managementState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header Card
          _buildStatusHeader(status),
          
          const SizedBox(height: 20),

          // Request Details Card
          _buildRequestDetails(status),

          const SizedBox(height: 20),

          // Status-specific actions
          if (status.status == 'PENDING') ...[
            _buildPendingActions(status, managementState),
          ] else if (status.status == 'APPROVED') ...[
            _buildApprovedActions(status),
          ] else if (status.status == 'REJECTED') ...[
            _buildRejectedActions(status, managementState),
          ],

          const SizedBox(height: 20),

          // Timeline Card
          _buildTimeline(status),

          const SizedBox(height: 20),

          // Help & Support Card
          _buildHelpSupportCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(ProviderRequestStatus status) {
    Color statusColor = _getStatusColor(status.status);
    IconData statusIcon = _getStatusIcon(status.status);

    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [statusColor.withOpacity(0.1), statusColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  size: 32,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Provider Request',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _getStatusMessage(status.status),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestDetails(ProviderRequestStatus status) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Request Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Request ID', status.id.toString()),
            _buildDetailRow('Status', status.status),
            _buildDetailRow('Submitted', _formatDate(status.createdAt)),
            if (status.updatedAt != status.createdAt)
              _buildDetailRow('Last Updated', _formatDate(status.updatedAt)),
            if (status.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingActions(ProviderRequestStatus status, AsyncValue<String?> managementState) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Text(
                  'Pending Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your request is under review. You can update certain details or cancel the request.',
              style: TextStyle(color: Colors.orange.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showUpdateRequestDialog(status),
                    icon: const Icon(Icons.edit),
                    label: const Text('Update Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: managementState.isLoading 
                        ? null 
                        : () => _showCancelDialog(),
                    icon: managementState.isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(managementState.isLoading ? 'Cancelling...' : 'Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedActions(ProviderRequestStatus status) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your provider request has been approved! You can now access your provider dashboard and start managing your charging station.',
              style: TextStyle(color: Colors.green.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/provider-dashboard');
                    },
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Open Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/provider-profile');
                    },
                    icon: const Icon(Icons.person),
                    label: const Text('Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade600,
                      side: BorderSide(color: Colors.green.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedActions(ProviderRequestStatus status, AsyncValue<String?> managementState) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text(
                  'Request Rejected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your provider request was not approved. Please review the feedback above and consider submitting a new request.',
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _submitNewRequest(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: managementState.isLoading 
                        ? null 
                        : () => _showCancelDialog(),
                    icon: managementState.isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(managementState.isLoading ? 'Removing...' : 'Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(ProviderRequestStatus status) {
    List<TimelineEvent> events = [];
    
    events.add(TimelineEvent(
      title: 'Request Submitted',
      date: status.createdAt,
      description: 'Your provider request was submitted for review',
      icon: Icons.send,
      isCompleted: true,
    ));

    if (status.status == 'PENDING') {
      events.add(TimelineEvent(
        title: 'Under Review',
        date: null,
        description: 'Our team is reviewing your application',
        icon: Icons.hourglass_empty,
        isCompleted: false,
        isCurrent: true,
      ));
    } else {
      events.add(TimelineEvent(
        title: 'Review Completed',
        date: status.updatedAt, // Use updatedAt instead of reviewedAt
        description: 'Application review has been completed',
        icon: Icons.check_circle,
        isCompleted: true,
      ));

      if (status.status == 'APPROVED') {
        events.add(TimelineEvent(
          title: 'Request Approved',
          date: status.updatedAt, // Use updatedAt instead of reviewedAt
          description: 'Congratulations! Your provider request has been approved',
          icon: Icons.celebration,
          isCompleted: true,
          isCurrent: true,
        ));
      } else if (status.status == 'REJECTED') {
        events.add(TimelineEvent(
          title: 'Request Rejected',
          date: status.updatedAt, // Use updatedAt instead of reviewedAt
          description: 'Your request was not approved. See details above.',
          icon: Icons.cancel,
          isCompleted: true,
          isCurrent: true,
          isError: true,
        ));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...events.map((event) => _buildTimelineItem(event, events)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(TimelineEvent event, List<TimelineEvent> events) {
    Color color = event.isError ? Colors.red.shade600 : 
                  event.isCurrent ? Colors.blue.shade600 :
                  event.isCompleted ? Colors.green.shade600 : Colors.grey.shade400;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                event.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (event != events.last)
              Container(
                width: 2,
                height: 50,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (event.date != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(event.date!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpSupportCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Help & Support',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Need help with your provider application? Our support team is here to help.',
              style: TextStyle(color: Colors.blue.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Open FAQ or help page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('FAQ feature coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.quiz),
                    label: const Text('FAQ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                      side: BorderSide(color: Colors.blue.shade600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Contact support
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Support contact feature coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contact Support'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                      side: BorderSide(color: Colors.blue.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ],
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

  String _getStatusMessage(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Your request is being reviewed by our team. This usually takes 2-3 business days.';
      case 'APPROVED':
        return 'Your provider request has been approved! You can now start managing your charging station.';
      case 'REJECTED':
        return 'Your request was not approved. Please review the feedback and consider reapplying.';
      default:
        return 'Status information is being loaded...';
    }
  }

  void _showUpdateRequestDialog(ProviderRequestStatus status) {
    final hourlyRateController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Request'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You can update limited fields while your request is pending review.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: hourlyRateController,
                decoration: const InputDecoration(
                  labelText: 'New Hourly Rate (₹)',
                  hintText: '50.00',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Updated Description',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
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
                if (rate != null && rate > 0) {
                  updates['hourlyRate'] = rate;
                }
              }
              
              if (descriptionController.text.isNotEmpty) {
                updates['description'] = descriptionController.text.trim();
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
                  final error = ref.read(providerRegistrationProvider).asError?.error.toString() ?? 'Unknown error';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update request: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter at least one field to update'),
                    backgroundColor: Colors.orange,
                  ),
                );
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

  void _showCancelDialog() {
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
          'Are you sure you want to cancel your provider request? This action cannot be undone and you will need to submit a new request if you want to become a provider.',
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
                final error = ref.read(providerRegistrationProvider).asError?.error.toString() ?? 'Unknown error';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to cancel request: $error'),
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

  void _submitNewRequest() async {
    // First cancel the existing rejected request
    final cancelSuccess = await ref.read(providerRegistrationProvider.notifier).cancelProviderRequest();
    
    if (cancelSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Previous request removed. Redirecting to new request form...'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the request status
      ref.invalidate(providerRequestStatusProvider);
      
      // Navigate to become provider screen
      Navigator.pushReplacementNamed(context, '/become-provider');
    } else if (mounted) {
      final error = ref.read(providerRegistrationProvider).asError?.error.toString() ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove previous request: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class TimelineEvent {
  final String title;
  final DateTime? date;
  final String description;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;
  final bool isError;

  TimelineEvent({
    required this.title,
    this.date,
    required this.description,
    required this.icon,
    this.isCompleted = false,
    this.isCurrent = false,
    this.isError = false,
  });
}