import 'package:flutter/material.dart';
import '../models/track.dart';

class ArtworkWidget extends StatelessWidget {
  final Track track;
  final int trackVersion;
  final ColorScheme colorScheme;

  const ArtworkWidget({
    super.key,
    required this.track,
    required this.trackVersion,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Card(
          key: ValueKey('${track.artwork}_$trackVersion'),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            track.artwork,
            width: 280,
            height: 280,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 280,
              height: 280,
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.music_off,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
