import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/season_controller.dart';
import '../models/season_model.dart';
import '../../sessions/pages/sessions_list_page.dart';
import '../../sessions/pages/create_session_page.dart';
import '../../sessions/widgets/session_card.dart';
import '../../sessions/controllers/session_controller.dart';
import '../../sessions/pages/edit_session_page.dart';
import '../../plantation/controllers/plantation_controller.dart';
import '../pages/edit_season_page.dart';
import '../../../../core/widgets/loading_spinner.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/utils/constants.dart';

class SeasonDetailsPage extends ConsumerWidget {
  final String seasonId;

  const SeasonDetailsPage({super.key, required this.seasonId});

  Future<void> _deleteSeason(BuildContext context, WidgetRef ref, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Season'),
        content: const Text('Are you sure you want to delete this season? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(seasonControllerProvider.notifier).deleteSeason(seasonId, userId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Season deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonAsync = ref.watch(seasonProvider(seasonId));
    final storage = const FlutterSecureStorage();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Season Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditSeasonPage(seasonId: seasonId),
                ),
              );
              if (result == true) {
                ref.invalidate(seasonProvider(seasonId));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final userId = await storage.read(key: AppConstants.userIdKey);
              if (userId != null) {
                _deleteSeason(context, ref, userId);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(seasonProvider(seasonId));
          ref.invalidate(sessionControllerProvider(seasonId));
        },
        child: seasonAsync.when(
          data: (season) {
            final farmAsync = ref.watch(farmProvider(season.farmId));
            final sessionsState = ref.watch(sessionControllerProvider(seasonId));
            
            return CustomScrollView(
            slivers: [
              // Season Information Card - Matching farm details style
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            season.seasonName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          // Farm Name and District
                          farmAsync.when(
                            data: (farm) => Column(
                              children: [
                                _buildInfoRow(context, 'Farm', farm.farmName),
                                _buildInfoRow(context, 'District', farm.district),
                              ],
                            ),
                            loading: () => _buildInfoRow(context, 'Farm', 'Loading...'),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          _buildInfoRow(context, 'Harvest Period', season.period),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Sessions Section Header
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[100],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Harvesting Sessions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              // Sessions List
              sessionsState.when(
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: const EmptyState(
                          message: 'No harvesting sessions recorded yet.\nTap the + button below to add your first session.',
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.only(bottom: 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final session = sessions[index];
                          return SessionCard(
                            session: session,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditSessionPage(
                                    sessionId: session.id,
                                    seasonId: seasonId,
                                  ),
                                ),
                              );
                              if (result == true) {
                                ref.invalidate(sessionControllerProvider(seasonId));
                              }
                            },
                          );
                        },
                        childCount: sessions.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: LoadingSpinner(message: 'Loading sessions...'),
                ),
                error: (error, stack) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${error.toString()}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(sessionControllerProvider(seasonId));
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            );
          },
          loading: () => const LoadingSpinner(message: 'Loading season...'),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: ${error.toString()}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(seasonProvider(seasonId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        ),
      ),
      floatingActionButton: seasonAsync.when(
        data: (_) => FloatingActionButton.extended(
          heroTag: 'season_details_fab',
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateSessionPage(seasonId: seasonId),
              ),
            );
            if (result == true && context.mounted) {
              // Refresh sessions list
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Session'),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

