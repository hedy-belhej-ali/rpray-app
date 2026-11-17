import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays bundled MP3 previews in-app. Notification sounds are handled
/// separately by Android channels / the native adhan service.
class AudioPreviewService {
  AudioPreviewService() {
    _player.setReleaseMode(ReleaseMode.stop);
    _completion = _player.onPlayerComplete.listen((_) {
      _playing = false;
      _notify();
    });
  }

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completion;
  bool _playing = false;
  String? _currentAsset;
  final ValueNotifier<String?> playingAsset = ValueNotifier<String?>(null);

  bool get isPlaying => _playing;

  Future<void> playAsset(String asset) async {
    try {
      await _player.stop();
      _currentAsset = asset;
      _playing = true;
      playingAsset.value = asset;
      await _player.play(AssetSource(asset));
    } catch (_) {
      _playing = false;
      playingAsset.value = null;
    }
  }

  Future<void> stop() async {
    _playing = false;
    _currentAsset = null;
    playingAsset.value = null;
    try {
      await _player.stop();
    } catch (_) {
      // Ignore stop failures.
    }
  }

  void _notify() {
    if (!_playing || _currentAsset == null) return;
    _playing = false;
    _currentAsset = null;
    playingAsset.value = null;
  }

  Future<void> dispose() async {
    await _completion?.cancel();
    await _player.dispose();
    playingAsset.dispose();
  }
}
