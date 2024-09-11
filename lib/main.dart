import 'dart:convert';
import 'dart:io';

import 'package:cider_remote/player.dart';
import 'package:cider_remote/qrview.dart';
import 'package:cider_remote/webview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import 'package:nsd/nsd.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    ThemeData _darkTheme = ThemeData(
      brightness: Brightness.dark,
      hintColor: Colors.grey[400],
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: Color(0xFFFAFAFA),
        selectionColor: Color(0x55FFFFFF),
        selectionHandleColor: Color(0xFFFAFAFA),
      ),
      scaffoldBackgroundColor: Colors.black,
    );
    return MaterialApp(
      title: 'Cider Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.pink,
      ),
      darkTheme: _darkTheme,
      home: MyHomePage(title: 'Cider'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  var savedMachines = [];
  var savedMachinesDetails = [];
  void _scanMDNS() async {
    final discovery = await startDiscovery('_cider-remote._tcp');
    discovery.addListener(() {
      String ip =
          utf8.decode(base64.decode(discovery.services[0].name!.toString()));
      stopDiscovery(discovery).then((_) => {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => WebViewScreen(
                        ip: ip,
                      )),
            )
          });
    });
  }

  late AnimationController animationController;
  @override
  void dispose() {
    super.dispose();
    animationController.dispose();
  }

  @override
  void initState() {
    super.initState();
    animationController =
        AnimationController(duration: new Duration(seconds: 2), vsync: this);
    animationController.repeat();
    getSavedMachines();
    _scanMDNS();
  }

  void getSavedMachines() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var _savedMachines = prefs.getStringList('machines') ?? [];
    var _savedMachinesDetails = [];
    for (var machine in _savedMachines) {
      String host = "";
      String token = "";
      String friendlyName = "";
      String conn_method = "lan";
      String backend = "";
      String platform = "";
      if (machine.contains("initialData")) {
        var map = jsonDecode(machine);
        host = map["address"];
        token = map["token"];
        friendlyName = "New Remote";
        backend = map["initialData"]["os"];
        conn_method = map["method"] ?? "lan";
        platform = map["initialData"]["platform"];
      } else {
        var map = jsonDecode(utf8.decode(base64.decode(machine)));
         host = map['host'];
         token = map['token'];
         friendlyName = map['friendlyName'];
         conn_method = "lan";
         backend = map['backend'];
         platform = map['platform'];
      }
      bool active = await getonlinestatus(host, token, conn_method);
      _savedMachinesDetails.add({
        'host': host,
        'token': token,
        'friendlyName': friendlyName,
        'backend': backend,
        'method': conn_method,
        'platform': platform,
        'active': active
      });
    }
    setState(() {
      savedMachines = _savedMachines;
      savedMachinesDetails = _savedMachinesDetails;
    });
  }

  Future<bool> getonlinestatus(String host, String token, String conn_method) async {
    final headers = {
      'apptoken': token,
      'Content-Type': 'application/json',
      // Replace this with the appropriate way to get the token in Dart
    };
    String start_url = conn_method == "lan"
        ? 'http://$host:10767'
        : 'https://$host';
    final Uri url = Uri.parse('$start_url/api/v1/playback/active');
    try {
      var response = await http.get(url, headers: headers)
      //     .timeout(
      //   // Duration(seconds: 2),
      //   onTimeout: () {
      //     return http.Response('Error', 408);
      //   },
      // )
      ;
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _showMyDialog(index) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Device not connected'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Cider Remote is unable to connect to this device.'),
                Text(
                    'Please make sure the device is online and the remote is on the same network.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Try anyway'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PlayerScreen(
                        data: savedMachines[index],
                      )),
                );

              }),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),


          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    //_scanMDNS();
    return Scaffold(
      body: SafeArea(
          child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            true
                ? Column(children: [
                    Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("Cider Remote",
                              style: TextStyle(
                                  fontSize: 30.0, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Row(children: [
                      Padding(
                        padding: EdgeInsets.only(left: 16.0),
                        child: Text("Saved devices",
                            style: TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.bold)),
                      ),
                      // refresh button
                      Expanded(
                        child: Padding(
                            padding: EdgeInsets.only(right: 16.0),
                            child: IconButton(
                              icon: Icon(Icons.refresh),
                              alignment: Alignment.centerRight,
                              onPressed: () {
                                getSavedMachines();
                              },
                            )),
                      ),
                    ]),
                    RefreshIndicator(
                        onRefresh: () async {
                          // Handle the refresh action here (e.g., fetch new data)
                          // You can call an API, update data, or perform any necessary tasks
                          // Remember to use asynchronous functions when performing async operations

                          // Example of a delay to simulate an asynchronous operation
                          getSavedMachines();
                        },
                        child: ListView.builder(
                            shrinkWrap: true,
                            scrollDirection: Axis.vertical,
                            itemCount: savedMachinesDetails.length,
                            itemBuilder: (context, index) {
                              var map = savedMachinesDetails[index];
                              String host = map['host'];
                              String token = map['token'];
                              String friendlyName = map['friendlyName'];
                              String backend = map['backend'];
                              String platform = map['platform'];
                              bool active = map['active'];

                              return
                                  // List with queue items and artwork
                                  SwipeActionCell(
                                key: ObjectKey(index),

                                /// this key is necessary
                                trailingActions: <SwipeAction>[
                                  SwipeAction(
                                      title: "Delete",
                                      onTap: (CompletionHandler handler) async {
                                        final SharedPreferences prefs =
                                            await SharedPreferences
                                                .getInstance();
                                        setState(() {
                                          savedMachines.removeAt(index);
                                          List<String> categoriesList =
                                              List<String>.from(
                                                  savedMachines as List);
                                          prefs.setStringList(
                                              'machines', categoriesList);
                                          getSavedMachines();
                                        });
                                      },
                                      color: Colors.red),
                                ],
                                child: Padding(
                                    padding: const EdgeInsets.all(1.0),
                                    child: ListTile(
                                      title: Text(friendlyName),
                                      subtitle: Text(host),
                                      trailing: active
                                          ? Icon(Icons.check_circle,
                                              color: Colors.green)
                                          : Icon(Icons.error,
                                              color: Colors.red),
                                      onTap: () {
                                        active
                                            ? Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        PlayerScreen(
                                                          data: savedMachines[
                                                              index],
                                                        )))
                                            : _showMyDialog(index);
                                      },
                                    )),
                              );
                            })),
                    SizedBox(
                      height: 30,
                    )
                  ])
                : Container(),
            // Text(
            //   'Scanning Cider Remote instance',
            // ),
            // Container(height: 20),
            // CircularProgressIndicator(
            //   valueColor: animationController
            //       .drive(ColorTween(begin: Colors.blueAccent, end: Colors.red)),
            // ),
          ],
        ),
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          var res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => QRViewScreen()),
          );
        },
        label: const Text('Scan'),
        icon: const Icon(CupertinoIcons.qrcode),
        backgroundColor: Colors.pink,
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
