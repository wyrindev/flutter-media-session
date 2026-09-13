import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_media_session/flutter_media_session.dart';

class SettingsPanel extends StatelessWidget {
  final bool active;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;
  final Set<MediaAction>? availableActions;
  final void Function(Set<MediaAction>) onActionsChanged;
  final MediaAction shuffleAction;
  final MediaAction repeatAction;
  final bool handlesInterruptions;
  final void Function(bool) onHandleInterruptionsChanged;
  final bool backgroundKeepAlive;
  final void Function(bool) onBackgroundKeepAliveChanged;

  const SettingsPanel({
    super.key,
    required this.active,
    required this.onActivate,
    required this.onDeactivate,
    required this.availableActions,
    required this.onActionsChanged,
    required this.shuffleAction,
    required this.repeatAction,
    required this.handlesInterruptions,
    required this.onHandleInterruptionsChanged,
    required this.backgroundKeepAlive,
    required this.onBackgroundKeepAliveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Center(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Active'),
                icon: Icon(Icons.sensors),
              ),
              ButtonSegment(
                value: false,
                label: Text('Inactive'),
                icon: Icon(Icons.sensors_off),
              ),
            ],
            selected: {active},
            onSelectionChanged: (set) {
              final val = set.first;
              if (val != active) val ? onActivate() : onDeactivate();
            },
          ),
        ),
        const SizedBox(height: 32),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: active
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "System Control Actions",
                      style: textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilterChip(
                          label: const Text("All"),
                          selected: availableActions?.length == 10,
                          onSelected: (selected) {
                            if (selected) {
                              onActionsChanged({
                                MediaAction.play,
                                MediaAction.pause,
                                MediaAction.skipToNext,
                                MediaAction.skipToPrevious,
                                MediaAction.seekTo,
                                MediaAction.stop,
                                MediaAction.rewind,
                                MediaAction.fastForward,
                                shuffleAction,
                                repeatAction,
                              });
                            } else {
                              onActionsChanged({});
                            }
                          },
                        ),
                        for (final action in [
                          MediaAction.play,
                          MediaAction.pause,
                          MediaAction.skipToNext,
                          MediaAction.skipToPrevious,
                          MediaAction.seekTo,
                          MediaAction.stop,
                          MediaAction.rewind,
                          MediaAction.fastForward,
                          shuffleAction,
                          repeatAction,
                        ])
                          _singleActionChip(action),
                      ],
                    ),
                    if (!kIsWeb && Platform.isAndroid) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text("Handle Audio Focus"),
                        subtitle: const Text(
                            "Automatically pause during phone calls or when other apps play audio"),
                        value: handlesInterruptions,
                        onChanged: onHandleInterruptionsChanged,
                      ),
                    ],
                    if (!kIsWeb && !Platform.isIOS) ...[
                      if (kIsWeb || !Platform.isAndroid) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],
                      SwitchListTile(
                        title: const Text("Background Keep-Alive"),
                        subtitle: const Text(
                            "Keep device awake during off-device playback (such as casting)"),
                        value: backgroundKeepAlive,
                        onChanged: onBackgroundKeepAliveChanged,
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _singleActionChip(MediaAction action) {
    final isSelected = availableActions?.any((a) => a.name == action.name) ?? false;

    return FilterChip(
      label: Text(action.name),
      selected: isSelected,
      onSelected: (selected) {
        final newActions = Set<MediaAction>.from(availableActions ?? {});
        if (selected) {
          if (action.name == 'shuffle') {
            newActions.add(shuffleAction);
          } else if (action.name == 'repeat') {
            newActions.add(repeatAction);
          } else {
            newActions.add(action);
          }
        } else {
          newActions.removeWhere((a) => a.name == action.name);
        }
        onActionsChanged(newActions);
      },
    );
  }
}
