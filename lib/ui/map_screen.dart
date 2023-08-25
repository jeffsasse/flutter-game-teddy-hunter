import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:teddyhunt/api/api_utils.dart';
import 'package:teddyhunt/api/url_utils.dart';
import 'package:teddyhunt/common/app_colors.dart';
import 'package:teddyhunt/common/shared_preferences.dart';
import 'package:teddyhunt/common/toast_util.dart';
import 'package:teddyhunt/common/utils.dart';
import 'package:teddyhunt/models/response_get_check_in.dart';
import 'package:teddyhunt/ui/place_picker_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class Place {
  double latitude;
  double longitude;
  String address;

  Place({
    this.latitude,
    this.longitude,
    this.address,
  });
}

class MapScreen extends StatefulWidget {
  static String tag = "/map";

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  //Google map related
  BitmapDescriptor iconBeforeCheckin;
  BitmapDescriptor iconAfterCheckin;
  String pfShowHelp;

  Completer<GoogleMapController> _controller;
  Set<Marker> _markers = {};
  Position _currentLocation;

  bool _isLoading = false;

  ResponseGetCheckIn _responseGetCheckIn;

  StreamSubscription<Position> _getPositionSubscription;

  void _getLocation() async {
    setState(() {
      _isLoading = true;
    });
    _currentLocation = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    if (_currentLocation != null) {
      if(pfShowHelp!=null){
        updatePinOnMap();
        _addLocationObserver();
        _getCheckInRecords();
      }else{
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int num = 0;

  void _addLocationObserver() {
    if (_getPositionSubscription == null) {
      const LocationOptions locationOptions =
      LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 5);

      final Stream<Position> positionStream =
      Geolocator().getPositionStream(locationOptions);

      _getPositionSubscription = positionStream.listen((Position position) {
        if (position != null) {
          if(num == 0){
            num = 1;
            Future.delayed(Duration(seconds: 5), (){
              _getCheckInRecords();
            });
          }

          _currentLocation = position;
          updatePinOnMap();

        }
      });
      _getPositionSubscription.pause();
    }

    if (_getPositionSubscription.isPaused) {
      _getPositionSubscription.resume();
    } else {
      _getPositionSubscription.pause();
    }

    setState(() {});
  }

  Future<void> _getCheckInRecords() async {
    ApiUtils()
        .get(context,
        '${URL.getLocations}?device_id=${await TeddyHuntUtils.getUUID()}&loc_lat=${_currentLocation.latitude}&loc_long=${_currentLocation.longitude}')
        .then((dynamic response) async {
          num = 0;
      if (response["s"] == 1) {
        var res = ResponseGetCheckIn.fromJson(response);
        _setMarkers(res);
      } else {
        setState(() {
          _isLoading = false;
        });
        AlertToast.showToastMsg(response["m"]);
      }
    }).catchError((error) {
      num = 0;
      setState(() {
        _isLoading = false;
      });
      if (error.type == DioErrorType.DEFAULT) {
        AlertToast.showToastMsg("No internet connection");
      } else {
        AlertToast.showToastMsg("Something went wrong");
      }
    });
  }

  _setMarkers(ResponseGetCheckIn res) {
    _markers.clear();

    Set<Marker> _dummyMarkers = {};

    if (res != null) {
      for (int i = 0; i < res.rs.locations.length; i++) {
        var item = res.rs.locations[i];
        _dummyMarkers.add(
          Marker(
              markerId: MarkerId(item.id),
              position: LatLng(
                double.parse(item.locLat),
                double.parse(item.locLong),
              ),
              infoWindow: InfoWindow(
                title: item.location,
              ),
              onTap: () {
                updatePinOnMap();
                if (item.deviceCheckinStatus == 0) {
                  _addCheckIn(item.id);
                }
              },
              icon: item.deviceCheckinStatus == 0
                  ? iconBeforeCheckin
                  : iconAfterCheckin
            /*icon: item.deviceCheckinStatus == 0
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                )
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),*/
          ),
        );
      }
    }
    _markers = _dummyMarkers;
    _responseGetCheckIn = res;
    _isLoading = false;
    setState(() {});
  }

  _addCheckIn(String id) async {

    Map<String, String> body = {
      'device_id': await TeddyHuntUtils.getUUID(),
      'location_id': id,
    };

    ApiUtils().post(context, URL.addCheckIn, body: body).then((response) {
      AlertToast.showToastMsg(response['m']);
      _getPositionSubscription = null;
      _getLocation();
    }).catchError((error) {
      if (error.type == DioErrorType.DEFAULT) {
        AlertToast.showToastMsg("No internet connection");
      } else {
        AlertToast.showToastMsg("Something went wrong");
      }
    });
  }

  Widget _topBody() {
    return new Container(
      color: AppColors.mainAppColor,
      height: MediaQuery.of(context).size.height * 0.25,
      width: MediaQuery.of(context).size.width,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: <Widget>[
          Opacity(
            opacity: 0.7,
            child: Image.asset(
              "assets/bg.png",
              fit: BoxFit.cover,
              width: MediaQuery.of(context).size.width * 0.70,
            ),
          ),
          Positioned(
            left: 20.0,
            top: 40.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                new Text(
                  "TEDDY BANK",
                  style: new TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 26.0),
                ),
                new Text(
                  _responseGetCheckIn != null
                      ? "${_responseGetCheckIn.rs.deviceCheckinsCount}"
                      : "0",
                  style: new TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 46.0),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _mapBody() {
    return ClipRRect(
      borderRadius: new BorderRadius.only(
        topLeft: Radius.circular(40),
        topRight: Radius.circular(40),
      ),
      child: new Container(
        color: AppColors.mainAppColor,
        child: Stack(
          children: <Widget>[
            GoogleMap(
              scrollGesturesEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: true,
              zoomGesturesEnabled: false,
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentLocation?.latitude??35.9748787,
                  _currentLocation?.longitude??-79.085389,
                ),
                zoom: 18,
              ),
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                _getLocation();
              },
            ),
            new Container(
              color: Colors.white.withOpacity(0.7),
              height: 60,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    new Container(
                      margin: EdgeInsets.only(left: 15, top: 5, bottom: 5),
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: new BorderRadius.all(
                          Radius.circular(40),
                        ),
                        color: AppColors.buttonColor,
                      ),
                      child: Row(
                        children: <Widget>[
                          new SizedBox(
                            width: 15,
                          ),
                          ClipOval(
                            child: Image.asset(
                              "assets/world.png",
                              height: 30,
                              width: 30,
                            ),
                          ),
                          new SizedBox(
                            width: 10,
                          ),
                          new Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              new Text(
                                "TEDDY TALLY",
                                style: new TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              new Text(
                                _responseGetCheckIn != null
                                    ? "${_responseGetCheckIn.rs.allCheckinsCount}"
                                    : "0",
                                style: new TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          new SizedBox(
                            width: 10,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: (){
                        openGofundme();
                      },
                      child: new Container(
                        margin: EdgeInsets.only(right: 15, top: 1, bottom: 5),
                        alignment: Alignment.center,
                        height: 54,
                        width: 56,
                        decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(50)
                        ),
                        child: Center(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text("DONATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),),
                            Text("TO C19", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),),
                            Text("RELIEF",  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),)
                          ],
                        ),),
                      ),
                    ),
                  ],
                ),
              )
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = Completer();
    getHelpPref();
      if(pfShowHelp == null){
        _getLocation();
      }
      setBeforeCheckinPin();
      setAfterCheckinPin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Container(
            color: AppColors.mainAppColor,
            child: Column(
              children: <Widget>[
                _topBody(),
                SizedBox(
                  child: new Container(
                    color: AppColors.mainAppColor,
                  ),
                  height: 20,
                ),
                Expanded(
                    child: pfShowHelp == null ? helpDialog() : _mapBody())
              ],
            ),
          ),
          _isLoading
              ? Container(
            color: Colors.white.withOpacity(0.3),
            child: Center(
              child: TeddyHuntUtils.progressIndicator(),
            ),
          )
              :Container()
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.mainAppColor,
        onPressed: () {
          showPlacePicker();
        },
        child: new Icon(
          Icons.add,
        ),
      ),
    );
  }

  showPlacePicker() async {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) =>
            PlacePicker("AIzaSyBaufeudiAD-D5OOKio76MB7wWGuQ2D6tY"),
      ),
    )
        .then((isReload) {
      if (isReload == null) {
        _getPositionSubscription = null;
        _getLocation();
      }
    });
  }

  openGofundme() async {
    const url = 'https://www.gofundme.com/f/teddy-hunt?utm_source=customer&utm_medium=copy_link&utm_campaign=p_cf+share-flow-1';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void setBeforeCheckinPin() async {
    iconBeforeCheckin = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 1.5), "assets/bear_dark.png");
  }

  void setAfterCheckinPin() async {
    iconAfterCheckin = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 1.5), "assets/bear.png");
  }

  @override
  void dispose() {
    super.dispose();
    if (_getPositionSubscription != null) {
      _getPositionSubscription.cancel();
      _getPositionSubscription = null;
    }
    debugPrint("Location listner removed");
  }

  getHelpPref() {
    Preferences.getString(Preferences.pfShowHelp).then((onValue) {
      setState(() {
        pfShowHelp = onValue;
        print("##$pfShowHelp");
      });
    });
  }

  Widget helpDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: 0.0,
      child: SingleChildScrollView(
        child: Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Text(
                  "1. Find as many Bears and Rainbows in your neighborhood as you can and add them to your Teddy Bank by tapping on each Rainbow Bear! (Teddy Bank will reset nightly)",
                  style: TextStyle(fontSize: 20.0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Text(
                  "2. If you see a bear or rainbow in a window that hasn't been mapped, hit the + button and add it!",
                  style: TextStyle(fontSize: 20.0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: RaisedButton(
                  color: AppColors.mainAppColor,
                  onPressed: () {
                    Preferences.setString(Preferences.pfShowHelp, "true");
                    pfShowHelp = "true";
                    setState(() {});
                  },
                  child: Text('OK',
                      style: TextStyle(fontSize: 20, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> updatePinOnMap() async {
    double lat = _currentLocation.latitude;
    CameraPosition cPosition = CameraPosition(
      target: LatLng(
        _currentLocation.latitude,
        _currentLocation.longitude,
      ),
      zoom: 18,
    );
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(cPosition));
    setState(() {});
  }
}
