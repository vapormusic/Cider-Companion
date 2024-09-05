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
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

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
  }

  void getSavedMachines() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedMachines = prefs.getStringList('machines') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    //_scanMDNS();
    getSavedMachines();
    return Scaffold(
      body: SafeArea(
          child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            savedMachines.length > 0
                ? Column(children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("Saved devices",
                            textAlign: TextAlign.left,
                            style: TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    ListView.builder(
                        shrinkWrap: true,
                        scrollDirection: Axis.vertical,
                        itemCount: savedMachines.length,
                        itemBuilder: (context, index) {
                          var map = jsonDecode(
                              utf8.decode(base64.decode(savedMachines[index])));
                          String host = map['host'];
                          String token = map['token'];
                          String friendlyName = map['friendlyName'];
                          String backend = map['backend'];
                          String platform = map['platform'];
                          return
                              // List with queue items and artwork
                            SwipeActionCell(
                              key: ObjectKey(index), /// this key is necessary
                              trailingActions: <SwipeAction>[
                                SwipeAction(
                                    title: "delete",
                                    onTap: (CompletionHandler handler) async {
                                      final SharedPreferences prefs = await SharedPreferences.getInstance();
                                      setState(() {
                                        savedMachines.removeAt(index);
                                        List<String> categoriesList = List<String>.from(savedMachines as List);
                                        prefs.setStringList('machines', categoriesList);
                                      });
                                    },
                                    color: Colors.red),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.all(1.0),
                                child: ListTile(
                                  title: Text(friendlyName),
                                  subtitle: Text(host),
                                  onTap: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => PlayerScreen(
                                              data: savedMachines[index],
                                            )));
                                  },
                                )
                              ),
                            );


                        }),
                    SizedBox(
                      height: 30,
                    )
                  ])
                : Container(),
            Text(
              'Scanning Cider Remote instance',
            ),
            Container(height: 20),
            CircularProgressIndicator(
              valueColor: animationController
                  .drive(ColorTween(begin: Colors.blueAccent, end: Colors.red)),
            ),
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
