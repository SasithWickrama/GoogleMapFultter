import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_map_polyline_new/google_map_polyline_new.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _polylineCount = 1;
  Map<PolylineId, Polyline> _polylines = <PolylineId, Polyline>{};
  Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};
  double? distance;
  int? duration;

  GoogleMapPolyline _googleMapPolyline =
      new GoogleMapPolyline(apiKey: "AIzaSyBZKPCs6Tn-0K_u5g_Fu6dWRoYamPhzlF8");

  // Polyline patterns
  List<List<PatternItem>> patterns = <List<PatternItem>>[
    <PatternItem>[], // line
    <PatternItem>[PatternItem.dash(30.0), PatternItem.gap(20.0)], // dash
    <PatternItem>[PatternItem.dot, PatternItem.gap(10.0)], // dot
    <PatternItem>[
      // dash-dot
      PatternItem.dash(30.0),
      PatternItem.gap(20.0),
      PatternItem.dot,
      PatternItem.gap(20.0)
    ],
  ];

  final LatLng _mapInitLocation = const LatLng(6.914224, 79.972179);
  LatLng _originLocation = const LatLng(6.914224, 79.972179);
  LatLng _destinationLocation = const LatLng(6.915327, 79.973861);

  GoogleMapController?
      _controller; // Add this line to store the controller instance

  bool _loading = false;

/*  _onMapCreated(GoogleMapController controller) {
    setState(() {
      // Store the controller instance for later use
      _controller = controller;

      // Add markers for the start and destination points when the map is created
      _addMarker(
        _originLocation,
        "Start",
        50.0, // Set the desired size
        Colors.green, // Set the desired color
      );

      _addMarker(
        _destinationLocation,
        "Destination",
        50.0, // Set the desired size
        Colors.orange, // Set the desired color
      );
    });
  }
*/

/*  Future<Uint8List> _createMarkerImage(double size, Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;

    // Draw a circle on the canvas to represent the marker
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      paint,
    );

    // Convert the canvas to an image
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final imgByteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return imgByteData!.buffer.asUint8List();
  }

  _addMarker(LatLng position, String title, double size, Color color) async {
    final markerId = MarkerId(position.toString());

    // Create a custom marker icon with desired size and color
    final markerIcon = BitmapDescriptor.fromBytes(
      await _createMarkerImage(size, color),
    );

    final marker = Marker(
      markerId: markerId,
      position: position,
      icon: markerIcon,
      infoWindow: InfoWindow(title: title),
    );

    setState(() {
      _markers[markerId] = marker;
    });
  }
*/

  _onMapCreated(GoogleMapController controller) {
    setState(() {
      // Store the controller instance for later use
      _controller = controller;

      // Add markers for the start and destination points when the map is created
      _addBusMarker(_originLocation, "Start", 1.0 , 'assets/bus_icon.png',"NB-9572");
    });
  }

_addBusMarker(LatLng position, String title, double size, String path, String name) async {
  final markerId = MarkerId(position.toString());

  // Create a custom marker icon with a bus image
  final markerIcon = await _createCustomMarker(path, size, name);

  final marker = Marker(
    markerId: markerId,
    position: position,
    icon: markerIcon,
    infoWindow: InfoWindow(title: title, snippet: name),
    anchor: Offset(0.5, 0.5),
  );

  setState(() {
    _markers[markerId] = marker;
  });
}

  Future<BitmapDescriptor> _createCustomMarker(String imagePath, double size, String label) async {
  final ByteData data = await rootBundle.load(imagePath);
  final Uint8List bytes = data.buffer.asUint8List();

  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo fi = await codec.getNextFrame();
  final ui.Image image = fi.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Draw the image on the canvas
  canvas.drawImage(image, Offset(0, 0), Paint());

  // Draw the label on the canvas
  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 25.0,
        fontWeight: FontWeight.bold, // Make the text bold
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();

  // Add padding to the text
  final double padding = 0.0;
  final double textX = padding;
  final double textY = image.height - textPainter.height - padding;

  textPainter.paint(canvas, Offset(textX, textY));

  // Convert the canvas to an image
  final picture = recorder.endRecording();
  final img = await picture.toImage(image.width, image.height);
  final imgByteData = await img.toByteData(format: ui.ImageByteFormat.png);

  if (imgByteData == null) {
    return BitmapDescriptor.defaultMarker;
  }

  final Uint8List uint8List = imgByteData.buffer.asUint8List();

  return BitmapDescriptor.fromBytes(uint8List);
}

  // Get polyline with Location (latitude and longitude)
  _getPolylinesWithLocation() async {
    _setLoadingMenu(true);
    List<LatLng>? _coordinates =
        await _googleMapPolyline.getCoordinatesWithLocation(
      origin: _originLocation,
      destination: _destinationLocation,
      mode: RouteMode.driving,
    );

    setState(() {
      _polylines.clear();
    });
    _addPolyline(_coordinates);
    _setLoadingMenu(false);
  }

  // Get polyline with Address
/*  _getPolylinesWithAddress() async {
    _setLoadingMenu(true);
    List<LatLng>? _coordinates =
        await _googleMapPolyline.getPolylineCoordinatesWithAddress(
      origin: 'Sri Lanka Institute Of Information Technology Rd',
      destination: 'SLIIT Faculty Parking',
      mode: RouteMode.driving,
    );

    setState(() {
      _polylines.clear();
    });
    _addPolyline(_coordinates);
    _setLoadingMenu(false);
  }
*/

  _addPolyline(List<LatLng>? _coordinates) {
    PolylineId id = PolylineId("poly$_polylineCount");
    Polyline polyline = Polyline(
      polylineId: id,
      patterns: patterns[0],
      color: Colors.blueAccent,
      points: _coordinates!,
      width: 10,
      onTap: () {},
    );

    setState(() {
      _polylines[id] = polyline;
      _polylineCount++;
    });
  }

  _setLoadingMenu(bool _status) {
    setState(() {
      _loading = _status;
    });
  }

// Function to call the API
  Future<void> callBusTrackerAPI() async {
    const String apiUrl =
        "https://bustracker.fyrestrap.com/bus_data_output_api.php";

    try {
      // Check if location permissions are granted
      var status = await Permission.location.status;
      if (status.isDenied) {
        // Request location permissions
        await Permission.location.request();
        // Check the status again after requesting permissions
        status = await Permission.location.status;
      }

      if (status.isGranted) {
        // Fetch the current location using Geolocator
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Use the current location as the destination
        _destinationLocation = LatLng(position.latitude, position.longitude);

        print("Updated Destination Location: $_destinationLocation");

        // Make the API call with the new destination location
        var response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          // Parse the response JSON
          print("Response data: ${response.body}");
          Map<String, dynamic> jsonResponse = json.decode(response.body);

          // Extract latitude and longitude values
          double latitude = double.parse(jsonResponse["latitude"]);
          double longitude = double.parse(jsonResponse["longitude"]);

          // Use the latitude and longitude values as needed
          _originLocation = LatLng(latitude, longitude);

          _addBusMarker(_destinationLocation, "Destination", 1.0,
              'assets/destination.png',"NB-9572"); // Set the desired size

          print("Updated Origin Location: $_originLocation");
          // Call _onMapCreated after fetching data to add markers for start and destination
          _onMapCreated(_controller!);
          // Continue with the rest of your code...
          _getPolylinesWithLocation();
        } else {
          throw Exception('Failed to call API');
        }
      } else {
        print("Location permissions denied by the user");
        // Handle the case where the user denied location permissions
      }
    } catch (e) {
      print("Error fetching data from the API or getting location: $e");
      // Handle the error as needed
    }
  }

  Future<void> getDistance() async {
    String apiKey = "AIzaSyBZKPCs6Tn-0K_u5g_Fu6dWRoYamPhzlF8";
    final String origin =
        "${_originLocation.latitude},${_originLocation.longitude}";
    final String destination =
        "${_destinationLocation.latitude},${_destinationLocation.longitude}";

    final String apiUrl =
        "https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$apiKey";

    try {
      final http.Response response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> routes = jsonResponse["routes"];

        if (routes.isNotEmpty) {
          final List<dynamic> legs = routes[0]["legs"];
          if (legs.isNotEmpty) {
            // Use the class-level variable instead of declaring a local variable
            distance =
                legs[0]["distance"]["value"] / 1000.0; // Convert to kilometers
            print('Distance: $distance km');
          } else {
            print('No legs found in the route');
          }
        } else {
          print('No routes found');
        }

        if (routes.isNotEmpty) {
          final List<dynamic> legs = routes[0]["legs"];
          if (legs.isNotEmpty) {
            // Extracting duration information in seconds
            final int durationInSeconds = legs[0]["duration"]["value"];
            // Convert duration to minutes
            final int durationInMinutes = (durationInSeconds / 60).round();

            print('Duration: $durationInMinutes minutes');

            // Call the function to update duration
            setState(() {
              duration = durationInMinutes;
            });
          } else {
            print('No legs found in the route');
          }
        } else {
          print('No routes found');
        }
      } else {
        print(
            'Failed to fetch directions. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching directions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Bus Tracking & Arrival Prediction System'),
        ),
        body: LayoutBuilder(
          builder: (context, cont) {
            return Column(
              children: <Widget>[
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height - 200,
                  child: GoogleMap(
                    onMapCreated: _onMapCreated,
                    markers: Set<Marker>.of(_markers.values),
                    polylines: Set<Polyline>.of(_polylines.values),
                    initialCameraPosition: CameraPosition(
                      target: _mapInitLocation,
                      zoom: 15,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.center,
                          child: ElevatedButton(
                            onPressed: () async {
                              await callBusTrackerAPI();
                              //_getPolylinesWithLocation();
                              await getDistance();
                            },
                            child: const Text(
                              'Show Bus Route',
                              style: TextStyle(
                                fontSize: 18, // Adjust the font size as needed
                              ),
                            ),
                          ),
                        ),
                        if (duration != null)
                          Container(
                              width: MediaQuery.of(context).size.width,
                              padding: const EdgeInsets.all(5.0),
                              child: Text(
                                'Distance: ${distance?.toStringAsFixed(2)} km & Duration: $duration minutes \n Powered by MS23478510',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              )),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _loading
            ? Container(
                color: Colors.black.withOpacity(0.75),
                child: const Center(
                  child: Text(
                    'Loading...',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            : Container(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
