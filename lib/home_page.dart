import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:flutter_ocr_sdk/flutter_ocr_sdk_platform_interface.dart';
import 'package:flutter_ocr_sdk/mrz_line.dart';
import 'package:flutter_ocr_sdk/mrz_parser.dart';
import 'package:flutter_ocr_sdk/mrz_result.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'result_page.dart';
import 'utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'camera_page.dart';
import 'global.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final picker = ImagePicker();

  void openResultPage(MrzResult information) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultPage(information: information),
        ));
  }

  void scanImage() async {
    XFile? photo = await picker.pickImage(source: ImageSource.gallery);

    if (photo == null) {
      return;
    }

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      File rotatedImage =
          await FlutterExifRotation.rotateImage(path: photo.path);
      photo = XFile(rotatedImage.path);
    }

    Uint8List fileBytes = await photo.readAsBytes();

    ui.Image image = await decodeImageFromList(fileBytes);

    ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData != null) {
      List<List<MrzLine>>? results = await mrzDetector.recognizeByBuffer(
          byteData.buffer.asUint8List(),
          image.width,
          image.height,
          byteData.lengthInBytes ~/ image.height,
          ImagePixelFormat.IPF_ARGB_8888.index);
      List<MrzLine>? finalArea;
      var information;
      if (results != null && results.isNotEmpty) {
        for (List<MrzLine> area in results) {
          if (area.length == 2) {
            finalArea = area;
            information = MRZ.parseTwoLines(area[0].text, area[1].text);
            information.lines = '${area[0].text}\n${area[1].text}';
            break;
          } else if (area.length == 3) {
            finalArea = area;
            information =
                MRZ.parseThreeLines(area[0].text, area[1].text, area[2].text);
            information.lines =
                '${area[0].text}\n${area[1].text}\n${area[2].text}';
            break;
          }
        }
      }
      if (finalArea != null) {
        openResultPage(information!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = Row(
      children: [
        Container(
            padding: const EdgeInsets.only(
              top: 30,
              left: 33,
            ),
            child: const Text('MRZ SCANNER',
                style: TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                )))
      ],
    );

    final description = Row(
      children: [
        Container(
            padding: const EdgeInsets.only(top: 6, left: 33, bottom: 44),
            child: const SizedBox(
              width: 271,
              child: Text(
                  'Recognizes MRZ code & extracts data from 1D-codes, passports, and visas.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  )),
            ))
      ],
    );

    final buttons = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
            onTap: () {
              if (!kIsWeb && Platform.isLinux) {
                showAlert(context, "Warning",
                    "${Platform.operatingSystem} is not supported");
                return;
              }

              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return const CameraPage();
              }));
            },
            child: Container(
              width: 150,
              height: 125,
              decoration: BoxDecoration(
                color: colorOrange,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    "images/icon-camera.png",
                    width: 90,
                    height: 60,
                  ),
                  const Text(
                    "Camera Scan",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  )
                ],
              ),
            )),
        GestureDetector(
            onTap: () {
              scanImage();
            },
            child: Container(
              width: 150,
              height: 125,
              decoration: BoxDecoration(
                color: colorBackground,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    "images/icon-image.png",
                    width: 90,
                    height: 60,
                  ),
                  const Text(
                    "Image Scan",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  )
                ],
              ),
            ))
      ],
    );

    final image = Image.asset(
      "images/image-mrz.png",
      width: MediaQuery.of(context).size.width,
      fit: BoxFit.cover,
    );
    return Scaffold(
      body: Column(
        children: [
          title,
          description,
          buttons,
          const SizedBox(
            height: 34,
          ),
          Expanded(
              child: Stack(
            children: [
              Positioned.fill(
                child: image,
              ),
              if (!isLicenseValid)
                Opacity(
                  opacity: 0.8,
                  child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: 40,
                      color: const Color(0xffFF1A1A),
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: InkWell(
                          onTap: () {
                            launchUrlString(
                                'https://www.dynamsoft.com/customer/license/trialLicense?product=dlr');
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.white, size: 20),
                              Text(
                                "  License expired! Renew your license ->",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ))),
                )
            ],
          ))
        ],
      ),
    );
  }
}