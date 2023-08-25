// To parse this JSON data, do
//
//     final responseGetCheckIn = responseGetCheckInFromJson(jsonString);

import 'dart:convert';

ResponseGetCheckIn responseGetCheckInFromJson(String str) => ResponseGetCheckIn.fromJson(json.decode(str));

String responseGetCheckInToJson(ResponseGetCheckIn data) => json.encode(data.toJson());

class ResponseGetCheckIn {
  int s;
  String m;
  Rs rs;

  ResponseGetCheckIn({
    this.s,
    this.m,
    this.rs,
  });

  factory ResponseGetCheckIn.fromJson(Map<String, dynamic> json) => ResponseGetCheckIn(
    s: json["s"] == null ? null : json["s"],
    m: json["m"] == null ? null : json["m"],
    rs: json["rs"] == null ? null : Rs.fromJson(json["rs"]),
  );

  Map<String, dynamic> toJson() => {
    "s": s == null ? null : s,
    "m": m == null ? null : m,
    "rs": rs == null ? null : rs.toJson(),
  };
}

class Rs {
  String deviceCheckinsCount;
  String allCheckinsCount;
  List<LocationViewData> locations;

  Rs({
    this.deviceCheckinsCount,
    this.allCheckinsCount,
    this.locations,
  });

  factory Rs.fromJson(Map<String, dynamic> json) => Rs(
    deviceCheckinsCount: json["device_checkins_count"] == null ? null : json["device_checkins_count"],
    allCheckinsCount: json["all_checkins_count"] == null ? null : json["all_checkins_count"],
    locations: json["locations"] == null ? null : List<LocationViewData>.from(json["locations"].map((x) => LocationViewData.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "device_checkins_count": deviceCheckinsCount == null ? null : deviceCheckinsCount,
    "all_checkins_count": allCheckinsCount == null ? null : allCheckinsCount,
    "locations": locations == null ? null : List<dynamic>.from(locations.map((x) => x.toJson())),
  };
}

class LocationViewData {
  String id;
  String location;
  String locLat;
  String locLong;
  String status;
  DateTime createdAt;
  DateTime updatedAt;
  int deviceCheckinStatus;

  LocationViewData({
    this.id,
    this.location,
    this.locLat,
    this.locLong,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deviceCheckinStatus,
  });

  factory LocationViewData.fromJson(Map<String, dynamic> json) => LocationViewData(
    id: json["id"] == null ? null : json["id"],
    location: json["location"] == null ? null : json["location"],
    locLat: json["loc_lat"] == null ? null : json["loc_lat"],
    locLong: json["loc_long"] == null ? null : json["loc_long"],
    status: json["status"] == null ? null : json["status"],
    createdAt: json["created_at"] == null ? null : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null ? null : DateTime.parse(json["updated_at"]),
    deviceCheckinStatus: json["device_checkin_status"] == null ? null : json["device_checkin_status"],
  );

  Map<String, dynamic> toJson() => {
    "id": id == null ? null : id,
    "location": location == null ? null : location,
    "loc_lat": locLat == null ? null : locLat,
    "loc_long": locLong == null ? null : locLong,
    "status": status == null ? null : status,
    "created_at": createdAt == null ? null : createdAt.toIso8601String(),
    "updated_at": updatedAt == null ? null : updatedAt.toIso8601String(),
    "device_checkin_status": deviceCheckinStatus == null ? null : deviceCheckinStatus,
  };
}
