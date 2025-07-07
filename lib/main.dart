import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui'; // Behövs för PointMode.points
import 'dart:math' as math; // Behövs för math.cos och math.pi

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
  double _currentAltitude = 0.0;
  // Ny zoomfaktor
  double _zoomFactor = 1.0; // 1.0 är standardzoom

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
      _currentAltitude = 0.0;
      _zoomFactor = 1.0; // Återställ zoom vid ny spårning
    });

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // Ta emot alla uppdateringar
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

  // Ny metod för att zooma in
  void _zoomIn() {
    setState(() {
      _zoomFactor = (_zoomFactor * 1.2).clamp(0.01, 250.0); // Öka med 20%, begränsa mellan 0.5x och 5x. Was: (0.5, 5.0)
      print('[Zoom] Zoomar in. Ny zoomfaktor: $_zoomFactor');
    });
  }

  // Ny metod för att zooma ut
  void _zoomOut() {
    setState(() {
      _zoomFactor = (_zoomFactor / 1.2).clamp(0.01, 250.0); // Minska med 20%, begränsa mellan 0.5x och 5x
      print('[Zoom] Zoomar ut. Ny zoomfaktor: $_zoomFactor');
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Min Löparapp'),
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: CustomPaint(
              painter: RoutePainter(
                routePositions: List.of(_routePositions),
                firstPosition: _firstPosition,
                canvasSize: screenSize,
                zoomFactor: _zoomFactor, // Skicka med zoomfaktorn
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: Text(
                'Altitud: ${_currentAltitude.toStringAsFixed(1)} m',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
          // Flytande knappar för zoom
          Positioned(
            bottom: 100, // Justera position
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomInBtn", // Unikt heroTag för varje FAB
                  mini: true, // Gör knappen mindre
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8), // Mellanslag mellan knapparna
                FloatingActionButton(
                  heroTag: "zoomOutBtn", // Unikt heroTag
                  mini: true, // Gör knappen mindre
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
      // Befintlig FloatingActionButton för start/stopp
      floatingActionButton: FloatingActionButton(
        heroTag: "startStopBtn", // Unikt heroTag
        onPressed: _isTracking ? _stopTracking : _startTracking,
        child: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // Standardposition längst ner till höger
    );
  }
}

// ---

class RoutePainter extends CustomPainter {
  final List<Position> routePositions;
  final Position? firstPosition;
  final Size canvasSize;
  final double zoomFactor; // Ny parameter för zoomfaktor

  RoutePainter({
    required this.routePositions,
    this.firstPosition,
    required this.canvasSize,
    required this.zoomFactor, // Måste inkluderas i konstruktorn
  });

  // Lägg till din konstanta här i klassen
  static const double FIXED_REF_ALTITUDE = 100.0; // Exempelvärde

  @override
  void paint(Canvas canvas, Size size) {
    print('[RoutePainter - paint] paint-metoden anropad. Antal rutter: ${routePositions.length}. Canvas Size: ${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}}');
    print('[RoutePainter - paint] Aktuell Zoom Faktor: ${zoomFactor.toStringAsFixed(2)}');


    // TESTLINJE: Kan tas bort när allt fungerar som det ska.
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
        // Skicka med zoomFactor till _gpsToCanvas
        final Offset firstOffset = _gpsToCanvas(firstPosition!, firstPosition!, canvasSize, zoomFactor);
        print('[RoutePainter - paint] Ritar ensam prick vid: ${firstOffset.dx.toStringAsFixed(2)}, ${firstOffset.dy.toStringAsFixed(2)}');
        canvas.drawPoints(PointMode.points, [firstOffset], dotPaint);
      }
      return;
    }

    final Paint routeLinePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint altitudeLinePaint = Paint() // Färg för altitudstrecken
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Paint altitudeProfilePaint = Paint() // Färg för altitudprofilens linje
      ..color = Colors.purple
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path routePath = Path();
    final Path altitudeProfilePath = Path();

    // Använd den fasta referensaltituden
    final double referenceAltitude = FIXED_REF_ALTITUDE;

    // Konvertera första GPS-punkten till canvas-koordinater
    final Offset startOffset = _gpsToCanvas(routePositions[0], firstPosition!, canvasSize, zoomFactor); // Skicka med zoomFactor
    routePath.moveTo(startOffset.dx, startOffset.dy); // Starta ruttlinjen

    // Beräkna och flytta till första punkten för altitudprofilen
    final Offset firstAltitudeOffset = _getAltitudeCanvasOffset(routePositions[0], startOffset, referenceAltitude);
    altitudeProfilePath.moveTo(firstAltitudeOffset.dx, firstAltitudeOffset.dy); // Starta altitudprofilens linje

    _drawAltitudeLine(canvas, routePositions[0], startOffset, referenceAltitude, altitudeLinePaint);

    for (int i = 1; i < routePositions.length; i++) {
      final Offset currentOffset = _gpsToCanvas(routePositions[i], firstPosition!, canvasSize, zoomFactor); // Skicka med zoomFactor
      routePath.lineTo(currentOffset.dx, currentOffset.dy); // Fortsätt ruttlinjen

      // Beräkna och dra linje till nästa punkt för altitudprofilen
      final Offset currentAltitudeOffset = _getAltitudeCanvasOffset(routePositions[i], currentOffset, referenceAltitude);
      altitudeProfilePath.lineTo(currentAltitudeOffset.dx, currentAltitudeOffset.dy); // Fortsätt altitudprofilens linje

      _drawAltitudeLine(canvas, routePositions[i], currentOffset, referenceAltitude, altitudeLinePaint);

      if (i % 5 == 0 || i == routePositions.length -1) {
        print('[RoutePainter - paint] Linje till punkt ${i}: ${currentOffset.dx.toStringAsFixed(2)}, ${currentOffset.dy.toStringAsFixed(2)}');
      }
    }

    canvas.drawPath(routePath, routeLinePaint); // Rita den blå ruttlinjen
    canvas.drawPath(altitudeProfilePath, altitudeProfilePaint); // Rita altitudprofilens linje
  }

  // Ingen ändring här då den endast hanterar altitud och inte kart-zoom
  Offset _getAltitudeCanvasOffset(Position currentPosition, Offset canvasPoint, double referenceAltitude) {
    const double altitudePixelScale = 0.5;
    final double altitudeDifference = currentPosition.altitude - referenceAltitude;
    final double verticalOffset = -altitudeDifference * altitudePixelScale;
    const double baseVerticalOffset = 0.0; // Was -20.0
    return Offset(canvasPoint.dx, canvasPoint.dy + baseVerticalOffset + verticalOffset);
  }

  // Befintlig metod för att rita ett altitudstreck
  void _drawAltitudeLine(Canvas canvas, Position currentPosition, Offset canvasPoint, double referenceAltitude, Paint paint) {
    const double altitudePixelScale = 0.5;

    final double altitudeDifference = currentPosition.altitude - referenceAltitude;
    final double lineLength = altitudeDifference * altitudePixelScale;

    if (altitudeDifference > 0) {
      paint.color = Colors.red.withOpacity(0.7);
    } else if (altitudeDifference < 0) {
      paint.color = Colors.green.withOpacity(0.7);
    } else {
      paint.color = Colors.grey.withOpacity(0.5);
    }

    canvas.drawLine(
      canvasPoint,
      Offset(canvasPoint.dx, canvasPoint.dy - lineLength),
      paint,
    );
  }

  // Ändrad: tar nu emot zoomFactor
  Offset _gpsToCanvas(Position currentPosition, Position refPosition, Size canvasSize, double zoomFactor) {
    // Justera denna konstant för att skala rutten.
    // Mindre värde = mer zoomat in, större rörelse på skärmen
    // Större värde = mer zoomat ut, mindre rörelse på skärmen
    // Multiplicera med zoomFactor för att kontrollera skalan
    const double basePixelsPerDegree = 800000.0;
    final double effectivePixelsPerDegree = basePixelsPerDegree * zoomFactor; // Använd zoomfaktorn här

    final double deltaLongitude = currentPosition.longitude - refPosition.longitude;
    final double deltaLatitude = currentPosition.latitude - refPosition.latitude;

    final double x = deltaLongitude * effectivePixelsPerDegree * math.cos(refPosition.latitude * math.pi / 180.0);
    final double y = -deltaLatitude * effectivePixelsPerDegree;

    final double offsetX = canvasSize.width / 2;
    final double offsetY = canvasSize.height / 2;

    final double finalX = x + offsetX;
    final double finalY = y + offsetY;

    return Offset(finalX, finalY);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    // Nu måste vi även rita om om zoomfaktorn ändras
    return oldDelegate.routePositions.length != routePositions.length ||
           oldDelegate.zoomFactor != zoomFactor;
  }
}