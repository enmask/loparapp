import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui'; // Behövs för PointMode.points

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Löparapp',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RunTrackerScreen(),
    );
  }
}

class RunTrackerScreen extends StatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen> {
  final List<Position> _routePositions = [];
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  Position? _firstPosition;
  // Lägg till en variabel för aktuell altitud
  double _currentAltitude = 0.0; // Standardvärde innan första positionen

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('[_checkLocationPermission] Platstjänster är inte aktiverade på enheten.');
      _showSnackbar('Platstjänster är inte aktiverade.');
      return;
    }
    print('[_checkLocationPermission] Platstjänster är aktiverade.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      print('[_checkLocationPermission] Platsbehörighet nekad. Begär behörighet...');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('[_checkLocationPermission] Platsbehörighet nekad igen efter begäran.');
        _showSnackbar('Platsbehörighet nekad.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('[_checkLocationPermission] Platsbehörighet permanent nekad.');
      _showSnackbar('Platsbehörighet nekad permanent, aktivera manuellt i inställningar.');
      return;
    }
    print('[_checkLocationPermission] Platsbehörighet beviljad.');
  }

  void _startTracking() {
    print('[_startTracking] Metod anropad.');

    setState(() {
      _isTracking = true;
      _routePositions.clear();
      _firstPosition = null;
      _currentAltitude = 0.0; // Återställ altitud vid start
    });

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 0: Received all updates. Was: 5
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      print('[Geolocator Stream] Ny position mottagen: ${position.latitude}, ${position.longitude}, noggrannhet: ${position.accuracy}, altitud: ${position.altitude}');

      setState(() {
        if (_firstPosition == null) {
          _firstPosition = position;
          print('[Geolocator Stream] Första referenspunkt satt: ${_firstPosition!.latitude}, ${_firstPosition!.longitude}');
        }
        _routePositions.add(position);
        // Uppdatera aktuell altitud med 1 decimal
        _currentAltitude = double.parse(position.altitude.toStringAsFixed(1));

        if (_routePositions.length % 10 == 0) {
          print('[RoutePainter] Antal råa punkter: ${_routePositions.length}');
        }
      });
    });
    print('[_startTracking] Lyssnar på positioner...');
    _showSnackbar('Spårning startad!');
  }

  void _stopTracking() {
    print('[_stopTracking] Metod anropad.');
    setState(() {
      _isTracking = false;
    });
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _showSnackbar('Spårning stoppad!');
    print('[_stopTracking] Spårning stoppad.');
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // VIKTIGT: Fånga in screen size här för att få rätt dimensioner
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Min Löparapp'),
      ),
      // Använd Stack för att lägga text ovanpå CustomPaint
      body: Stack(
        children: [
          SizedBox.expand( // Tvingar CustomPaint att expandera till hela tillgängliga ytan
            child: CustomPaint(
              painter: RoutePainter(
                routePositions: List.of(_routePositions),
                firstPosition: _firstPosition,
                canvasSize: screenSize,
              ),
            ),
          ),
          // Lägg till Text-widgeten för altituden
          Positioned(
            top: 10, // Justera positionen som du vill
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black54, // Bakgrund för läsbarhet
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: Text(
                'Altitud: ${_currentAltitude.toStringAsFixed(1)} m', // Visa med 1 decimal
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isTracking ? _stopTracking : _startTracking,
        child: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}

// ---

class RoutePainter extends CustomPainter {
  final List<Position> routePositions;
  final Position? firstPosition;
  final Size canvasSize; // Denna används nu korrekt tack vare SizedBox.expand

  RoutePainter({
    required this.routePositions,
    this.firstPosition,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('[RoutePainter - paint] paint-metoden anropad. Antal rutter: ${routePositions.length}. Canvas Size: ${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}');

    // TESTLINJE: Om du vill ta bort den röda testlinjen nu när allt fungerar,
    // kommentera bort eller ta bort följande rader.
    final Paint testPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(size.width * 0.25, size.height * 0.25),
                    Offset(size.width * 0.75, size.height * 0.75),
                    testPaint);
    print('[RoutePainter - paint] Ritade statisk testlinje.');
    // SLUT PÅ TESTLINJE


    if (routePositions.length < 2 || firstPosition == null) {
      if (routePositions.length == 1 && firstPosition != null) {
        final Paint dotPaint = Paint()..color = Colors.red ..strokeWidth = 10.0 ..strokeCap = StrokeCap.round;
        final Offset firstOffset = _gpsToCanvas(firstPosition!, firstPosition!, canvasSize);

        print('[RoutePainter - paint] Ritar ensam prick vid: ${firstOffset.dx.toStringAsFixed(2)}, ${firstOffset.dy.toStringAsFixed(2)}');
        canvas.drawPoints(PointMode.points, [firstOffset], dotPaint);
      }
      return;
    }

    final Paint paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();

    final Offset startOffset = _gpsToCanvas(routePositions[0], firstPosition!, canvasSize);
    path.moveTo(startOffset.dx, startOffset.dy);

    print('[RoutePainter - paint] Path startad vid: ${startOffset.dx.toStringAsFixed(2)}, ${startOffset.dy.toStringAsFixed(2)}');

    for (int i = 1; i < routePositions.length; i++) {
      final Offset currentOffset = _gpsToCanvas(routePositions[i], firstPosition!, canvasSize);
      path.lineTo(currentOffset.dx, currentOffset.dy);
      // Logga inte varje punkt, blir för mycket. Var 5:e eller sista.
      if (i % 5 == 0 || i == routePositions.length -1) {
        print('[RoutePainter - paint] Linje till punkt ${i}: ${currentOffset.dx.toStringAsFixed(2)}, ${currentOffset.dy.toStringAsFixed(2)}');
      }
    }

    print('[RoutePainter - paint] Anropar canvas.drawPath för att rita rutten.');
    canvas.drawPath(path, paint);
  }

  Offset _gpsToCanvas(Position currentPosition, Position refPosition, Size canvasSize) {
    // Justera denna konstant för att skala rutten.
    // Mindre värde = mer zoomat in, större rörelse på skärmen
    // Större värde = mer zoomat ut, mindre rörelse på skärmen
    const double pixelsPerDegree = 800000.0; // Finjustera detta efter behov och test

    final double deltaLongitude = currentPosition.longitude - refPosition.longitude;
    final double deltaLatitude = currentPosition.latitude - refPosition.latitude;

    // Här har vi ändrat ordningen på y-axeln så att positiva latitud-förändringar
    // (norrut) ritas uppåt på skärmen (mindre y-värde).
    // Multiplikation med cosinus för att kompensera för longituders konvergens vid polerna.
    // Denna är inte helt exakt för mycket stora avstånd men fungerar bra lokalt.
    final double x = deltaLongitude * pixelsPerDegree * math.cos(refPosition.latitude * math.pi / 180.0);
    final double y = -deltaLatitude * pixelsPerDegree; // Negativ för att y-axeln går nedåt i Flutter

    final double offsetX = canvasSize.width / 2;
    final double offsetY = canvasSize.height / 2;

    final double finalX = x + offsetX;
    final double finalY = y + offsetY;

    print('[RoutePainter - _gpsToCanvas] Input Lat/Lon: ${currentPosition.latitude.toStringAsFixed(6)}, ${currentPosition.longitude.toStringAsFixed(6)}');
    print('[RoutePainter - _gpsToCanvas] Delta X/Y (relativ): ${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}');
    print('[RoutePainter - _gpsToCanvas] Canvas Offset: ${offsetX.toStringAsFixed(2)}, ${offsetY.toStringAsFixed(2)}');
    print('[RoutePainter - _gpsToCanvas] Final Canvas Coords: ${finalX.toStringAsFixed(2)}, ${finalY.toStringAsFixed(2)}');

    return Offset(finalX, finalY);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    // Logga för att se vad som händer
    print('shouldRepaint called and will return ${oldDelegate.routePositions.length != routePositions.length} because oldDelegate.routePositions.length == ${oldDelegate.routePositions.length} and routePositions.length == ${routePositions.length}');
    return oldDelegate.routePositions.length != routePositions.length;
  }
}