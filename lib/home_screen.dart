import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  Position? currentPosition;
  List<LatLng> pathPoints = [];
  bool isTracking = false;
  bool isLoading = true;
  double totalDistance = 0.0;
  int speed = 0;
  Timer? trackingTimer;
  String status = "Tap START to begin tracking";
  
  late AnimationController pulseController;
  late Animation<double> pulseAnimation;

  @override
  void initState() {
    super.initState();
    pulseController = AnimationController(vsync: this, duration: Duration(seconds: 1));
    pulseAnimation = Tween(begin: 1.0, end: 1.3).animate(pulseController);
    pulseController.repeat(reverse: true);
    initLocation();
  }

  Future<void> initLocation() async {
    setState(() => isLoading = true);
    
    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    setState(() {
      currentPosition = position;
      status = "GPS Ready - ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
      isLoading = false;
    });

    mapController?.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(position.latitude, position.longitude), 16));
  }

  void startTracking() {
    setState(() {
      isTracking = true;
      status = "Tracking Live...";
    });
    
    trackingTimer = Timer.periodic(Duration(seconds: 3), (timer) => updateLocation());
  }

  void stopTracking() {
    trackingTimer?.cancel();
    setState(() {
      isTracking = false;
      status = "Stopped! Total: ${totalDistance.toStringAsFixed(2)} km | ${pathPoints.length} points";
    });
  }

  Future<void> updateLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    setState(() {
      currentPosition = position;
      speed = (position.speed * 3.6).round();
    });

    LatLng newPoint = LatLng(position.latitude, position.longitude);
    
    if (pathPoints.isNotEmpty) {
      double distance = Geolocator.distanceBetween(
        pathPoints.last.latitude, pathPoints.last.longitude,
        newPoint.latitude, newPoint.longitude,
      );
      totalDistance += distance / 1000;
    }
    
    pathPoints.add(newPoint);
    
    mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
  }

  Future<void> exportTrack() async {
    final dir = await getExternalStorageDirectory();
    final file = File('${dir!.path}/gps_track_${DateTime.now().millisecondsSinceEpoch}.txt');
    await file.writeAsString('Distance: ${totalDistance.toStringAsFixed(2)}km\nPoints: ${pathPoints.length}\n${pathPoints.map((p) => '${p.latitude},${p.longitude}').join('\n')}');
    Fluttertoast.showToast(msg: 'Track saved to ${file.path}');
  }

  void clearTrack() {
    setState(() {
      pathPoints.clear();
      totalDistance = 0.0;
      status = "Track cleared";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          currentPosition == null || isLoading
              ? Center(child: SpinKitDoubleBounce(color: Colors.teal))
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                    zoom: 16,
                  ),
                  onMapCreated: (controller) => mapController = controller,
                  myLocationEnabled: true,
                  markers: {
                    Marker(
                      markerId: MarkerId('current'),
                      position: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                    )
                  },
                  polylines: {
                    Polyline(
                      polylineId: PolylineId('path'),
                      points: pathPoints,
                      color: isTracking ? Colors.red : Colors.blue,
                      width: 6,
                    )
                  },
                ),
          
          // Header
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("GPS TRACKER", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Icon(Icons.gps_fixed, color: Colors.red, size: 28),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(status, style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
          
          // Stats
          Positioned(
            bottom: 220,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text("DISTANCE", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text("${totalDistance.toStringAsFixed(2)} km", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text("SPEED", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text("$speed km/h", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Big Track Button
          Positioned(
            bottom: 100,
            left: 40,
            right: 40,
            child: GestureDetector(
              onTap: isTracking ? stopTracking : startTracking,
              child: AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: pulseAnimation.value,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: isTracking 
                          ? [Colors.red.shade400, Colors.red.shade600]
                          : [Colors.teal.shade400, Colors.teal.shade600]),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isTracking ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 30),
                          SizedBox(width: 15),
                          Text(isTracking ? "STOP" : "START", 
                               style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                },
              ),
            ),
          ),
          
          // Action Buttons
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "export",
                  mini: true,
                  onPressed: exportTrack,
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.download),
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "clear",
                  mini: true,
                  onPressed: clearTrack,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.clear),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    pulseController.dispose();
    trackingTimer?.cancel();
    super.dispose();
  }
}
