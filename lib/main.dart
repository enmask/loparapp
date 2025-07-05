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
  static const double FIXED_REF_ALTITUDE = 38.0;

  final List<Position> routePositions;
  final Position? firstPosition;
  final Size canvasSize;


  RoutePainter({
    required this.routePositions,
    this.firstPosition,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('[RoutePainter - paint] paint-metoden anropad. Antal rutter: ${routePositions.length}. Canvas Size: ${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}}');

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
        final Offset firstOffset = _gpsToCanvas(firstPosition!, firstPosition!, canvasSize);
        print('[RoutePainter - paint] Ritar ensam prick vid: ${firstOffset.dx.toStringAsFixed(2)}, ${firstOffset.dy.toStringAsFixed(2)}');
        canvas.drawPoints(PointMode.points, [firstOffset], dotPaint);
      }
      return;
    }

    final Paint routeLinePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint altitudeLinePaint = Paint() // Färg för altitudstrecken
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final Paint altitudeProfilePaint = Paint() // <<< NYTT: Färg för altitudprofilens linje >>>
      ..color = Colors.purple // Välj en färg som passar
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path routePath = Path(); // Byt namn för tydlighet
    final Path altitudeProfilePath = Path(); // <<< NYTT: Sökväg för altitudprofilen >>>

    final double firstAltitude = firstPosition!.altitude; // Referensaltitud

    // Konvertera första GPS-punkten till canvas-koordinater
    final Offset startOffset = _gpsToCanvas(routePositions[0], firstPosition!, canvasSize);
    routePath.moveTo(startOffset.dx, startOffset.dy); // Starta ruttlinjen

    // Beräkna och flytta till första punkten för altitudprofilen
    final Offset firstAltitudeOffset = _getAltitudeCanvasOffset(routePositions[0], startOffset, /*firstAltitude*/ FIXED_REF_ALTITUDE);
    altitudeProfilePath.moveTo(firstAltitudeOffset.dx, firstAltitudeOffset.dy); // <<< NYTT: Starta altitudprofilens linje >>>

    // Rita första altitudstrecket
    _drawAltitudeLine(canvas, routePositions[0], startOffset, /*firstAltitude*/ FIXED_REF_ALTITUDE, altitudeLinePaint);

    for (int i = 1; i < routePositions.length; i++) {
      final Offset currentOffset = _gpsToCanvas(routePositions[i], firstPosition!, canvasSize);
      routePath.lineTo(currentOffset.dx, currentOffset.dy); // Fortsätt ruttlinjen

      // Beräkna och dra linje till nästa punkt för altitudprofilen
      final Offset currentAltitudeOffset = _getAltitudeCanvasOffset(routePositions[i], currentOffset, /*firstAltitude*/ FIXED_REF_ALTITUDE);
      altitudeProfilePath.lineTo(currentAltitudeOffset.dx, currentAltitudeOffset.dy); // <<< NYTT: Fortsätt altitudprofilens linje >>>

      // Rita altitudstreck för varje punkt
      _drawAltitudeLine(canvas, routePositions[i], currentOffset, /*firstAltitude*/ FIXED_REF_ALTITUDE, altitudeLinePaint);

      if (i % 5 == 0 || i == routePositions.length -1) {
        print('[RoutePainter - paint] Linje till punkt ${i}: ${currentOffset.dx.toStringAsFixed(2)}, ${currentOffset.dy.toStringAsFixed(2)}');
      }
    }

    canvas.drawPath(routePath, routeLinePaint); // Rita den blå ruttlinjen
    canvas.drawPath(altitudeProfilePath, altitudeProfilePaint); // <<< NYTT: Rita altitudprofilens linje >>>
  }

  // Ny metod för att beräkna altitudens offset på canvasen
  Offset _getAltitudeCanvasOffset(Position currentPosition, Offset canvasPoint, double firstAltitude) {
    const double altitudePixelScale = 5.5; // 0.5 pixlar per meter skillnad

    final double altitudeDifference = currentPosition.altitude - firstAltitude;
    final double verticalOffset = -altitudeDifference * altitudePixelScale; // Negativ för att högre altitud ska ritas högre upp (mindre y-värde)

    // Altitudprofilen ritas horisontellt parallellt med rutten, men med en vertikal offset
    // baserad på altituden. Vi lägger till en liten fast offset för att den inte ska krocka
    // med den blå ruttlinjen om altitudskillnaden är noll.
    const double baseVerticalOffset = /*-20.0*/ 1.0; // Flytta altitudlinjen 20 pixlar uppåt från ruttlinjen
    return Offset(canvasPoint.dx, canvasPoint.dy + baseVerticalOffset + verticalOffset);
  }

  // Befintlig metod för att rita ett altitudstreck
  void _drawAltitudeLine(Canvas canvas, Position currentPosition, Offset canvasPoint, double firstAltitude, Paint paint) {
    const double altitudePixelScale = 5.5; // 0.5 pixlar per meter skillnad

    final double altitudeDifference = currentPosition.altitude - firstAltitude;
    final double lineLength = altitudeDifference * altitudePixelScale;

    if (altitudeDifference > 0) {
      paint.color = Colors.red.withOpacity(0.7); // Uppåt (högre än start)
    } else if (altitudeDifference < 0) {
      paint.color = Colors.green.withOpacity(0.7); // Nedåt (lägre än start)
    } else {
      paint.color = Colors.grey.withOpacity(0.5); // Platt (samma som start)
    }

    canvas.drawLine(
      canvasPoint,
      Offset(canvasPoint.dx, canvasPoint.dy - lineLength), // 'minus lineLength' för att uppåt är mindre y-koordinat
      paint,
    );
  }


  Offset _gpsToCanvas(Position currentPosition, Position refPosition, Size canvasSize) {
    // With 800000, the full screen width of around 400 pixels corresponds to about a distance of 20m
    // With 40000, the full screen width of around 400 pixels corresponds to about a distance of 400m
    // With 4000, the full screen width of around 400 pixels corresponds to about a distance of 4km
    const double pixelsPerDegree = 20000.0; // Finjustera detta efter behov och test. Was: 800000.0

    final double deltaLongitude = currentPosition.longitude - refPosition.longitude;
    final double deltaLatitude = currentPosition.latitude - refPosition.latitude;

    final double x = deltaLongitude * pixelsPerDegree * math.cos(refPosition.latitude * math.pi / 180.0);
    final double y = -deltaLatitude * pixelsPerDegree;

    final double offsetX = canvasSize.width / 2;
    final double offsetY = canvasSize.height / 2;

    final double finalX = x + offsetX;
    final double finalY = y + offsetY;

    return Offset(finalX, finalY);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.routePositions.length != routePositions.length;
  }
}