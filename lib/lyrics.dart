import 'dart:convert';

import 'package:cider_remote/player.dart';
import 'package:flutter/material.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class LyricsScreen extends StatefulWidget {
  String data;
  LyricsScreen({Key? key, required this.data}) : super(key: key);
  @override
  LyricsScreenState createState() => LyricsScreenState();
}

class LyricsScreenState extends State<LyricsScreen> {
  bool _isPlaying = false;
  var _duration = 0.5;
  var _fullduration = 1.0;
  var _volume = 0.5;
  String _songId = "";
  String _artist = "";
  String _title = "";
  String _album = "";
  String _artwork = "";

  String host = "";
  String token = "";
  String friendlyName = "";
  String backend = "";
  String platform = "";
  var _shuffle_mode = 0;
  var _repeat_mode = 0;
  var _lyrics = [];
  final ItemScrollController itemScrollController = ItemScrollController();
  final ScrollOffsetController scrollOffsetController =
      ScrollOffsetController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetListener scrollOffsetListener =
      ScrollOffsetListener.create();
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
    var data = await comRPC("GET", "volume", false, token);
    setState(() {
      _volume = data["volume"];
    });
  }

  void _getlyrics(String id) async {
    final headers = {
      'Content-Type': 'application/json',
      'apptoken':
          token // Replace this with the appropriate way to get the token in Dart
    };
    print(id);
    final Uri url = Uri.parse('http://$host:10767/api/v1/lyrics/$id');
    try {
      final response = await http.get(url, headers: headers);
      print(json.decode(response.body));
      setState(() {
        _lyrics = json.decode(response.body);
      });
    } catch (error) {
      print('Request error: $error');
    }
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
        _songId = data?["playParams"]["id"] ?? _songId;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    var map = jsonDecode(utf8.decode(base64.decode(widget.data)));
    host = map['host'];
    token = map['token'];
    friendlyName = map['friendlyName'];
    backend = map['backend'];
    platform = map['platform'];

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
            }
          });
          break;
        case "playbackStatus.playbackStateDidChange":
          setState(() {
            if (data != null) {
              _isPlaying = data["state"] == "playing";
              parseDuration(data?["attributes"]?["remainingTime"],
                  data?["attributes"]?["currentPlaybackTime"]);
              _artwork = data["attributes"]["artwork"]["url"]
                  .toString()
                  .replaceAll("{w}x{h}", "400x400");
              _artist = data["attributes"]["artistName"];
              _title = data["attributes"]["name"];
              _album = data["attributes"]["albumName"];
              _songId = data?["attributes"]?["playParams"]["id"] ?? _songId;
            }
          });
          break;
        case "playbackStatus.nowPlayingItemDidChange":
          setState(() {
            if (data != null) {
              _artwork = data?["artwork"]?["url"]
                      ?.toString()
                      .replaceAll("{w}x{h}", "400x400") ??
                  _artwork.toString().replaceAll("{w}x{h}", "400x400");
              _artist = data?["artistName"] ?? _artist;
              _title = data?["name"] ?? _title;
              _album = data?["albumName"] ?? _album;
              parseDuration(
                  data?["remainingTime"], data?["currentPlaybackTime"]);
              _songId = data?["playParams"]["id"] ?? _songId;
            }
          });
          break;
      }
    }

    IO.Socket socket = IO.io(
        'http://${host}:10767',
        IO.OptionBuilder()
            .setTransports(['websocket']) // for Flutter or Dart VM
            .build());
    socket.onConnect((_) {
      // print('connect');
      // socket.emit('msg', 'test');
    });
    socket.on(
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

    final Uri url =
        Uri.parse('http://$host:10767/api/v1/playback/$request');
    try {
      final response = method != "GET"
          ? await http.post(url,
              headers: headers, body: json.encode(body ?? {}))
          : await http.get(url, headers: headers);
      print(json.decode(response.body));
      return json.decode(response.body);
    } catch (error) {
      if (!noCheck) {
        print('Request error: $error');
      }
    }
    _getlyrics(_songId);
  }

  @override
  Widget build(BuildContext context) {
    // convert the b64-encoded data to a dict

    return Scaffold(
        body: SafeArea(
            child: Column(children: [
      // add back button
      Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PlayerScreen(data: widget.data)));
            },
          ),
        ],
      ),
      ScrollablePositionedList.builder(
        itemCount: _lyrics.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _lyrics[index].text,
              style: TextStyle(
                color:
                    // _lyrics![index].timeStamp.isAfter(dt)
                    //     ? Colors.white38
                    //     :
                    Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
        itemScrollController: itemScrollController,
        scrollOffsetController: scrollOffsetController,
        itemPositionsListener: itemPositionsListener,
        scrollOffsetListener: scrollOffsetListener,
      )
    ])));
  }
}
