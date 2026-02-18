import 'dart:math';
import '../audio_service.dart';

class AudioController {
  final Random rnd;
  AudioService service;
  MusicalMood mood = MusicalMood.intro;

  AudioController(this.service, this.rnd);

  void newTrack({MusicalMood? newMood}) {
    if (newMood != null) mood = newMood;
    service.setMood(mood);
    service.playNewTrack();
  }

  String getTrack() => switch (mood) {
    MusicalMood.danger => "audio/tracks/danger${rnd.nextInt(4)+1}.mp3",
    MusicalMood.planet => "audio/tracks/planet${rnd.nextInt(4)+1}.mp3",
    MusicalMood.space  => "audio/tracks/wandering${rnd.nextInt(4)+1}.mp3",
    MusicalMood.intro  => "audio/tracks/intro${rnd.nextInt(2)+1}.mp3",
  };
}
