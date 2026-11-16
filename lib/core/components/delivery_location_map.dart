import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/hardware_theme.dart';

class DeliveryLocationMap extends StatelessWidget {
  final LatLng location;
  final LatLng? origin;
  final double height;
  final bool isInteractive;

  const DeliveryLocationMap({
    super.key,
    required this.location,
    this.origin = const LatLng(14.2818, 121.4167), // PRY-ARR Store Origin (Santa Cruz, Laguna)
    this.height = 200,
    this.isInteractive = true,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2429),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hwOrange, width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pin_drop_rounded, color: hwOrange, size: 36),
            const SizedBox(height: 8),
            Text(
              'Delivery Location Pin: ${location.latitude.toStringAsFixed(4)}° N, ${location.longitude.toStringAsFixed(4)}° E',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('delivery'),
        position: location,
        infoWindow: const InfoWindow(title: 'Delivery location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (origin != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('store_origin'),
          position: origin!,
          infoWindow: const InfoWindow(title: 'PRY-ARR Store'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (origin != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: [origin!, location],
          color: hwOrange,
          width: 4,
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: location,
            zoom: 15,
          ),
          mapType: MapType.normal,
          scrollGesturesEnabled: isInteractive,
          zoomGesturesEnabled: isInteractive,
          rotateGesturesEnabled: isInteractive,
          tiltGesturesEnabled: isInteractive,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: isInteractive,
          markers: markers,
          polylines: polylines,
        ),
      ),
    );
  }
}
