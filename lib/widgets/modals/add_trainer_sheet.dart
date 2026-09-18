import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/maps_launcher.dart';
import '../primary_button.dart';

/// "Trainer finden" — search the public trainer directory by name, or paste
/// an invitation link/code directly.
class AddTrainerSheet extends StatefulWidget {
  const AddTrainerSheet({super.key});

  @override
  State<AddTrainerSheet> createState() => _AddTrainerSheetState();
}

class _AddTrainerSheetState extends State<AddTrainerSheet> {
  final _search = TextEditingController();
  final _linkController = TextEditingController();
  Timer? _debounce;
  String? _linkingTrainerId;
  bool _submittingLink = false;

  @override
  void initState() {
    super.initState();
    // Show something on open rather than an empty list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().searchTrainers('');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      context.read<AppState>().searchTrainers(value);
    });
  }

  Future<void> _linkTo(AppState app, Profile trainer) async {
    final code = trainer.inviteCode;
    if (code == null) return;
    setState(() => _linkingTrainerId = trainer.id);
    await app.submitLinkCode(code);
    if (mounted) setState(() => _linkingTrainerId = null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reitlehrer finden', style: AppTextStyles.serif(size: 24)),
        const SizedBox(height: 6),
        Text(
          'Nach Namen oder Ort suchen — oder direkt einen Einladungslink einfügen.',
          style: AppTextStyles.sans(
            size: 12.5,
            color: AppColors.inkFaint(.55),
            height: 1.55,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: cardDecoration(shadowOpacity: .05),
          child: TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            style: AppTextStyles.sans(size: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              hintText: 'Name oder Ort …',
              hintStyle: AppTextStyles.sans(
                size: 14,
                color: AppColors.inkFaint(.4),
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 19,
                color: AppColors.inkFaint(.4),
              ),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 17,
                        color: AppColors.inkFaint(.4),
                      ),
                      onPressed: () {
                        _search.clear();
                        _onSearchChanged('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: app.searchingTrainers
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.green),
                )
              : app.trainerSearchResults.isEmpty
              ? Center(
                  child: Text(
                    'Keine Reitlehrer gefunden.',
                    style: AppTextStyles.sans(
                      size: 12.5,
                      color: AppColors.inkFaint(.5),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: app.trainerSearchResults.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final t = app.trainerSearchResults[i];
                    final alreadyLinked = app.linkedTrainers.any(
                      (l) => l.id == t.id,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                      decoration: cardDecoration(shadowOpacity: .05),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.fullName,
                                  style: AppTextStyles.sans(
                                    size: 13.5,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                if ((t.facility ?? '').isNotEmpty)
                                  Text(
                                    t.facility!,
                                    style: AppTextStyles.sans(
                                      size: 11.5,
                                      color: AppColors.inkFaint(.5),
                                    ),
                                  ),
                                if ((t.address ?? '').isNotEmpty)
                                  GestureDetector(
                                    onTap: () => openAddressInMaps(t.address!),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.place_outlined,
                                            size: 12,
                                            color: AppColors.green,
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              t.address!,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.sans(
                                                size: 11,
                                                weight: FontWeight.w600,
                                                color: AppColors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (alreadyLinked)
                            Text(
                              'Verknüpft',
                              style: AppTextStyles.sans(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: AppColors.mintText,
                              ),
                            )
                          else
                            SizedBox(
                              height: 32,
                              child: PrimaryButton(
                                label: 'Verknüpfen',
                                expand: false,
                                loading: _linkingTrainerId == t.id,
                                onPressed: () => _linkTo(app, t),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 18),
        Text(
          'ODER LINK/CODE EINFÜGEN',
          style: AppTextStyles.eyebrow(color: AppColors.inkFaint(.42)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: cardDecoration(shadowOpacity: .05),
          child: TextField(
            controller: _linkController,
            style: AppTextStyles.sans(size: 12.5),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'galoppal.de/t/…',
              contentPadding: EdgeInsets.symmetric(vertical: 3),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Schließen',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Verknüpfen',
                loading: _submittingLink,
                onPressed: () async {
                  setState(() => _submittingLink = true);
                  await app.submitLinkCode(_linkController.text);
                  if (context.mounted) {
                    setState(() => _submittingLink = false);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
