import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color shipColor = Colors.blue;
const Color depthColor = Colors.blue;
const Color scanColor = Colors.blue;
const Color scanDepthColor = Colors.lightBlueAccent;
const Color farColor = Colors.black;
const Color nearColor = Colors.yellowAccent;
const kViewportWidth = 32;
const kViewportHeight = 32;

PlayerOptions fugueOptions = PlayerOptions();

enum FugueOption {
  sound(true),fastCombat(false),autoScoop(false),fancyGraph(false),verbose(false);
  final bool defVal;
  const FugueOption(this.defVal);
}

class PlayerOptions {
  Map<FugueOption,bool> map = {};

  PlayerOptions();

  PlayerOptions.copy(PlayerOptions options) {
    for (FugueOption o in options.map.keys) {
      map[o] = options.map[o] ?? false;
    }
  }

  bool getBool(FugueOption o) { //print("$o -> ${map[o]}");
    return (map.containsKey(o) ? map[o] : false) ?? false;
  }

  static const _keyPfx = 'playerOptions_';
  String optKey(FugueOption o) => "$_keyPfx${o.name}";

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    for (FugueOption o in map.keys) {
      await prefs.setBool(optKey(o), map[o] ?? false);
    }
  }

  Future<void> load() async { //print("Loading");
    final prefs = await SharedPreferences.getInstance();
    for (FugueOption o in FugueOption.values) {
      map[o] = prefs.getBool(optKey(o)) ?? o.defVal;
    }
  }

  static void updateSound(AudioPlayer player) { //print("Updating sound... ${fugueOptions.getBool(FugueOption.sound)}");
    if (fugueOptions.getBool(FugueOption.sound)) {
      if (player.state != PlayerState.playing) player.resume();
    } else {
      player.stop();
    }
  }

  static void editPlayerOptions(BuildContext context, AudioPlayer player) async {
    if (!context.mounted) return; // Check if widget is still in the tree
    final updated = await showPlayerOptionsDialog(context, fugueOptions);
    if (updated != null) {
      await updated.save();
      fugueOptions = updated; //check context.mounted?
      updateSound(player);
    }
  }
}

Future<PlayerOptions?> showPlayerOptionsDialog(
    BuildContext context, PlayerOptions currentOptions) {
  return showDialog<PlayerOptions>(
    context: context,
    builder: (context) {
      return PlayerOptionsDialog(options: fugueOptions);
    },
  );
}

class PlayerOptionsDialog extends StatefulWidget {
  final PlayerOptions options;

  const PlayerOptionsDialog({super.key, required this.options});

  @override
  State<PlayerOptionsDialog> createState() => _PlayerOptionsDialogState();
}

class _PlayerOptionsDialogState extends State<PlayerOptionsDialog> {
  late PlayerOptions _tempOptions;

  @override
  void initState() {
    super.initState();
    _tempOptions = PlayerOptions.copy(widget.options);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Player Options'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_tempOptions.map.keys.length, (i) {
          FugueOption o = _tempOptions.map.keys.elementAt(i);
          return CheckboxListTile(
            title: Text(o.name),
            value: _tempOptions.map[o],
            onChanged: (val) { //print("New value for $o: $val");
              setState(() {
                _tempOptions.map[o] = val ?? false;
              });
            },
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null), // cancel
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_tempOptions),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
