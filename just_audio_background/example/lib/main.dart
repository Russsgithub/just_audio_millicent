import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_example/common.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:marqueer/marqueer.dart';
import 'package:transparent_image/transparent_image.dart';

import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Top bar
    systemNavigationBarColor: Colors.transparent, // Bottom bar
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
    statusBarIconBrightness:
        Brightness.dark, // or light depending on background
    systemNavigationBarIconBrightness: Brightness.dark, // same here
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  static int _nextMediaId = 0;
  late AudioPlayer _player;

  final _playlist = HlsAudioSource(
    Uri.parse("https://d1i4sik9cp7a6c.cloudfront.net/hls/live.m3u8"),
    tag: MediaItem(
      id: '${_nextMediaId++}',
      album: "",
      title: "millicent",
      artUri: Uri.parse(
          "https://millicent.org/static/imgs/millicent_sized_portrait_flutter.png"),
    ),
  );

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    try {
      await _player.setAudioSource(_playlist);
      _player.play();
    } on PlayerException catch (e) {
      print("Initialization Error code: ${e.code}");
      print("Initialization Error message: ${e.message}");
    } on PlayerInterruptedException catch (e) {
      /// do stuff
      print("Initialization Connection aborted: ${e.message}");
    } on PlatformException catch (e) {
      _player.stop();
      print("Platform Error $e");
    } catch (e, stackTrace) {
      // Catch load errors: 404, invalid url ...
      print("Error loading playlist: $e");
      print(stackTrace);
    }

    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace st) {
      if (e is PlatformException) {
        _player.stop();
        print('Error code: ${e.code}');
        print('Error message: ${e.message}');
        print('AudioSource index: ${e.details?["index"]}');
      } else {
        _player.stop();
        print('An error occurred: $e');
      }
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.ready) {
        setState(() {});
      } else if (state.processingState == ProcessingState.completed) {
        print("Skipping to edge");
        Future.delayed(const Duration(seconds: 1), () {
          _player.seek(Duration.zero, index: _player.effectiveIndices.first);
          _player.play();
        });
      }
    });
  }

  @override
  void dispose() {
    // Release decoders and buffers back to the operating system making them
    // available for other apps to use.
    _player.dispose();
    super.dispose();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle lifecycle changes if needed
    print("Lifecycle change. $state");
    if (state == AppLifecycleState.paused) {
      print("Stopping");
      // Release the player's resources when not in use. We use "stop" so that
      // if the app resumes later, it will still remember what position to
      // resume from.
      _player.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness:
              Brightness.dark, // or .dark depending on background
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: SafeArea(
                top: false,
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.only(top: 55.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black54, width: 0.5),
                    color: const Color(0xff5f6459), //0xffe3dfb2
                    borderRadius:
                        BorderRadius.circular(6.0), // Rounded inner edges
                  ),
                  child: Stack(
                    alignment: AlignmentDirectional.bottomCenter,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            StreamBuilder<IcyMetadata?>(
                              stream: _player.icyMetadataStream,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const SizedBox();
                                } else if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                } else if (!snapshot.hasData) {
                                  return const SizedBox();
                                } else {
                                  final metadata = snapshot.data;
                                  final jsonString =
                                      metadata?.info?.title ?? '';

                                  if (jsonString.isNotEmpty) {
                                    print(jsonString);
                                    try {
                                      List<dynamic> jsonDataList =
                                          jsonDecode(jsonString);

                                      Map<String, dynamic> jsonData =
                                          jsonDataList[1];

                                      var musicTitle =
                                          jsonData['music']['title'];
                                      var musicArtist =
                                          jsonData['music']['artist'];
                                      var musicUrl =
                                          jsonData['music']['source_url'];
                                      var musicImage =
                                          (jsonData['music']['image'] != null)
                                              ? jsonData['music']['image']
                                              : "";
                                      var fieldTitle =
                                          jsonData['field']['title'];
                                      var fieldArtist =
                                          jsonData['field']['artist'];
                                      var fieldUrl =
                                          jsonData['field']['source_url'];
                                      var vocalTitle =
                                          jsonData['vocal']['title'];
                                      var vocalArtist =
                                          jsonData['vocal']['artist'];
                                      var vocalUrl =
                                          jsonData['vocal']['source_url'];

                                      musicTitle =
                                          musicTitle.contains("Error")
                                              ? "silence"
                                              : musicTitle;
                                      musicArtist =
                                          musicTitle.contains("Error")
                                              ? "silence"
                                              : musicArtist;

                                      return Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            if (vocalTitle == "silence")
                                              const Spacer(),
                                            if (vocalTitle != "silence")
                                              MetadataContainer(
                                                  stream: "vocal",
                                                  title: '$vocalTitle',
                                                  artist: '$vocalArtist',
                                                  image: '',
                                                  link: '$vocalUrl'),
                                            if (fieldTitle == "silence")
                                              const Spacer(),
                                            if (fieldTitle != "silence")
                                              MetadataContainer(
                                                  stream: "field",
                                                  title: '$fieldTitle',
                                                  artist: '$fieldArtist',
                                                  image: '',
                                                  link: '$fieldUrl'),
                                            if (musicTitle == "silence")
                                              const Spacer(flex: 6),
                                            if (musicTitle != "silence")
                                              MetadataContainer(
                                                  stream: "music",
                                                  title: '$musicTitle',
                                                  artist: '$musicArtist',
                                                  image: '$musicImage',
                                                  link: '$musicUrl'),
                                          ],
                                        ),
                                      );
                                    } catch (e) {
                                      print("Error decoding json: $e");
                                      return const Expanded(child: Column());
                                    }
                                  } else {
                                    return const Expanded(child: Column());
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Container(
                                color: Colors.transparent,
                                height: 70,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      top: 12.0, left: 12.0, right: 12.0),
                                  child: Container(
                                      decoration: const BoxDecoration(
                                          image: DecorationImage(
                                    isAntiAlias: true,
                                    opacity: 0.7,
                                    image: AssetImage(
                                        "assets/images/millicent_word.png"),
                                  ))),
                                ),
                              ),
                            ),
                            Center(
                              child: Container(
                                color: const Color(0x00131313),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 20, left: 12.0, right: 12.0),
                                  child: Container(
                                      height:
                                          16, // Margin to create space for the border
                                      decoration: const BoxDecoration(
                                          image: DecorationImage(
                                        isAntiAlias: true,
                                        opacity: 1.0,
                                        image: AssetImage(
                                            "assets/images/rbb.png"),
                                      ))),
                                ),
                              ),
                            ),
                            // Display play/pause button and volume/speed sliders.
                            ControlButtons(_player),
                            const SizedBox(height: 18),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
            ),
        ),
        ),
    );
  }
}

class MetadataContainer extends StatelessWidget {
  final String stream;
  final String title;
  final String artist;
  final String image;
  final String link;

  const MetadataContainer({
    required this.stream,
    required this.title,
    required this.artist,
    required this.image,
    required this.link,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Flexible(
      fit: FlexFit.loose,
      flex: (image == '') ? 1 : 5,
      child: GestureDetector(
        onTap: () async {
          var urlStr = link.trim();

          if (urlStr.contains("https://www.youtube.com")) {
            urlStr = "$urlStr&mute=1";
          }
          if (urlStr == '') {
            urlStr = "https://duckduckgo.com/?q=$title+$artist";
          }

          var url = Uri.parse(urlStr);

          if (await canLaunchUrl(url)) {
            bool launched = await launchUrl(url, mode: LaunchMode.inAppWebView);

            if (!launched) {
              print("Using external app");
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          } else {
            throw 'Could not launch $url';
          }
        },
        child: Column(
          children: [
            if (image != "")
              Flexible(
                fit: FlexFit.loose,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5.0),
                    child: FadeInImage.memoryNetwork(
                      key: Key(image),
                      placeholder: kTransparentImage,
                      image: image,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.width,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 400),
                      fadeOutDuration: const Duration(milliseconds: 800),
                      imageErrorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error);
                      },
                    ),
                  ),
                ),
              ),
            Container(
              width: MediaQuery.of(context).size.width,
              color: Colors.transparent,
              child: Padding(
                  padding:
                      const EdgeInsets.only(top: 5.0, left: 15.0, right: 15.0),
                  child: TextContainer(
                    stream: stream,
                    title: title,
                    artist: artist,
                    image: image,
                    link: link,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class TextContainer extends StatelessWidget {
  final String stream;
  final String title;
  final String artist;
  final String image;
  final String link;

  const TextContainer({
    required this.stream,
    required this.title,
    required this.artist,
    required this.image,
    required this.link,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = MarqueerController();
    if (image != '') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.trim(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w400,
                color: const Color(0x90C3C3C3)),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (artist != "")
            Text(
              artist.trim(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: const Color(0x90838383)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
        ],
      );
    } else {
      return Center(
        child: SizedBox(
          height: 50,
          width: MediaQuery.of(context).size.width,
          child: Marqueer(
              pps: stream == "vocal" ? 8 : 15,

              /// optional
              controller: controller,

              /// optional
              direction: MarqueerDirection.rtl,

              /// optional
              interaction: false,
              restartAfterInteractionDuration: const Duration(seconds: 6),

              /// optional
              restartAfterInteraction: false,

              /// optional
              onChangeItemInViewPort: (index) {
                print('item index: $index');
              },
              onInteraction: () {
                print('on interaction callback');
              },
              onStarted: () {
                print('on started callback');
              },
              onStopped: () {
                print('on stopped callback');
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                child: Text(
                  // '${title.trim()} recorded by ${artist.isNotEmpty ? artist.trim() : "Unknown"}',
                  title.trim(),
                  style: const TextStyle(
                      color: Color(0x90E3E3E3),
                      fontWeight: FontWeight.w200,
                      fontSize: 30),
                ),
              )),
        ),
      );
    }
  }
}

class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          color: const Color(0xff131313),
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),
        const Spacer(),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: const SpinKitDoubleBounce(
                  color: Color(0xff131313),
                  duration: Duration(seconds: 4),
                ),
              );
            } else if (playing != true) {
              return IconButton(
                  color: const Color(0xff232323),
                  icon: const Icon(Icons.play_arrow),
                  iconSize: 64.0,
                  onPressed: () {
                    player.seek(null);
                    player.play();
                  });
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                color: const Color(0xff131313),
                icon: const Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                color: const Color(0xff131313),
                icon: const Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero,
                    index: player.effectiveIndices.first),
              );
            }
          },
        ),
        const Spacer(),
        IconButton(
          color: const Color(0xff131313),
          icon: const Icon(Icons.info_outline),
          onPressed: () {
            Navigator.of(context).push(_createRoute());
          },
        ),
      ],
    );
  }
}

Route _createRoute() {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => const Manifesto(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
    opaque: false, // Set this to false
    barrierColor: Colors.transparent,
  );
}

class Manifesto extends StatelessWidget {
  const Manifesto({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          height: double.infinity,
          color: Colors.black,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.0),
              color: const Color(0xff131313),
              borderRadius: BorderRadius.circular(12.0), // Rounded inner edges
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 10.0, bottom: 0.0),
                          child: Image.asset(
                            "assets/images/millicent_manifesto_header.png",
                            height: 150,
                            width: 150,
                          ),
                        ),
                        const Text(
                            style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                                height: 2,
                                fontSize: 28),
                            textAlign: TextAlign.center,
                            "The 'millicent' Manifesto"),
                        const Text(
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 15),
                            textAlign: TextAlign.justify,
                            "1) To view the existence of the internet as a positive opportunity towards the uniting of humanity."),
                        const Spacer(),
                        const Text(
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 15),
                            textAlign: TextAlign.justify,
                            "2) To work towards the unity of humanity through the promotion of music, storytelling, poetry and sound design, from all languages and cultures."),
                        const Spacer(),
                        const Text(
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 15),
                            textAlign: TextAlign.justify,
                            "3) To promote an existence beyond the barriers constructed through contemporary political notions of national borders, through the medium of radio."),
                        const Spacer(),
                        const Text(
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 15),
                            textAlign: TextAlign.justify,
                            "4) To promote a sense of all humanity being equal. Regardless of age, race, gender, ethnicity or geographical location."),
                        const Spacer(),
                        const Text(
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 15),
                            textAlign: TextAlign.justify,
                            "5) To respect and promote the further understanding of the importance of the co-existence of differing belief systems."),
                        const Spacer(),
                        const Text(
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 15),
                            textAlign: TextAlign.justify,
                            "6) To broadcast, the very best audio quality content, celebrating the rich diversity of humanity’s cultural achievements, and to make this content available to all."),
                        const Spacer(),
                        const Text(
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 15),
                            textAlign: TextAlign.justify,
                            "7) To consider cultural diversity a positive asset."),
                        const Spacer(),
                        const Text(
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 15),
                            textAlign: TextAlign.justify,
                            "8) To educate, entertain and inform."),
                        const Spacer(),
                        const Text(
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 15),
                            textAlign: TextAlign.justify,
                            "9) To celebrate the contribution of the gift of creativity to humanity’s well being."),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF201F16),
                            foregroundColor: Colors.white54,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w100),
                              'back'),
                        ),
                        const Spacer(flex: 2)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
