import 'dart:io';

import 'package:cider_remote/player.dart';
import 'package:cider_remote/webview.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore: must_be_immutable
class QRViewScreen extends StatefulWidget {
  String? id = "";
  void onQRViewCreated;
  @override
  _QRViewScreen createState() => _QRViewScreen();
}



class _QRViewScreen extends State<QRViewScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  late QRViewController controller;
  var savedMachines = [];

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller.pauseCamera();
    } else if (Platform.isIOS) {
      controller.resumeCamera();
    }
  }

  void getSavedMachines() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedMachines = prefs.getStringList('machines')?? [];
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child:
                  Text('Scan your Cider Remote QR'),
            ),
          )
        ],
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context);
        },
        label: const Text('Go back'),
        backgroundColor: Colors.pink,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        result = scanData;
        if (result != null && result!.code != null) {
          controller.stopCamera();
          // check if the scanned data is a cider remote link or json data

          if (result!.code!
              .contains("pair-api.ciderapp.workers.dev/?data=")

          ) {
            var b64data= result!.code!.substring(result!.code!.indexOf('data=')+5);
            if (!savedMachines.contains(b64data)){
              setState(() {
                savedMachines.add(b64data);
                List<String> categoriesList = List<String>.from(savedMachines as List);
                prefs.setStringList('machines', categoriesList);
              });
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                        data: result!.code!.substring(result!.code!.indexOf('data=')+5),
                      )),
            );
          }
          else if (result!.code!.contains("initialData")) {
            if (!savedMachines.contains(result!.code!)){
              setState(() {
                savedMachines.add(result!.code!);
                List<String> categoriesList = List<String>.from(savedMachines as List);
                prefs.setStringList('machines', categoriesList);
              });
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                    data: result!.code!,
                  )),
            );
          }

          else {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => WebViewScreen(
                        ip: result!.code!,
                      )),
            );
          }
        }
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
