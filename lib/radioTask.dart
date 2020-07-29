import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

void _backgroundTaskEntrypoint() {
  AudioServiceBackground.run(() => RadioTask());
}

class RadioTask extends BackgroundAudioTask {
  AudioPlayer _player;
  MediaItem _mediaItem = MediaItem(
    id: 'Radio Sana Doctrina',
    album: 'Radio Sana Doctrina',
    artist: 'Asamblea de Lota',
    title: 'Radio Sana Doctrina',
    artUri: 'http://www.radiosanadoctrina.cl/images/r1.png',
  );
  bool playing = false;
  // StreamSubscription _metadataStream;

  final playControl = MediaControl(
    androidIcon: 'drawable/ic_action_play_arrow',
    label: 'Play',
    action: MediaAction.play,
  );
  final pauseControl = MediaControl(
    androidIcon: 'drawable/ic_action_pause',
    label: 'Pause',
    action: MediaAction.pause,
  );
  final stopControl = MediaControl(
    androidIcon: 'drawable/ic_action_stop',
    label: 'Stop',
    action: MediaAction.stop,
  );

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    // Broadcast that we're connecting, and what controls are available.
    AudioServiceBackground.setMediaItem(_mediaItem);
    AudioServiceBackground.setState(
        controls: [stopControl],
        playing: false,
        processingState: AudioProcessingState.connecting,
        systemActions: [MediaAction.stop]);

    _player = AudioPlayer();
    try {
      await _player.setUrl('http://162.210.196.142:8124/stream');

      // Broadcast that we're playing, and what controls are available.
      _player.play();
      AudioServiceBackground.setState(
        controls: [pauseControl, stopControl],
        playing: true,
        processingState: AudioProcessingState.ready,
        systemActions: [MediaAction.pause, MediaAction.stop],
      );
      playing = true;
      AudioServiceBackground.sendCustomEvent({'event': 'play'});
      // metadataStream = player.icyMetadataStream.listen(streamCallback);
    } catch (e) {
      onStop();
    }
  }

  @override
  Future<void> onStop() async {
    AudioServiceBackground.sendCustomEvent({'event': 'stop'});
    // Stop playing audio
    await _player.stop();
    // Shut down this background task
    await super.onStop();
  }

  @override
  void onPlay() => _play();

  @override
  void onPause() => _pause();

  @override
  void onClick(MediaButton button) {
    if (playing) {
      _pause();
    } else {
      _play();
    }
  }

  void _play() async {
    _player.dispose();
    _player = AudioPlayer();
    try {
      await _player.setUrl('http://162.210.196.142:8124/stream');
      _player.play();
      AudioServiceBackground.setState(
        controls: [pauseControl, stopControl],
        playing: true,
        processingState: AudioProcessingState.ready,
        systemActions: [MediaAction.pause, MediaAction.stop],
      );
      playing = true;
      AudioServiceBackground.sendCustomEvent({'event': 'play'});
    } catch (e) {
      onStop();
    }
  }

  void _pause() async {
    _player.stop();
    AudioServiceBackground.setState(
      controls: [playControl, stopControl],
      playing: false,
      processingState: AudioProcessingState.ready,
      systemActions: [MediaAction.play, MediaAction.stop],
    );
    playing = false;
    AudioServiceBackground.sendCustomEvent({'event': 'pause'});
  }

  @override
  Future<dynamic> onCustomAction(action, args) async {
    if (action == 'setMediaItem') {
      AudioServiceBackground.setMediaItem(
        MediaItem(
          id: 'Radio Sana Doctrina',
          album: 'Radio Sana Doctrina',
          artist: args['preacher'] ?? 'Asamblea de Lota',
          title: args['lecture'] ?? 'Radio Sana Doctrina',
          artUri: 'http://www.radiosanadoctrina.cl/images/r1.png',
        ),
      );
    } else if (action == 'init') {
      AudioServiceBackground.sendCustomEvent(
          {'event': playing ? 'play' : 'pause'});
    }
  }

  // Handle a phone call or other interruption
  onAudioFocusLost(AudioInterruption interruption) => _pause();

  // Handle the end of an audio interruption.
  onAudioFocusGained(AudioInterruption interruption) => _pause();
}
