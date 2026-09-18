import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/feature_request.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/tab_scroll_view.dart';

/// Open in-app board: any signed-in user can propose a feature and
/// up-/downvote others' proposals, sorted by net score.
class FeatureRequestsScreen extends StatefulWidget {
  const FeatureRequestsScreen({super.key});

  @override
  State<FeatureRequestsScreen> createState() => _FeatureRequestsScreenState();
}

class _FeatureRequestsScreenState extends State<FeatureRequestsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadFeatureRequests();
  }

  Future<void> _composeRequest(AppState app) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 22,
          right: 22,
          top: 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Feature vorschlagen', style: AppTextStyles.serif(size: 22)),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              autofocus: true,
              style: AppTextStyles.sans(size: 14),
              decoration: InputDecoration(
                hintText: 'Titel',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              style: AppTextStyles.sans(size: 13.5),
              decoration: InputDecoration(
                hintText: 'Beschreibung (optional)',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Vorschlagen',
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
    if (result == true) {
      await app.submitFeatureRequest(
        title: titleController.text,
        description: descriptionController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: TabScrollView(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chevron_left,
                    size: 18,
                    color: AppColors.green,
                  ),
                  Text(
                    'Profil',
                    style: AppTextStyles.sans(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Feature-Wünsche',
                    style: AppTextStyles.serif(size: 31, letterSpacing: -.3),
                  ),
                ),
                IconButton(
                  onPressed: () => _composeRequest(app),
                  icon: const Icon(
                    Icons.add_circle,
                    color: AppColors.blue,
                    size: 28,
                  ),
                ),
              ],
            ),
            Text(
              'Schlag vor, was Galoppal noch können soll — oder stimm für andere Vorschläge.',
              style: AppTextStyles.sans(
                size: 12.5,
                color: AppColors.inkFaint(.55),
              ),
            ),
            const SizedBox(height: 18),
            if (app.loadingFeatureRequests)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (app.sortedFeatureRequests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  'Noch keine Vorschläge. Sei der Erste!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sans(
                    size: 12.5,
                    color: AppColors.inkFaint(.5),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (final r in app.sortedFeatureRequests) ...[
                    _FeatureCard(app: app, request: r),
                    const SizedBox(height: 11),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.app, required this.request});

  final AppState app;
  final FeatureRequest request;

  @override
  Widget build(BuildContext context) {
    final score = app.featureScores[request.id] ?? 0;
    final myVote = app.myFeatureVotes[request.id];
    final isMine = request.authorId == app.profile?.id;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              InkWell(
                onTap: () => app.voteFeature(request.id, 1),
                child: Icon(
                  Icons.keyboard_arrow_up,
                  size: 22,
                  color: myVote == 1
                      ? AppColors.green
                      : AppColors.inkFaint(.35),
                ),
              ),
              Text(
                '$score',
                style: AppTextStyles.sans(size: 14, weight: FontWeight.w700),
              ),
              InkWell(
                onTap: () => app.voteFeature(request.id, -1),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 22,
                  color: myVote == -1
                      ? const Color(0xFFB3261E)
                      : AppColors.inkFaint(.35),
                ),
              ),
            ],
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
                        request.title,
                        style: AppTextStyles.sans(
                          size: 14.5,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isMine)
                      InkWell(
                        onTap: () => app.deleteFeatureRequest(request),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.inkFaint(.4),
                        ),
                      ),
                  ],
                ),
                if ((request.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    request.description!,
                    style: AppTextStyles.sans(
                      size: 12.5,
                      color: AppColors.inkFaint(.6),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'von ${request.authorName ?? 'Unbekannt'}',
                  style: AppTextStyles.sans(
                    size: 11,
                    color: AppColors.inkFaint(.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
