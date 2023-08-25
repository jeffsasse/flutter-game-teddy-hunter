import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teddyhunt/common/app_colors.dart';
import 'package:teddyhunt/ui/map_screen.dart';

void main() async {
  Widget _defaultHome = new MapScreen();

  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(
      new MaterialApp(
        color: AppColors.mainAppColor,
        debugShowCheckedModeBanner: false,
        title: 'Deliverit',
        home: _defaultHome,
        routes: {
          MapScreen.tag: (context) => MapScreen(),
        },
      ),
    );
  });
}

