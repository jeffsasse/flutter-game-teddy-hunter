import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class ApiUtils {
  static Dio dio = new Dio();

  Future<dynamic> get(BuildContext context, String url) async {
    debugPrint("GET URL : $url");
    return dio
        .get(
          url,
        )
        .then((response) => onResponse(context, response));
  }

  Future<dynamic> post(BuildContext context, String url,
      {Map<String, String> body}) async {
    debugPrint("POST URL : $url");
    debugPrint("Request body : $body");
    return dio
        .post(
          url,
          data: FormData.fromMap(body),
        )
        .then((response) => onResponse(context, response));
  }

  Future<dynamic> put(BuildContext context, String url,
      {Map<String, String> body}) async {
    debugPrint("PUT URL : $url");
    debugPrint("Request body : $body");
    return dio
        .put(
          url,
          data: FormData.fromMap(body),
        )
        .then((response) => onResponse(context, response));
  }

  onResponse(BuildContext context, Response<dynamic> response) {
    int code = response.statusCode;
    var resData = response.data;
    debugPrint("Response body : $code..." + response.data.toString());
    if (code < 200 || code > 400) {
      throw new Exception("Server Error...");
    }
    return json.decode(json.encode(resData));
  }
}
