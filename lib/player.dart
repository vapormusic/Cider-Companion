import 'dart:convert';
import 'dart:ui';

import 'package:animated_music_indicator/animated_music_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';

import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;

class PlayerScreen extends StatefulWidget {
  String data;
  PlayerScreen({Key? key, required this.data}) : super(key: key);
  @override
  PlayerScreenState createState() => PlayerScreenState();
}

class PlayerScreenState extends State<PlayerScreen> {
  bool _isPlaying = false;
  var _duration = 0.5;
  var _fullduration = 1.0;
  var _volume = 0.25;
  String _songId = "";
  String _artist = "";
  String _title = "No song playing";
  String _album = "";
  String? _artwork = "";
  String storefront = "";
  String bgcolor = "";
  String textcolor1 = "";
  String textcolor2 = "";
  String textcolor3 = "";
  var _queue = [];
  var _lyrics = [];
  String _appmode = "player";
  String host = "";
  String token = "";
  String friendlyName = "";
  String backend = "";
  String platform = "";
  String conn_method = "lan";
  var lyrics_idx = 0;
  var _shuffle_mode = 0;
  var _repeat_mode = 0;
  var _autoplay_mode = false;
  final ItemScrollController itemScrollController = ItemScrollController();
  final ScrollOffsetController scrollOffsetController =
      ScrollOffsetController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetListener scrollOffsetListener =
      ScrollOffsetListener.create();
  late IO.Socket _socket;

  bool isNumeric(String s) {
    if (s == null) {
      return false;
    }
    return double.tryParse(s) != null;
  }

  void _seekTo(double value) {
    var time = value * _fullduration;
    comRPC("POST", "seek", false, token, {"position": (time).toInt()});
  }

  void _playPause() async {
    setState(() {
      _isPlaying = !_isPlaying;
      comRPC("POST", "playpause", false, token);
    });
  }

  void _next() async {
    setState(() {
      comRPC("POST", "next", false, token);
    });
  }

  void _prev() async {
    setState(() {
      comRPC("POST", "previous", false, token);
    });
  }

  void _shuffle() async {
    setState(() {
      _shuffle_mode = _shuffle_mode == 1 ? 0 : 1;
    });
    await comRPC("POST", "toggle-shuffle", false, token);
    _getPlaybackInfo();
  }

  void _repeat() async {
    setState(() {
      _repeat_mode = _repeat_mode == 2 ? 0 : (_repeat_mode + 1);
    });
    await comRPC("POST", "toggle-repeat", false, token);
    _getPlaybackInfo();
  }

  void _getVolume() async {
    final headers = {
      'apptoken': token,
      'Content-Type': 'application/json',
      // Replace this with the appropriate way to get the token in Dart
    };
    String start_url = conn_method == "lan"
        ? 'http://$host:10767'
        : 'https://$host';
    final Uri url = Uri.parse('$start_url/api/v1/playback/volume');
    try {
      final response = await http.get(url, headers: headers);
      var data = json.decode(response.body);
      print(data);
      setState(() {
        if ((data["volume"] is double) || (data["volume"] is int)) {
          if (data["volume"] is int)
            _volume = data["volume"].toDouble();
          else {
            _volume = data["volume"];
          }
        } else {
          print('Error2 $data["volume"] ');
        }
      });
    } catch (error) {}
  }

  void _getQueue() async {
    var data = await comRPC("GET", "queue", false, token);
    setState(() {
      if (data is List<dynamic> && _appmode == "queue") {
        _queue = data;
      }
    });
  }

  void check_playing() async {
    var data = await comRPC("GET", "is-playing", true, token);
    setState(() {
      if (data["is_playing"] is bool) {
        _isPlaying = data["is_playing"] ?? false;
      }
    });
  }

  void check_autoplay() async {
    var data = await comRPC("GET", "autoplay", true, token);
    setState(() {
      if (data["value"] is bool) {
        _autoplay_mode = data["value"] ?? false;
      }
    });
  }

  void _updateQueue(int oldIndex, int newIndex) async {
    var data = await comRPC("POST", "queue/move-to-position", false, token, {
      "startIndex": oldIndex,
      "destinationIndex": newIndex,
      "returnQueue": true
    });
    setState(() {
      if (data is List<dynamic>) {
        _queue = data;
      }
    });
  }

  void _getLyrics(String id) async {
    final headers = {
      'Content-Type': 'application/json',
      'apptoken':
          token // Replace this with the appropriate way to get the token in Dart
    };
    String start_url = conn_method == "lan"
        ? 'http://$host:10767'
        : 'https://$host';
    final Uri url = Uri.parse('$start_url/api/v1/lyrics/$id');
    try {
      final response = await http.get(url, headers: headers);
      setState(() {
        _lyrics = json.decode(response.body);
      });
    } catch (error) {}
  }

  Future<bool> getRegion() async {
    final headers = {
      'Content-Type': 'application/json',
      'apptoken':
          token // Replace this with the appropriate way to get the token in Dart
    };
    String start_url = conn_method == "lan"
        ? 'http://$host:10767'
        : 'https://$host';
    final Uri url = Uri.parse('$start_url/api/v1/amapi/run-v3');
    try {
      final response = await http.post(url,
          headers: headers,
          body: json.encode({
            "path":
                "/v1/me/account?meta=subscription&challenge%5BsubscriptionCapabilities%5D=voice%2Cpremium"
          }));
      setState(() {
        storefront = json.decode(response.body)?["data"]?["meta"]
                ?["subscription"]?["storefront"] ??
            "us";
      });
      return true;
    } catch (error) {
      return false;
    }
  }

  void getColors(String songId) async {
    try {
      print(storefront);
      if (storefront == "") {
        await getRegion();
      }
      final response = await amAPI_rpc(
          "/v1/catalog/$storefront/songs/$songId", false, token);
      setState(() {
        var artwork = response?["data"]?["data"]?[0]?["attributes"]?["artwork"];
        if (artwork != null) {
          setState(() {
            bgcolor = artwork["bgColor"] ?? bgcolor;
            textcolor1 = artwork["textColor1"] ?? textcolor1;
            textcolor2 = artwork["textColor2"] ?? textcolor2;
            textcolor3 = artwork["textColor3"] ?? textcolor3;
            print("$textcolor1 $textcolor2 $bgcolor");
          });
        }
      });
    } catch (error) {}
  }

  static double checkDouble(dynamic value) {
    if (value is String) {
      return double.parse(value);
    } else {
      return value.toDouble();
    }
  }

  void parseDuration(remainingTime, currentPlaybackTime) {
    setState(() {
      // make 0 if both are null
      if (remainingTime == null && currentPlaybackTime == null) {
        remainingTime = 0.0;
        currentPlaybackTime = 0.0;
      } else {
        // make 0 if one of them is null
        remainingTime = remainingTime ?? 0.0;
        currentPlaybackTime = currentPlaybackTime ?? 0.0;
      }

      _fullduration =
          checkDouble(remainingTime) + checkDouble(currentPlaybackTime);
      _duration = (checkDouble(currentPlaybackTime) / _fullduration)
          .clamp(0.0, 1.0)
          .toDouble();
    });
  }

  void _getPlaybackInfo() async {
    var data = await comRPC("GET", "now-playing", false, token);
    setState(() {
      if (data?["info"] != null) {
        data = data["info"];
        parseDuration(data?["remainingTime"], data?["currentPlaybackTime"]);
        _artwork = (data?["artwork"]?["url"] ?? _artwork)
            .toString()
            .replaceAll("{w}x{h}", "400x400");
        _artist = data?["artistName"] ?? _artist;
        _title = data?["name"] ?? _title;
        _album = data?["albumName"] ?? _album;
        _shuffle_mode = data?["shuffleMode"] ?? _shuffle_mode;
        _repeat_mode = data?["repeatMode"] ?? _repeat_mode;
        _songId = data?["playParams"]?["id"] ?? _songId;
      }
    });
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();

    // dispose scroll controllers
  }

  @override
  void initState() {
    super.initState();
    // Enable hybrid composition.
    //if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
    if (widget.data.contains("initialData")) {
      var map = jsonDecode(widget.data);
        host = map["address"];
        token = map["token"];
        friendlyName = "New Remote";
        backend = map["initialData"]["os"];
        platform = map["initialData"]["platform"];
      conn_method = map["method"];
    } else {
      var map = jsonDecode(utf8.decode(base64.decode(widget.data)));
      host = map['host'];
      token = map['token'];
      friendlyName = map['friendlyName'];
      backend = map['backend'];
      platform = map['platform'];
      conn_method = 'lan';
    }
    _getPlaybackInfo();

    void _parseSocket(data, type) {
      // print(data);
      // print(type);
      switch (type) {
        case "playbackStatus.playbackTimeDidChange":
          setState(() {
            if (data != null) {
              _isPlaying = data["isPlaying"];
              parseDuration(
                  data["currentPlaybackDuration"] - data["currentPlaybackTime"],
                  data["currentPlaybackTime"]);
              if (_lyrics.length > 0) {
                // get index from lyrics where timestamp is greater than currentPlaybackTime
                // print(data["currentPlaybackTime"]);
                var index = _lyrics.indexWhere((element) =>
                    element["start"] <= data["currentPlaybackTime"] &&
                    element["end"] >= data["currentPlaybackTime"]);
                if (lyrics_idx != index && index != -1) {
                  lyrics_idx = index;
                  if (index >= 0 && _appmode == "lyrics") {
                    itemScrollController.scrollTo(
                        index: index,
                        duration: Duration(seconds: 1),
                        curve: Curves.easeInOutCubic);
                  }
                }
              }
            }
          });
          break;
        case "playbackStatus.playbackStateDidChange":
          setState(() {
            if (data != null) {
              // print(data);
              _isPlaying = data["state"] == "playing";
              parseDuration(data?["attributes"]?["remainingTime"],
                  data?["attributes"]?["currentPlaybackTime"]);
              _artwork = data["attributes"]["artwork"]["url"]
                  .toString()
                  .replaceAll("{w}x{h}", "400x400");
              _artist = data["attributes"]["artistName"];
              _title = data["attributes"]["name"];
              _album = data["attributes"]["albumName"];
              _songId = data?["attributes"]?["playParams"]?["id"] ?? _songId;
            }
            check_playing();
          });
          break;
        case "playbackStatus.nowPlayingItemDidChange":
          setState(() {
            if (data != null) {
              _lyrics = [];
              _artwork = data?["artwork"]?["url"]
                      ?.toString()
                      .replaceAll("{w}x{h}", "400x400") ??
                  _artwork.toString().replaceAll("{w}x{h}", "400x400");
              _artist = data?["artistName"] ?? _artist;
              _title = data?["name"] ?? _title;
              _album = data?["albumName"] ?? _album;
              parseDuration(
                  data?["remainingTime"], data?["currentPlaybackTime"]);
              _songId = data?["playParams"]?["id"] ?? _songId;
              _getQueue();
              _getLyrics(_songId);
              check_autoplay();
              getColors(_songId);
            }
          });
          break;
      }
    }

    _getQueue();
    check_playing();
    _getVolume();
    try {
      getColors(_songId);
    } catch (_) {}
    String start_url = conn_method == "lan"
        ? 'http://$host:10767'
        : 'https://$host';
    _socket = IO.io(
        start_url,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew() // for Flutter or Dart VM
            .build());
    _socket.onConnect((_) {
      // socket.emit('msg', 'test');
    });
    _socket.on(
        'API:Playback', (data) => _parseSocket(data["data"], data["type"]));
  }

  Future<dynamic> comRPC(
      String method, String request, bool noCheck, String token,
      [Map<String, dynamic>? body]) async {
    final headers = {
      'Content-Type': 'application/json',
      'apptoken':
          token // Replace this with the appropriate way to get the token in Dart
    };
    String start_url = conn_method == "lan"
        ? 'http://$host:10767'
        : 'https://$host';
    final Uri url = Uri.parse('$start_url/api/v1/playback/$request');
    print("$url $token $conn_method");
    try {
      final response = method != "GET"
          ? await http.post(url,
              headers: headers, body: json.encode(body ?? {}))
          : await http.get(url, headers: headers);
      if (noCheck) {
        json.decode(response.body);
      }
      return json.decode(response.body);
    } catch (error) {
      if (!noCheck) {
        print('Request error: $error');
      }
    }
  }

  Future<dynamic> amAPI_rpc(String request, bool noCheck, String token) async {
    final headers = {
      'Content-Type': 'application/json',
      'apptoken':
          token // Replace this with the appropriate way to get the token in Dart
    };
    String start_url = conn_method == "lan"
        ? 'http://$host:10767'
        : 'https://$host';
    final Uri url = Uri.parse('$start_url/api/v1/amapi/run-v3');
    try {
      final response = await http.post(url,
          headers: headers, body: json.encode({"path": request}));
      if (noCheck) {
        json.decode(response.body);
      }
      return json.decode(response.body);
    } catch (error) {
      if (!noCheck) {
        print('Request error: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // convert the b64-encoded data to a dict
    Future<bool> _willPopCallback() async {
      // await showDialog or Show add banners or whatever
      // then
      setState(() {
        if (_appmode != "player") {
          _appmode = "player";
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
      return Future.value(false);
    }

    return WillPopScope(
        onWillPop: () => _willPopCallback(),
        child: Scaffold(
            body: SafeArea(
                child: Container(
                    // decoration: BoxDecoration(
                    //   image: DecorationImage(
                    //     image: NetworkImage(_artwork),
                    //     fit: BoxFit.cover,
                    //   ),
                    //   boxShadow: <BoxShadow>[
                    //     new BoxShadow(
                    //       color: Colors.black26,
                    //       blurRadius: 5.0,
                    //       offset: new Offset(30.0, 30.0),
                    //     )
                    //   ],
                    // ),
                    child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
                        child: switch (_appmode) {
                          "player" => Stack(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                        child: IconButton(
                                      style: IconButton.styleFrom(
                                        splashFactory: NoSplash.splashFactory,
                                      ),
                                      icon: Icon(Icons.arrow_back),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      alignment: Alignment.centerLeft,
                                    )),
                                    // Expanded(
                                    //     child: IconButton(
                                    //   style: IconButton.styleFrom(
                                    //     splashFactory: NoSplash.splashFactory,
                                    //   ),
                                    //   icon: Icon(Icons.search),
                                    //   alignment: Alignment.centerRight,
                                    //   onPressed: () {
                                    //     //
                                    //   },
                                    // ))
                                  ],
                                ),
                                Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      // Add back button

                                      // Album Art
                                      (_artwork == null)
                                          ? ConstrainedBox(
                                              // rounded corners

                                              constraints:
                                                  BoxConstraints.expand(
                                                      width: 200, height: 200))
                                          : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                              child: Container(
                                                  width: 200,
                                                  height: 200,
                                                  child: CachedNetworkImage(
                                                    imageUrl: _artwork!,
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Container(),
                                                  ))),
                                      // Track Info (Artist, Title, Album)
                                      Container(
                                        padding: EdgeInsets.only(
                                            left: 20.0,
                                            right: 20,
                                            top: 10,
                                            bottom: 10),
                                        child: Column(
                                          children: <Widget>[
                                            Text(
                                              _title,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                            Text(
                                              _artist,
                                              style: TextStyle(
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                            Text(
                                              _album,
                                              style: TextStyle(fontSize: 16),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Progress Bar
                                      SliderTheme(
                                        child: Slider(
                                          value: _duration,
                                          onChanged: _seekTo,
                                          min: 0.0,
                                          max: 1.0,
                                        ),
                                        data: SliderTheme.of(context).copyWith(
                                            trackHeight: 20,
                                            thumbColor: Colors.transparent,
                                            thumbShape: RoundSliderThumbShape(
                                                enabledThumbRadius: 0.0)),
                                      ),
                                      // Time Indicator
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Padding(
                                            padding: EdgeInsets.only(left: 20),
                                            child: Text(
                                              // format as mm:ss
                                              Duration(
                                                      seconds: (_duration *
                                                              _fullduration)
                                                          .toInt())
                                                  .toString()
                                                  .split('.')
                                                  .first
                                                  .substring(2),
                                              style: TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(right: 20),
                                            child: Text(
                                              Duration(
                                                      seconds: (_fullduration)
                                                          .toInt())
                                                  .toString()
                                                  .split('.')
                                                  .first
                                                  .substring(2),
                                              style: TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Control Buttons
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          IconButton(
                                            icon: Icon(Icons.shuffle),
                                            onPressed: _shuffle,
                                            iconSize: 20,
                                            color: _shuffle_mode == 1
                                                ? Colors.blue
                                                : Theme.of(context)
                                                    .disabledColor,
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.skip_previous),
                                            onPressed: _prev,
                                            iconSize: 50,
                                          ),
                                          IconButton(
                                            icon: Icon(_isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow),
                                            onPressed: _playPause,
                                            iconSize: 50,
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.skip_next),
                                            onPressed: _next,
                                            iconSize: 50,
                                          ),
                                          IconButton(
                                            icon: _repeat_mode == 1
                                                ? Icon(Icons.repeat_one)
                                                : Icon(Icons.repeat),
                                            onPressed: _repeat,
                                            iconSize: 20,
                                            color: _repeat_mode > 0
                                                ? Colors.blue
                                                : Theme.of(context)
                                                    .disabledColor,
                                          ),
                                        ],
                                      ),
                                      // Volume Slider
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Add volume icon
                                            SizedBox(width: 25),
                                            Icon(_volume > 0
                                                ? Icons.volume_up
                                                : Icons.volume_mute),
                                            Expanded(
                                                child: Slider(
                                              value: _volume,
                                              onChanged: (value) {
                                                setState(() {
                                                  _volume = value;
                                                });
                                                comRPC("POST", "volume", false,
                                                    token, {"volume": value});
                                              },
                                              min: 0.0,
                                              max: 1.0,
                                            )),
                                          ]),
                                      SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Lyrics and Queue
                                          SizedBox(width: 30),
                                          Expanded(
                                              child: Container(
                                                  child: ElevatedButton(
                                            onPressed: () {
                                              _getLyrics(this._songId);
                                              setState(() {
                                                _appmode = "lyrics";
                                              });
                                            },
                                            child: Container(child:
                                              // icon and text
                                              Row(
                                                children: [
                                                  Icon(Icons.library_books),
                                                  SizedBox(width: 10),
                                                  Text('Lyrics'),
                                                ],
                                                  mainAxisAlignment: MainAxisAlignment.center
                                              ),

                                            )
                                                    ,
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12), // <-- Radius
                                              ),
                                            ),
                                          ))),
                                          SizedBox(width: 30),
                                          Expanded(
                                              child: Container(
                                                  child: ElevatedButton(
                                            onPressed: () {
                                              _getQueue();
                                              check_autoplay();
                                              setState(() {
                                                _appmode = "queue";
                                              });
                                            },
                                            child: Container(child:
                                              // icon and text
                                              Row(
                                                children: [
                                                  Icon(Icons.queue_music),
                                                  SizedBox(width: 10),
                                                  Text('Queue'),
                                                ],
                                                  mainAxisAlignment: MainAxisAlignment.center
                                              ),

                                            )
                                                    ,
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12), // <-- Radius
                                              ),
                                            ),
                                          ))),
                                          SizedBox(width: 30),
                                        ],
                                      )
                                    ])
                              ],
                            ),
                          "queue" => Container(
                                // List contains queue items
                                child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Add back button
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.arrow_back),
                                      onPressed: () {
                                        _getPlaybackInfo();
                                        setState(() {
                                          _appmode = "player";
                                        });
                                      },
                                    ),
                                    Text(
                                      "Up Next",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22.0,
                                      ),
                                    ),
                                    Expanded(
                                        child: IconButton(
                                      icon: Icon(CupertinoIcons.loop),
                                      color: _autoplay_mode
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context).indicatorColor,
                                      onPressed: () {
                                        _getPlaybackInfo();
                                        setState(() {
                                          _autoplay_mode = !_autoplay_mode;
                                          comRPC("POST", "toggle-autoplay",
                                              false, token);

                                          _getQueue();
                                        });
                                      },
                                      alignment: Alignment.centerRight,
                                    )),
                                    IconButton(
                                      icon: Icon(Icons.clear_all),
                                      onPressed: () {
                                        _getPlaybackInfo();
                                        setState(() {
                                          comRPC("POST", "queue/clear-queue",
                                              false, token);

                                          _queue.clear();
                                        });
                                      },
                                      alignment: Alignment.centerRight,
                                    ),
                                  ],
                                ),
                                Expanded(
                                    child: ReorderableListView.builder(
                                  scrollDirection: Axis.vertical,
                                  itemCount: _queue.length,
                                  itemBuilder: (context, index) {
                                    return
                                        // List with queue items and artwork
                                        SwipeActionCell(
                                      key: Key(_queue[index]["id"]),

                                      /// this key is necessary
                                      trailingActions: <SwipeAction>[
                                        SwipeAction(
                                            title: "Delete",
                                            onTap: (CompletionHandler
                                                handler) async {
                                              comRPC(
                                                  "POST",
                                                  "queue/remove-by-index",
                                                  false,
                                                  token,
                                                  {"index": index});
                                              setState(() {
                                                _queue.removeAt(index);
                                              });
                                            },
                                            color: Colors.red),
                                      ],
                                      child: Padding(
                                        padding: const EdgeInsets.all(1.0),
                                        child: ListTile(
                                          key: Key(_queue[index]["id"]),
                                          title: Text(_queue[index]
                                              ["attributes"]["name"]),
                                          subtitle: Text(_queue[index]
                                              ["attributes"]["artistName"]),
                                          leading: (_queue[index]["id"] ==
                                                  _songId)
                                              ? ConstrainedBox(
                                                  child: AnimatedMusicIndicator(
                                                      barStyle: BarStyle.solid,
                                                      roundBars: false,
                                                      size: 0.50,
                                                      numberOfBars: 4),
                                                  constraints:
                                                      BoxConstraints.expand(
                                                          width: 50,
                                                          height: 50))
                                              : Image.network(
                                                  _queue[index]["attributes"]
                                                          ["artwork"]["url"]
                                                      .toString()
                                                      .replaceAll(
                                                          "{w}x{h}", "400x400"),
                                                  width: 50,
                                                  height: 50,
                                                ),
                                          trailing:
                                              ReorderableDragStartListener(
                                            index: index,
                                            child:
                                                const Icon(Icons.drag_handle),
                                          ),
                                          onTap: () {
                                            // comRPC("POST", "/play-itemr", false, token,
                                            //     {"id": _queue[index]["id"], "type": _queue[index]["type"]});
                                            comRPC(
                                                "POST",
                                                "queue/change-to-index",
                                                false,
                                                token,
                                                {"index": index});
                                            // print(index);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  onReorder: (oldIndex, newIndex) {
                                    if (newIndex > oldIndex) {
                                      newIndex -= 1;
                                    }
                                    var item = _queue.removeAt(oldIndex);
                                    _queue.insert(newIndex, item);
                                    // comRPC("POST", "queue/move", false, token,
                                    //     {"from": oldIndex, "to": newIndex});
                                    _updateQueue(oldIndex, newIndex);
                                  },
                                ))
                              ],
                            )),
                          "lyrics" => Container(
                                child: Container(
                                    // List contains queue items
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                  // Add back button
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.arrow_back),
                                        onPressed: () {
                                          _getPlaybackInfo();
                                          setState(() {
                                            _appmode = "player";
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  // Add current song title, album and artwork
                                  ListTile(
                                    title: Text(_title),
                                    subtitle: Text(_artist),
                                    leading: (_artwork == null)
                                        ? ConstrainedBox(
                                            constraints: BoxConstraints.expand(
                                                width: 50, height: 50))
                                        : CachedNetworkImage(
                                            imageUrl: _artwork!,
                                            width: 50,
                                            height: 50,
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(),
                                          ),
                                    onTap: () {
                                      // comRPC("POST", "play", false, token,
                                      //     {"id": _queue[index]["id"]});
                                      setState(() {
                                        _appmode = "player";
                                      });
                                    },
                                  ),
                                  _lyrics.length == 0
                                      ? Text("No lyrics found")
                                      : Expanded(
                                          child:
                                              ScrollablePositionedList.builder(
                                          itemCount: _lyrics.length,
                                          itemBuilder: (context, index) {
                                            return Padding(
                                                padding:
                                                    const EdgeInsets.all(20.0),
                                                child: InkWell(
                                                  onTap: () {
                                                    _seekTo(_lyrics[index]
                                                            ["start"] /
                                                        _fullduration);
                                                  },
                                                  child: Text(
                                                    (_lyrics[index]["empty"] ==
                                                            true)
                                                        ? "..."
                                                        : _lyrics[index]
                                                            ["text"],
                                                    style: TextStyle(
                                                      color: _lyrics[index]
                                                                  ["start"] <=
                                                              (_duration *
                                                                  _fullduration)
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                          : Theme.of(context)
                                                              .indicatorColor,
                                                      fontSize: (_lyrics[index]
                                                                  ["empty"] ==
                                                              true)
                                                          ? 60
                                                          : (_lyrics[index][
                                                                      "start"] <=
                                                                  (_duration *
                                                                      _fullduration)
                                                              ? 26
                                                              : 24),
                                                      fontWeight: (_lyrics[
                                                                      index]
                                                                  ["start"] <=
                                                              (_duration *
                                                                  _fullduration)
                                                          ? FontWeight.bold
                                                          : FontWeight.w500),
                                                    ),
                                                  ),
                                                ));
                                          },
                                          itemScrollController:
                                              itemScrollController,
                                          scrollOffsetController:
                                              scrollOffsetController,
                                          itemPositionsListener:
                                              itemPositionsListener,
                                          scrollOffsetListener:
                                              scrollOffsetListener,
                                        )
                                          // Lyrics / ScrolledPositionedList

                                          )
                                ]))),
                          _ => Text("Unknown mode"),
                        })))));
  }
}
