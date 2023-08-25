import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:progress_dialog/progress_dialog.dart';
import 'package:teddyhunt/api/api_utils.dart';
import 'package:teddyhunt/api/url_utils.dart';
import 'package:teddyhunt/common/app_colors.dart';
import 'package:teddyhunt/common/toast_util.dart';
import 'package:teddyhunt/common/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class LocationResult {
  String name;
  String locality;
  LatLng latLng;
  String formattedAddress;
  String placeId;
}

class NearbyPlace {
  String name;
  String icon;
  LatLng latLng;
}

class AutoCompleteItem {
  String id;
  String text;
  int offset;
  int length;
}

class PlacePicker extends StatefulWidget {
  final String apiKey;
  final LatLng displayLocation;

  PlacePicker(this.apiKey, {this.displayLocation});

  @override
  State<StatefulWidget> createState() {
    return PlacePickerState();
  }
}

class PlacePickerState extends State<PlacePicker> {
  final Completer<GoogleMapController> mapController = Completer();
  final Set<Marker> markers = Set();
  LocationResult locationResult;
  OverlayEntry overlayEntry;
  List<NearbyPlace> nearbyPlaces = List();
  String sessionToken = Uuid().v4();
  GlobalKey appBarKey = GlobalKey();
  bool hasSearchTerm = false;
  String previousSearchTerm = '';

  int _mapTypeSelection = 0;

  CameraPosition _cameraPosition;

  ProgressDialog pr;

  Map<int, Widget> _mapType = {
    0: Padding(
      padding: new EdgeInsets.fromLTRB(25, 1, 25, 1),
      child: Text("Normal"),
    ),
    1: Padding(
      padding: new EdgeInsets.fromLTRB(25, 1, 25, 1),
      child: Text("Satellite"),
    ),
  };

  PlacePickerState();

  void onMapCreated(GoogleMapController controller) {
    this.mapController.complete(controller);
    moveToCurrentUserLocation();
  }

  @override
  void setState(fn) {
    if (this.mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    pr = new ProgressDialog(context);
    pr.style(message: "Please wait...");
    markers.add(Marker(
      position: widget.displayLocation ?? LatLng(23.4241, 53.8478),
      markerId: MarkerId("selected-location"),
    ));
  }

  @override
  void dispose() {
    this.overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: (){
        return null;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.mainAppColor,
          key: this.appBarKey,
          leading: IconButton(
            onPressed: (){
              Navigator.pop(context);
            },
            icon: Platform.isIOS?
            Icon(Icons.arrow_back_ios):
            Icon(Icons.arrow_back),
          ),
          title: SearchInput((it) {
            searchPlace(it);
          }),
          centerTitle: true,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: GoogleMap(
                mapType:
                _mapTypeSelection == 0 ? MapType.normal : MapType.satellite,
                initialCameraPosition: CameraPosition(
                  target: widget.displayLocation ?? LatLng(23.4241, 53.8478),
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: onMapCreated,
                onTap: (latLng) {
                  clearOverlay();
                  moveToLocation(latLng, zoom: _cameraPosition.zoom);
                },
                markers: markers,
                onCameraMove: (CameraPosition position) {
                  _cameraPosition = position;
                },
              ),
            ),
            this.hasSearchTerm
                ? SizedBox()
                : Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SelectPlaceAction(
                    getLocationName(),
                        () {
                      if (this.locationResult != null){
                        _addCheckIn();
                      }
                    },
                  ),
                  Divider(
                    height: 5,
                  ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(15),
                      child: InkWell(
                        onTap: (){
                          openInsta();
                        },
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color:  AppColors.buttonColor,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.grey, width: 0.5)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 30,
                                height: 30,
                                child: Image.asset("assets/instagram.png"),
                              ),
                              SizedBox(width: 10,),
                              Column(
                                children: <Widget>[
                                  Text("SEND US SCORES", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),),
                                  Text("AND TEDDY PICS", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  /*Expanded(
                        child: ListView(
                          children: this
                              .nearbyPlaces
                              .map(
                                (it) => NearbyPlaceItem(
                                  it,
                                  () {
                                    moveToLocation(it.latLng);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),*/
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hides the autocomplete overlay
  void clearOverlay() {
    if (this.overlayEntry != null) {
      this.overlayEntry.remove();
      this.overlayEntry = null;
    }
  }

  void searchPlace(String place) {
    if (place == this.previousSearchTerm) {
      return;
    } else {
      previousSearchTerm = place;
    }
    if (context == null) {
      return;
    }
    clearOverlay();
    setState(() {
      hasSearchTerm = place.length > 0;
    });
    if (place.length < 1) {
      return;
    }
    final RenderBox renderBox = context.findRenderObject();
    Size size = renderBox.size;

    final RenderBox appBarBox =
        this.appBarKey.currentContext.findRenderObject();

    this.overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: appBarBox.size.height,
        width: size.width,
        child: Material(
          elevation: 1,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 24,
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(
                  width: 24,
                ),
                Expanded(
                  child: Text(
                    "Finding place...",
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(this.overlayEntry);

    autoCompleteSearch(place);
  }

  void autoCompleteSearch(String place) {
    place = place.replaceAll(" ", "+");
    var endpoint =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?" +
            "key=${widget.apiKey}&" +
            "input={$place}&sessiontoken=${this.sessionToken}";

    if (this.locationResult != null) {
      endpoint += "&location=${this.locationResult.latLng.latitude}," +
          "${this.locationResult.latLng.longitude}";
    }
    http.get(endpoint).then((response) {
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        List<dynamic> predictions = data['predictions'];

        List<RichSuggestion> suggestions = [];

        if (predictions.isEmpty) {
          AutoCompleteItem aci = AutoCompleteItem();
          aci.text = "No result found";
          aci.offset = 0;
          aci.length = 0;

          suggestions.add(RichSuggestion(aci, () {}));
        } else {
          for (dynamic t in predictions) {
            AutoCompleteItem aci = AutoCompleteItem();

            aci.id = t['place_id'];
            aci.text = t['description'];
            aci.offset = t['matched_substrings'][0]['offset'];
            aci.length = t['matched_substrings'][0]['length'];

            suggestions.add(RichSuggestion(aci, () {
              FocusScope.of(context).requestFocus(FocusNode());
              decodeAndSelectPlace(aci.id);
            }));
          }
        }

        displayAutoCompleteSuggestions(suggestions);
      }
    }).catchError((error) {
      print(error);
    });
  }

  void decodeAndSelectPlace(String placeId) {
    clearOverlay();

    String endpoint =
        "https://maps.googleapis.com/maps/api/place/details/json?key=${widget.apiKey}" +
            "&placeid=$placeId";

    http.get(endpoint).then((response) {
      if (response.statusCode == 200) {
        Map<String, dynamic> location =
            jsonDecode(response.body)['result']['geometry']['location'];

        LatLng latLng = LatLng(location['lat'], location['lng']);

        moveToLocation(latLng);
      }
    }).catchError((error) {
      print(error);
    });
  }

  void displayAutoCompleteSuggestions(List<RichSuggestion> suggestions) {
    final RenderBox renderBox = context.findRenderObject();
    Size size = renderBox.size;

    final RenderBox appBarBox =
        this.appBarKey.currentContext.findRenderObject();

    clearOverlay();

    this.overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        top: appBarBox.size.height,
        child: Material(
          elevation: 1,
          child: Column(
            children: suggestions,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(this.overlayEntry);
  }

  String getLocationName() {
    if (this.locationResult == null) {
      return "Unnamed location";
    }

    for (NearbyPlace np in this.nearbyPlaces) {
      if (np.latLng == this.locationResult.latLng &&
          np.name != this.locationResult.locality) {
        this.locationResult.name = np.name;
        return "${np.name}, ${this.locationResult.locality}";
      }
    }

    return "${this.locationResult.name}, ${this.locationResult.locality}";
  }

  /// Moves the marker to the indicated lat,lng
  void setMarker(LatLng latLng) {
    // markers.clear();
    setState(() {
      markers.clear();
      markers.add(
        Marker(
          markerId: MarkerId("selected-location"),
          position: latLng,
        ),
      );
    });
  }

  void getNearbyPlaces(LatLng latLng) {
    http
        .get("https://maps.googleapis.com/maps/api/place/nearbysearch/json?" +
            "key=${widget.apiKey}&" +
            "location=${latLng.latitude},${latLng.longitude}&radius=150")
        .then((response) {
      if (response.statusCode == 200) {
        this.nearbyPlaces.clear();
        for (Map<String, dynamic> item
            in jsonDecode(response.body)['results']) {
          NearbyPlace nearbyPlace = NearbyPlace();

          nearbyPlace.name = item['name'];
          nearbyPlace.icon = item['icon'];
          double latitude = item['geometry']['location']['lat'];
          double longitude = item['geometry']['location']['lng'];

          LatLng _latLng = LatLng(latitude, longitude);

          nearbyPlace.latLng = _latLng;

          this.nearbyPlaces.add(nearbyPlace);
        }
      }

      // to update the nearby places
      setState(() {
        // this is to require the result to show
        this.hasSearchTerm = false;
      });
    }).catchError((error) {});
  }

  void reverseGeocodeLatLng(LatLng latLng) {
    http
        .get("https://maps.googleapis.com/maps/api/geocode/json?" +
            "latlng=${latLng.latitude},${latLng.longitude}&" +
            "key=${widget.apiKey}")
        .then((response) {
      if (response.statusCode == 200) {
        Map<String, dynamic> responseJson = jsonDecode(response.body);

        final result = responseJson['results'][0];

        String road = result['address_components'][0]['short_name'];
        String locality = result['address_components'][1]['short_name'];

        setState(() {
          this.locationResult = LocationResult();
          this.locationResult.name = road;
          this.locationResult.locality = locality;
          this.locationResult.latLng = latLng;
          this.locationResult.formattedAddress = result['formatted_address'];
          this.locationResult.placeId = result['place_id'];
        });
      }
    }).catchError((error) {
      print(error);
    });
  }

  void moveToLocation(LatLng latLng, {double zoom}) {
    this.mapController.future.then((controller) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: latLng,
            zoom: zoom == null ? 15.0 : zoom,
          ),
        ),
      );
    });

    setMarker(latLng);

    reverseGeocodeLatLng(latLng);

    getNearbyPlaces(latLng);
  }

  void moveToCurrentUserLocation() {
    if (widget.displayLocation != null) {
      moveToLocation(widget.displayLocation);
      return;
    }

    var location = Location();
    location.getLocation().then((locationData) {
      LatLng target = LatLng(locationData.latitude, locationData.longitude);
      moveToLocation(target);
    }).catchError((error) {
      // TODO: Handle the exception here
      print(error);
    });
  }

  openInsta() async {
    const url = 'https://urlgeni.us/instagram/tpv';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _addCheckIn() async {
    await pr.show();
    Map<String, String> body = {
      'device_id': await TeddyHuntUtils.getUUID(),
      'location': this.locationResult.name,
      'loc_lat': this.locationResult.latLng.latitude.toString(),
      'loc_long': this.locationResult.latLng.longitude.toString(),
    };
    ApiUtils().post(context, URL.addLocation, body: body).then((response) {
      pr.hide();
      AlertToast.showToastMsg(response['m']);
      Navigator.pop(context);
    }).catchError((error) {
      if (error.type == DioErrorType.DEFAULT) {
        AlertToast.showToastMsg("No internet connection");
      } else {
        AlertToast.showToastMsg("Something went wrong");
      }
    });
  }
}

class SearchInput extends StatefulWidget {
  final ValueChanged<String> onSearchInput;

  SearchInput(this.onSearchInput);

  @override
  State<StatefulWidget> createState() {
    return SearchInputState();
  }
}

class SearchInputState extends State<SearchInput> {
  TextEditingController editController = TextEditingController();

  Timer debouncer;

  bool hasSearchEntry = false;

  SearchInputState();

  @override
  void initState() {
    super.initState();
    this.editController.addListener(this.onSearchInputChange);
  }

  @override
  void dispose() {
    this.editController.removeListener(this.onSearchInputChange);
    this.editController.dispose();

    super.dispose();
  }

  void onSearchInputChange() {
    if (this.editController.text.isEmpty) {
      this.debouncer?.cancel();
      widget.onSearchInput(this.editController.text);
      return;
    }

    if (this.debouncer?.isActive ?? false) {
      this.debouncer.cancel();
    }

    this.debouncer = Timer(Duration(milliseconds: 500), () {
      widget.onSearchInput(this.editController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.search,
            color: Theme.of(context).textTheme.body1.color,
          ),
          SizedBox(
            width: 8,
          ),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Add a New Teddy Bear Location",
                border: InputBorder.none,
              ),
              controller: this.editController,
              onChanged: (value) {
                setState(() {
                  this.hasSearchEntry = value.isNotEmpty;
                });
              },
            ),
          ),
          SizedBox(
            width: 8,
          ),
          this.hasSearchEntry
              ? GestureDetector(
                  child: Icon(
                    Icons.clear,
                  ),
                  onTap: () {
                    this.editController.clear();
                    setState(() {
                      this.hasSearchEntry = false;
                    });
                  },
                )
              : SizedBox(),
        ],
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).canvasColor,
      ),
    );
  }
}

class SelectPlaceAction extends StatelessWidget {
  String locationName;
  final VoidCallback onTap;

  SelectPlaceAction(this.locationName, this.onTap);

  @override
  Widget build(BuildContext context) {
    locationName = locationName.replaceAll(", ", " ");
    return Material(
      child: InkWell(
        onTap: () {
          this.onTap();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      locationName,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "Tap to select this location",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              /*Icon(
                Icons.arrow_forward,
              )*/
              Text(
                'ADD',
                style: TextStyle(
                  color: AppColors.mainAppColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class NearbyPlaceItem extends StatelessWidget {
  final NearbyPlace nearbyPlace;
  final VoidCallback onTap;

  NearbyPlaceItem(this.nearbyPlace, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: Row(
              children: <Widget>[
                Image.network(
                  nearbyPlace.icon,
                  width: 16,
                ),
                SizedBox(
                  width: 24,
                ),
                Expanded(
                  child: Text(
                    "${nearbyPlace.name}",
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                )
              ],
            )),
      ),
    );
  }
}

class RichSuggestion extends StatelessWidget {
  final VoidCallback onTap;
  final AutoCompleteItem autoCompleteItem;

  RichSuggestion(this.autoCompleteItem, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: RichText(
                    text: TextSpan(children: getStyledTexts(context)),
                  ),
                )
              ],
            )),
        onTap: this.onTap,
      ),
    );
  }

  List<TextSpan> getStyledTexts(BuildContext context) {
    final List<TextSpan> result = [];

    String startText =
        this.autoCompleteItem.text.substring(0, this.autoCompleteItem.offset);
    if (startText.isNotEmpty) {
      result.add(
        TextSpan(
          text: startText,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 15,
          ),
        ),
      );
    }

    String boldText = this.autoCompleteItem.text.substring(
        this.autoCompleteItem.offset,
        this.autoCompleteItem.offset + this.autoCompleteItem.length);

    result.add(TextSpan(
      text: boldText,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).textTheme.body1.color,
      ),
    ));

    String remainingText = this
        .autoCompleteItem
        .text
        .substring(this.autoCompleteItem.offset + this.autoCompleteItem.length);
    result.add(
      TextSpan(
        text: remainingText,
        style: TextStyle(
          color: Colors.grey,
          fontSize: 15,
        ),
      ),
    );

    return result;
  }
}
