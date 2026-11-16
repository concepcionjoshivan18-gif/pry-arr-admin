import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

void main() {
  final mapsImpl = GoogleMapsFlutterPlatform.instance;
  if (mapsImpl is GoogleMapsFlutterAndroid) {
    mapsImpl.useAndroidViewSurface = true;
  }
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: StoreMapScreen(),
  ));
}

class StoreMapScreen extends StatelessWidget {
  const StoreMapScreen({super.key});

  static const _store = LatLng(14.5995, 120.9842); // replace with your store's coordinates

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Us')),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(target: _store, zoom: 15),
        markers: {
          const Marker(
            markerId: MarkerId('store'),
            position: _store,
            infoWindow: InfoWindow(title: 'Our Hardware Store'),
          ),
        },
      ),
    );
  }
}