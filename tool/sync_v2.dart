// ignore_for_file: avoid_print

import 'dart:io';

/// Script to sync v3 updates on `main` tag release to `support/v2` branch.
///
/// Usage:
///   dart run tool/sync_v2.dart [--tag=v3.X.Y] [--dry-run]
void main(List<String> args) async {
  final tagArg = args.firstWhere(
    (a) => a.startsWith('--tag='),
    orElse: () => '',
  );
  final isDryRun = args.contains('--dry-run');

  String tagName = tagArg.isNotEmpty
      ? tagArg.substring('--tag='.length)
      : Platform.environment['GITHUB_REF_NAME'] ?? '';

  if (tagName.isEmpty) {
    // Try getting latest tag on main
    final res = await _runGit(['tag', '--points-at', 'HEAD']);
    if (res.stdout.toString().trim().isNotEmpty) {
      tagName = res.stdout.toString().trim().split('\n').first;
    }
  }

  if (tagName.isEmpty) {
    print(
        '❌ Error: No tag specified. Use --tag=v3.X.Y or run in GitHub Actions with a tag.');
    exit(1);
  }

  print('🚀 Starting v2 sync process for tag: $tagName (Dry-run: $isDryRun)');

  // 1. Parse v3 version from tag
  final v3VersionStr = tagName.startsWith('v') ? tagName.substring(1) : tagName;
  final v3Version = _SemVer.parse(v3VersionStr);
  if (v3Version == null) {
    print('❌ Error: Could not parse semantic version from tag $tagName');
    exit(1);
  }

  // Ensure origin/support/v2 and tags are fetched
  await _runGit(['fetch', 'origin', 'support/v2', '--tags']);

  // 2. Find previous v3 tag
  final allTagsRes = await _runGit(['tag', '-l', 'v3.*']);
  final v3Tags = allTagsRes.stdout
      .toString()
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  v3Tags.sort((a, b) {
    final va = _SemVer.parse(a.startsWith('v') ? a.substring(1) : a);
    final vb = _SemVer.parse(b.startsWith('v') ? b.substring(1) : b);
    if (va == null || vb == null) return 0;
    return va.compareTo(vb);
  });

  String? previousV3Tag;
  final currentTagIndex = v3Tags.indexOf(tagName);
  if (currentTagIndex > 0) {
    previousV3Tag = v3Tags[currentTagIndex - 1];
  } else if (v3Tags.isNotEmpty && v3Tags.last != tagName) {
    previousV3Tag = v3Tags.last;
  }

  print('📌 Current v3 tag: $tagName (Version: $v3Version)');
  print('📌 Previous v3 tag: ${previousV3Tag ?? "None found"}');

  // 3. Check if syncable files changed
  if (previousV3Tag != null) {
    final diffRes =
        await _runGit(['diff', '--name-only', previousV3Tag, tagName]);
    final changedFiles = diffRes.stdout
        .toString()
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    print(
        '🔍 Changed files between $previousV3Tag and $tagName: ${changedFiles.length} files');

    final syncableDirs = [
      'lib/',
      'android/',
      'darwin/',
      'windows/',
      'test/',
      'example/'
    ];
    final syncableFiles = ['README.md', 'pubspec.yaml'];

    final hasSyncableChanges = changedFiles.any((file) {
      if (syncableFiles.contains(file)) return true;
      return syncableDirs.any((dir) => file.startsWith(dir));
    });

    if (!hasSyncableChanges) {
      print(
          '✅ No syncable files (lib, native, tests, example, README, pubspec) changed in $tagName.');
      print('⏩ Skipping v2 sync.');
      return;
    }
  }

  // 4. Calculate v2 version increment
  _SemVer? prevV3Version;
  if (previousV3Tag != null) {
    prevV3Version = _SemVer.parse(
      previousV3Tag.startsWith('v')
          ? previousV3Tag.substring(1)
          : previousV3Tag,
    );
  }

  // Get current v2 version from origin/support/v2:pubspec.yaml
  final v2PubspecRes =
      await _runGit(['show', 'origin/support/v2:pubspec.yaml']);
  final v2VersionMatch = RegExp(r'^version:\s*([^\s+]+)', multiLine: true)
      .firstMatch(v2PubspecRes.stdout.toString());
  if (v2VersionMatch == null) {
    print(
        '❌ Error: Could not read version from origin/support/v2:pubspec.yaml');
    exit(1);
  }

  final currentV2VersionStr = v2VersionMatch.group(1)!;
  final currentV2Version = _SemVer.parse(currentV2VersionStr);
  if (currentV2Version == null) {
    print('❌ Error: Could not parse current v2 version: $currentV2VersionStr');
    exit(1);
  }

  final newV2Version = _calculateNewV2Version(
    currentV2Version: currentV2Version,
    prevV3Version: prevV3Version,
    currV3Version: v3Version,
  );

  print('💡 Current v2 Version: $currentV2Version');
  print('💡 New v2 Target Version: $newV2Version');

  // 5. Setup temporary worktree for support/v2
  final tempDir = Directory.systemTemp.createTempSync('v2_sync_worktree_');
  final worktreePath = tempDir.path;

  try {
    print('📂 Adding git worktree at $worktreePath');
    await _runGit(['worktree', 'add', worktreePath, 'origin/support/v2']);

    // Ensure git user configured in worktree
    await _ensureGitConfigured(worktreePath);

    // Copy syncable directories/files from current v3 tag/HEAD to worktree
    final syncDirs = ['lib', 'android', 'darwin', 'windows', 'test', 'example'];
    for (final dir in syncDirs) {
      final targetDir = Directory('$worktreePath/$dir');
      if (targetDir.existsSync()) {
        targetDir.deleteSync(recursive: true);
      }
      final srcDir = Directory(dir);
      if (srcDir.existsSync()) {
        _copyDirectory(srcDir, targetDir);
      }
    }

    // Process pubspec.yaml in v2 worktree
    final v2PubspecFile = File('$worktreePath/pubspec.yaml');
    if (v2PubspecFile.existsSync()) {
      var content = v2PubspecFile.readAsStringSync();
      content = content.replaceFirst(
        RegExp(r'^version:\s*.*$', multiLine: true),
        'version: $newV2Version',
      );
      v2PubspecFile.writeAsStringSync(content);
    }

    // Process README.md in v2 worktree
    final srcReadmeFile = File('README.md');
    if (srcReadmeFile.existsSync()) {
      var readmeContent = srcReadmeFile.readAsStringSync();
      // Replace version references in installation instructions
      readmeContent = readmeContent.replaceAll(
        RegExp(r'flutter_media_session:\s*\^\d+\.\d+\.\d+'),
        'flutter_media_session: ^$newV2Version',
      );

      // Adjust note under installation section to clarify v2 maintenance status and link to main branch docs
      final v3NotePattern = RegExp(
        r'> \*\*Note\*\*: Version 3\.x is a complete architectural overhaul\.[^\n]*',
      );
      const v2NoteReplacement =
          '> **Note**: This branch maintains the **v2 legacy release line**. '
          'For the latest 3.x features and documentation, visit the [main branch](https://github.com/wyrindev/flutter-media-session/tree/main).';

      if (v3NotePattern.hasMatch(readmeContent)) {
        readmeContent =
            readmeContent.replaceFirst(v3NotePattern, v2NoteReplacement);
      }

      File('$worktreePath/README.md').writeAsStringSync(readmeContent);
    }

    // Process CHANGELOG.md in v2 worktree
    final mainChangelogFile = File('CHANGELOG.md');
    final v2ChangelogFile = File('$worktreePath/CHANGELOG.md');
    if (mainChangelogFile.existsSync() && v2ChangelogFile.existsSync()) {
      final v3Notes = _extractChangelogSection(
          mainChangelogFile.readAsStringSync(), v3VersionStr);
      final existingV2Changelog = v2ChangelogFile.readAsStringSync();

      final changelogBody = v3Notes.isNotEmpty
          ? v3Notes
          : "* Synchronized fixes and maintenance updates from $tagName.";

      final newV2Entry = '## $newV2Version\n\n$changelogBody\n\n';

      v2ChangelogFile.writeAsStringSync(newV2Entry + existingV2Changelog);
    }

    // 6. Run validation checks (`flutter analyze` & `flutter test`) in worktree
    print('🧪 Running validation tests on synced v2 codebase...');
    final analyzeResult = await _runProcess('flutter', ['analyze'],
        workingDirectory: worktreePath);
    final testResult =
        await _runProcess('flutter', ['test'], workingDirectory: worktreePath);

    final is100PercentSafe =
        analyzeResult.exitCode == 0 && testResult.exitCode == 0;

    print('📊 Analysis Exit Code: ${analyzeResult.exitCode}');
    print('📊 Test Exit Code: ${testResult.exitCode}');

    if (isDryRun) {
      print(
          '🔍 [Dry-Run] Completed verification. 100% Safe: $is100PercentSafe');
      return;
    }

    final newTagName = 'v$newV2Version';

    if (is100PercentSafe) {
      print(
          '✅ Codebase is 100% verified. Directly committing and pushing to support/v2...');
      await _runGit(['-C', worktreePath, 'add', '.']);
      await _runGit([
        '-C',
        worktreePath,
        'commit',
        '-m',
        'chore(v2): sync v3 updates for release $newV2Version',
      ]);
      await _runGit(['-C', worktreePath, 'tag', newTagName]);
      await _runGit(
          ['-C', worktreePath, 'push', 'origin', 'HEAD:support/v2', '--tags']);
      print('🎉 Successfully updated support/v2 and pushed tag $newTagName');
    } else {
      print(
          '⚠️ Validation checks failed or require review. Opening Pull Request...');
      final branchName = 'auto/sync-$tagName-to-v2';
      await _runGit(['-C', worktreePath, 'checkout', '-b', branchName]);
      await _runGit(['-C', worktreePath, 'add', '.']);
      await _runGit([
        '-C',
        worktreePath,
        'commit',
        '-m',
        'chore(v2): backport $tagName updates (requires review)',
      ]);
      await _runGit(
          ['-C', worktreePath, 'push', '-u', 'origin', branchName, '--force']);

      // Create Pull Request using gh CLI
      final prTitle = 'sync(v2): backport $tagName updates ($newV2Version)';
      final prBody = '''
### Automated v3 -> v2 Backport

* **Source v3 Tag**: `$tagName`
* **Target v2 Version**: `$newV2Version`
* **Status**: Automated verification flagged items requiring manual review.

#### Validation Results
* `flutter analyze`: ${analyzeResult.exitCode == 0 ? "PASSED" : "FAILED"}
* `flutter test`: ${testResult.exitCode == 0 ? "PASSED" : "FAILED"}

Please inspect the changes and merge once verified.
''';

      final ghPrRes = await _runProcess(
        'gh',
        [
          'pr',
          'create',
          '--base',
          'support/v2',
          '--head',
          branchName,
          '--title',
          prTitle,
          '--body',
          prBody,
          '--reviewer',
          'wyrindev',
        ],
        workingDirectory: worktreePath,
      );

      print('📋 PR Creation output: ${ghPrRes.stdout}');
      if (ghPrRes.stderr.toString().isNotEmpty) {
        print('📋 PR Creation stderr: ${ghPrRes.stderr}');
      }
    }
  } finally {
    print('🧹 Cleaning up worktree...');
    await _runGit(['worktree', 'remove', '--force', worktreePath]);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}

Future<void> _ensureGitConfigured(String workingDirectory) async {
  final nameRes =
      await _runGit(['-C', workingDirectory, 'config', 'user.name']);
  if (nameRes.stdout.toString().trim().isEmpty) {
    await _runGit(
        ['-C', workingDirectory, 'config', 'user.name', 'github-actions[bot]']);
  }
  final emailRes =
      await _runGit(['-C', workingDirectory, 'config', 'user.email']);
  if (emailRes.stdout.toString().trim().isEmpty) {
    await _runGit([
      '-C',
      workingDirectory,
      'config',
      'user.email',
      'github-actions[bot]@users.noreply.github.com',
    ]);
  }
}

_SemVer _calculateNewV2Version({
  required _SemVer currentV2Version,
  required _SemVer? prevV3Version,
  required _SemVer currV3Version,
}) {
  if (prevV3Version == null) {
    return currentV2Version.incrementPatch();
  }

  if (currV3Version.minor > prevV3Version.minor ||
      currV3Version.major > prevV3Version.major) {
    return currentV2Version.incrementMinor();
  } else {
    return currentV2Version.incrementPatch();
  }
}

String _extractChangelogSection(String changelog, String version) {
  final lines = changelog.split('\n');
  final buffer = StringBuffer();
  bool recording = false;

  for (final line in lines) {
    if (line.startsWith('## ')) {
      if (recording) break;
      if (line.contains(version)) {
        recording = true;
        continue;
      }
    } else if (recording) {
      buffer.writeln(line);
    }
  }

  return buffer.toString().trim();
}

void _copyDirectory(Directory src, Directory dest) {
  dest.createSync(recursive: true);
  for (final entity in src.listSync(recursive: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('.')) continue; // skip hidden files like .git
    if (entity is File) {
      entity.copySync('${dest.path}/$name');
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory('${dest.path}/$name'));
    }
  }
}

Future<ProcessResult> _runGit(List<String> args) {
  return Process.run('git', args);
}

Future<ProcessResult> _runProcess(String executable, List<String> args,
    {String? workingDirectory}) {
  return Process.run(executable, args, workingDirectory: workingDirectory);
}

class _SemVer implements Comparable<_SemVer> {
  final int major;
  final int minor;
  final int patch;

  _SemVer(this.major, this.minor, this.patch);

  static _SemVer? parse(String input) {
    final clean = input.trim().replaceAll(RegExp(r'^[vV]'), '').split('-')[0];
    final parts = clean.split('.').map((s) => int.tryParse(s)).toList();
    if (parts.length < 3 || parts.any((p) => p == null)) return null;
    return _SemVer(parts[0]!, parts[1]!, parts[2]!);
  }

  _SemVer incrementPatch() => _SemVer(major, minor, patch + 1);
  _SemVer incrementMinor() => _SemVer(major, minor + 1, 0);

  @override
  int compareTo(_SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}
