import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AlertToast {
  static void showToastMsg(String txt) {
    Fluttertoast.showToast(
      msg: txt,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIos: 5,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
    );
  }
}