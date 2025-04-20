import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Map Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MapSample(),
    );
  }
}

class MapSample extends StatefulWidget {
  const MapSample({super.key});

  @override
  State<MapSample> createState() => _MapSampleState();
}

class _MapSampleState extends State<MapSample> {
  final LatLng _initialCenter = LatLng(35.6892, 51.3890);
  double _initialZoom = 12;
  LatLng? _currentPosition;
  LatLng? _serverPosition;
  final MapController _mapController = MapController();

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("سرویس موقعیت مکانی غیرفعال است.")),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("مجوز دسترسی به موقعیت مکانی ندارید.")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("مجوز دسترسی به موقعیت مکانی به‌صورت دائم رد شده است.")),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _mapController.move(_currentPosition!, _initialZoom);
    });
  }

  Future<void> _sendLocationToServer() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ابتدا موقعیت خود را دریافت کنید.")),
      );
      return;
    }

    final url = Uri.parse('http://192.168.1.106/phpv/mylo.php');

    try {
      final response = await http.post(
        url,
        body: {
          'latitude': _currentPosition!.latitude.toString(),
          'longitude': _currentPosition!.longitude.toString(),
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ ارسال موفق: ${response.body}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("خطا در ارسال موقعیت.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("اتصال به سرور ممکن نیست.")),
      );
    }
  }

  Future<void> _fetchLocationFromServer() async {
    final url = Uri.parse('http://192.168.1.106/phpv/mylo.php'); // فرض بر اینکه آخرین مختصات رو برمی‌گردونه

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = response.body;

        // مثال داده دریافتی: "Latitude: 35.6, Longitude: 51.4"
        final regex = RegExp(r'Latitude:\s*([\d.-]+),\s*Longitude:\s*([\d.-]+)');
        final match = regex.firstMatch(data);

        if (match != null) {
          final lat = double.parse(match.group(1)!);
          final lng = double.parse(match.group(2)!);

          setState(() {
            _serverPosition = LatLng(lat, lng);
            _mapController.move(_serverPosition!, _initialZoom);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("موقعیت از سرور دریافت شد.")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("فرمت داده دریافتی نادرست است.")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("خطا در دریافت اطلاعات از سرور.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ارتباط با سرور برقرار نشد.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 80,
          height: 80,
          child: const Icon(Icons.place, color: Colors.red, size: 40),
        ),
      );
    }

    if (_serverPosition != null) {
      markers.add(
        Marker(
          point: _serverPosition!,
          width: 80,
          height: 80,
          child: const Icon(Icons.place, color: Colors.pink, size: 40),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("نمونه نقشه با flutter_map"),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? _initialCenter,
              initialZoom: _initialZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            bottom: 80,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _getCurrentLocation,
                      child: const Text("گرفتن موقعیت"),
                    ),
                    ElevatedButton(
                      onPressed: _sendLocationToServer,
                      child: const Text("ارسال به سرویس"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _fetchLocationFromServer,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                  child: const Text("دریافت از سرور"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
