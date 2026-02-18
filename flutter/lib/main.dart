import 'dart:math';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:crawlspace_engine/audio_service.dart';
import 'package:crawlspace_engine/controllers/audio_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/galaxy.dart';
import 'package:crawlspace_flutter/ui/views/ascii_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'options.dart';

/*
TODO: savefiles, autoscroll tweaks, mobile imgs
distance to homeworld influence,
special planets (all - => lower heat, all +++ => higher heat)
find system feature, center system when clicked?
system notes
system shapes
 */

enum ViewType {normal,textOnly,galaxy}

ViewType currentView = ViewType.normal;

final AudioPlayer fuguePlayer = AudioPlayer();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, // Left-side Landscape]);
  runApp(const FugueApp());
}

class FugueApp extends StatelessWidget {
  const FugueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: CustomScrollBehavior(),
      title: 'Space Fugue',
      theme: ThemeData(colorSchemeSeed: Colors.brown), //ThemeData.dark(useMaterial3: true),
      home: const FugueHome(title: 'Space Fugue'),
    );
  }
}

enum ViewState {game,map,options}

class FugueModel extends ChangeNotifier {
  final FugueEngine engine;

  FugueModel(this.engine);

  void notify() => notifyListeners();
}

class FugueHome extends StatefulWidget {
  const FugueHome({super.key, required this.title});
  final String title;

  @override
  State<FugueHome> createState() => _FugueHomeState();
}

class _FugueHomeState extends State<FugueHome> {
  FugueModel? model;
  bool loading = false;
  ViewState view = ViewState.game;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }
  
  @override
  Widget build(BuildContext context) { //print("Building Main Widget");
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage("img/splash_land.png"),fit: BoxFit.fill),
        ),
        child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: (model?.engine == null)
              ? preGameColumn()
              : gameColumn(),
        ),
      ),
    ));
  }

  List<Widget> gameColumn() {
    return [
      Expanded(child: ListenableBuilder(
        listenable: model!,
        builder: (BuildContext context, Widget? child) => Column(children: [
          model!.engine.gameOver
            ? gameOver() //Expanded(child: GalaxyView(fugueModel!,key: ValueKey(fugueModel))),
            : Expanded(child: AsciiView(model!.engine,key: ValueKey(model!.engine))),
        ]),
      )),
    ];
  }

  List<Widget> preGameColumn() {
    return [
      const SizedBox(height: 24),
      newGameButton(),
    ];
  }

  Widget newGameButton() {
    return ElevatedButton(
        onPressed: _initGame,
        child: const Text('New Game')
    );
  }

  Widget optionButton(BuildContext ctx) {
    return ElevatedButton(
      onPressed: () => PlayerOptions.editPlayerOptions(ctx,fuguePlayer),
      child: kIsWeb ? const Text('Options') : const Icon(Icons.settings),
    );
  }

  Widget helpButton({isNewTab = true}) {
    return ElevatedButton(
        onPressed: () => launchUrl(Uri.parse('https://spacefugue.online/help/overview.html'),webOnlyWindowName: isNewTab ? '_blank' : '_self',),
        child: kIsWeb ? const Text('Help') : const Icon(Icons.help)
    );
  }

  void _loadOptions() async {
    setState(() { loading = true; });
    await fugueOptions.load();
    setState(() { loading = false; });
  }

  Widget gameOver() {
    return ColoredBox(color: Colors.black, child:
        Column(children: [
          Text("You were ${model?.engine.result}",
              style: const TextStyle(color: Colors.white)), //const Text("*** SCORE ***"),
          Text("Turns (1 pt each): ${model?.engine.auTick}",
              style: const TextStyle(color: Colors.green)),
          Text("Discovered ${model?.engine.galaxy.discoveredSystems()} systems (2 pts each)",
              style: const TextStyle(color: Colors.blue)),
          Text("Pirates vanquished (3 pts each): ${model?.engine.player.piratesVanquished}",
              style: const TextStyle(color: Colors.grey)),
          Text("Found Star One (500 pts): ${model?.engine.player.starOne}",
              style: const TextStyle(color: Colors.orange)),
          Text("Victory (1000 pts): ${model?.engine.victory}",
              style: const TextStyle(color: Colors.purpleAccent),),
          Text("Score: ${model?.engine.score}"
              ,style: const TextStyle(color: Colors.white)),
          newGameButton(),
      ]));
  }

  void _initGame() { //_updateSound();
    model = FugueModel(FugueEngine(Galaxy("FooBar"), "Zug", seed: Random().nextInt(999)));
    model!.engine.addListener(model!.notify);
    model!.engine.audioController.service = FlutterAudioService(model!.engine.audioController);
    setState(() {
      view = ViewState.game;
    });
  }
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class FlutterAudioService extends AudioService {
  AudioController controller;
  FlutterAudioService(this.controller);

  @override
  void playNewTrack() {
    if (fugueOptions.getBool(FugueOption.sound)) fuguePlayer.play(AssetSource(controller.getTrack()),volume: .33);
  }

  @override
  void setMood(MusicalMood mood) {
    // TODO: implement setMood
  }

}
