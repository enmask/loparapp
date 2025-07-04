import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui';

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
  // Ändra listtypen till Position istället för Offset
  /*final*/ List<Position> _routePositions = []; // Lista för att lagra råa GPS-positioner
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;

  // Lägg till en variabel för att lagra den första mottagna positionen.
  // Denna används som en referenspunkt för att rita.
  Position? _firstPosition;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  // Helper function för att visa SnackBar
  void _showSnackbar(String message) {
    if (mounted) { // Kontrollera att widgeten fortfarande är monterad innan SnackBar visas
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
      _routePositions.clear(); // Rensa gamla rutter
      _firstPosition = null; // Återställ första positionen vid ny spårning
    });

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // Fortsätt med 0 för felsökning för att få många punkter
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      print('[Geolocator Stream] Ny position mottagen: ${position.latitude}, ${position.longitude}, noggrannhet: ${position.accuracy}');

      setState(() {
        if (_firstPosition == null) {
          _firstPosition = position; // Sätt första positionen som referens
          print('[Geolocator Stream] Första referenspunkt satt: ${_firstPosition!.latitude}, ${_firstPosition!.longitude}');
        }
        _routePositions.add(position); // Lägg till den råa GPS-positionen
        // Bug fix, make sure that 
        _routePositions = List.from(_routePositions); // TODO: Should be able to remove this now...


        // Felsökningsutskrift för antal punkter
        ///if (_routePositions.length % 10 == 0) {
          print('[RoutePainter] Antal råa punkter: ${_routePositions.length}');
        ///}
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
    // Få skärmstorleken direkt från MediaQuery för att skicka till CustomPaint
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Min Löparapp'),
      ),

      body: SizedBox.expand( // <<< VIKTIG ÄNDRING HÄR >>>

      //body: Center(
        child: CustomPaint(
        //body: CustomPaint(

          // Skicka med råa positioner, den första positionen och skärmstorleken
          painter: RoutePainter(

            //routePositions: _routePositions,
            routePositions: List.of(_routePositions), // <-- TEST

            firstPosition: _firstPosition,
            canvasSize: screenSize,
          ),
          /*
          child: Container(
            color: Colors.white, // Ge CustomPaint en bakgrundsfärg för att synas
            //width: double.infinity, // Fyll hela bredden
            //height: double.infinity, // Fyll hela höjden
            width: 300.0, // <<< TEST: Ge den en fast bredd >>>
            height: 300.0, // <<< TEST: Ge den en fast höjd >>>

          ),
          */
        ),
        ),
      //),
      floatingActionButton: FloatingActionButton(
        onPressed: _isTracking ? _stopTracking : _startTracking,
        child: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}

// ---

class RoutePainter extends CustomPainter {
  final List<Position> routePositions; // Nu en lista av Position-objekt
  final Position? firstPosition; // Den första positionen för referens
  final Size canvasSize; // Skärmstorleken

  // Uppdatera konstruktorn
  RoutePainter({
    required this.routePositions,
    this.firstPosition, // firstPosition är valfri, men vi förväntar den
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {


  print('[RoutePainter - paint] paint-metoden anropad. Antal rutter: ${routePositions.length}, size: ${size}');

    final Paint testPaint = Paint() // <<< NY TEST-PAINT >>>
      ..color = Colors.red
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // <<< RITA EN STATISK LINJE I MITTEN AV SKÄRMEN >>>
    // Detta borde alltid synas om CustomPaint fungerar
    canvas.drawLine(Offset(size.width * 0.25 + 0.0, size.height * 0.25),
                    Offset(size.width * 0.75 + 0.0, size.height * 0.75 + 0.0),
                    testPaint);
    print('\n\n\n\n[RoutePainter - paint] Ritade statisk testlinje. size.width: ${size.width}');
    // <<< SLUT PÅ TESTLINJEN >>>





    // Behöver minst två positioner och en startposition för att rita en linje
    // och att första positionen inte är null
    if (routePositions.length < 2 || firstPosition == null) {
      if (routePositions.length == 1 && firstPosition != null) {
        // Om bara en punkt finns, rita den som en prick
        final Paint dotPaint = Paint()..color = Colors.green ..strokeWidth = 10.0 ..strokeCap = StrokeCap.round;
        print('paint will call _gpsToCanvas (only one dot)');
        final Offset firstOffset = _gpsToCanvas(firstPosition!, firstPosition!, canvasSize);
        print('back in paint after _gpsToCanvas call (only one dot)');

        // <<< LÄGG TILL LOGGNING FÖR PRICK >>>
        print('[RoutePainter - paint] Ritar ensam prick vid: ${firstOffset.dx.toStringAsFixed(2)}, ${firstOffset.dy.toStringAsFixed(2)}');
        // <<< SLUT PÅ LOGGNING >>>

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

    // Flytta till den första punkten i den faktiska rutten, omvandlad till skärmkoordinater
    print('paint will call _gpsToCanvas (first dot)');

    final Offset startOffset = _gpsToCanvas(routePositions[0], firstPosition!, canvasSize);
    print('back in paint after _gpsToCanvas call (first dot)');
    print('[paint] startOffset: ${startOffset}');
    path.moveTo(startOffset.dx, startOffset.dy);


    // <<< LÄGG TILL LOGGNING FÖR STARTPUNKT PÅ RUTTEN >>>
    print('[RoutePainter - paint] Path startad vid: ${startOffset.dx.toStringAsFixed(2)}, ${startOffset.dy.toStringAsFixed(2)}');
    // <<< SLUT PÅ LOGGNING >>>

    // Rita linjer mellan efterföljande punkter
    for (int i = 1; i < routePositions.length; i++) {
      print('paint will call _gpsToCanvas (next dot)');
      final Offset currentOffset = _gpsToCanvas(routePositions[i], firstPosition!, canvasSize);
      print('back in paint after _gpsToCanvas call (next dot)');
      print('[paint] currentOffset: ${currentOffset}');
      path.lineTo(currentOffset.dx, currentOffset.dy);

      // <<< LÄGG TILL LOGGNING FÖR VARJE LINJESEGMENT >>>
      if (i % 5 == 0 || i == routePositions.length -1) { // Logga inte varje punkt, blir för mycket. Var 5:e eller sista.
        print('[RoutePainter - paint] Linje till punkt ${i}: ${currentOffset.dx.toStringAsFixed(2)}, ${currentOffset.dy.toStringAsFixed(2)}');
      }
      // <<< SLUT PÅ LOGGNING >>>
    }

    print('[paint] path: ${path}');

    // <<< LÄGG TILL LOGGNING FÖR RITNING AV HELA RUTTEN >>>
    print('[RoutePainter - paint] Anropar canvas.drawPath för att rita rutten.');
    // <<< SLUT PÅ LOGGNING >>>

    canvas.drawPath(path, paint);
  }

  // Ny hjälpmetod för att omvandla GPS Position till Offset på Canvas
  Offset _gpsToCanvas(Position currentPosition, Position refPosition, Size canvasSize) {

    print('[_gpsToCanvas] currentPosition: ${currentPosition} (lat: ${currentPosition.latitude}, lon: ${currentPosition.longitude}, alt: ${currentPosition.altitude}, ), refPosition: ${refPosition}');

    // Denna faktor bestämmer hur "uppförstorad" din rutt blir.
    // Experimentera med detta värde. Ett större värde zoomar in mer.
    // Om 1 grad är 111 km, och vi vill att 1 meter (ca 0.000009 grader) ska synas:
    // 1 meter = 10 pixlar -> 10 pixlar / 0.000009 grader = ca 1,1 miljoner
    // En faktor på 500 000 till 1 000 000 är ofta bra för lokal rörelse.
    const double pixelsPerDegree = 400000.0; // Prova detta värde, justera vid behov. Was: 800000 (screen width around 50m)
                                           //                                       Then: 5000 (kantarellpromenad)

    // Beräkna skillnaden i longitud och latitud från referenspunkten
    final double deltaLongitude = currentPosition.longitude - refPosition.longitude;
    final double deltaLatitude = currentPosition.latitude - refPosition.latitude;

    // Omvandla delta till pixlar
    // Observera att longitud-skillnad behöver justeras för latitud (jordens krökning),
    // men för korta sträckor är detta förenklat OK.
    // Latitud ändras linjärt (1 grad latitud är ungefär samma sträcka överallt).
    final double x = deltaLongitude * pixelsPerDegree;
    final double y = -deltaLatitude * pixelsPerDegree; // Y-axel är inverterad i Flutter

    print('[_gpsToCanvas] x: ${x}, y: ${y}');

    // Addera en offset för att centrera den första punkten på canvasen
    final double offsetX = canvasSize.width / 2;
    final double offsetY = canvasSize.height / 2;

    print('[_gpsToCanvas] offsetX: ${offsetX}, offsetY: ${offsetY}');
    print('[_gpsToCanvas] x+offsetX: ${x+offsetX}, y+offsetY: ${y+offsetY}');

    final double finalX = x + offsetX; // De slutgiltiga X-koordinaterna
    final double finalY = y + offsetY; // De slutgiltiga Y-koordinaterna
    // <<< LÄGG TILL DESSA LOGGNINGAR >>>
    print('\n\n[RoutePainter - _gpsToCanvas] Input Lat/Lon: ${currentPosition.latitude}, ${currentPosition.longitude}');
    print('[RoutePainter - _gpsToCanvas] Delta X/Y (relativ): ${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}');
    print('[RoutePainter - _gpsToCanvas] Canvas Offset: ${offsetX.toStringAsFixed(2)}, ${offsetY.toStringAsFixed(2)}');
    print('[RoutePainter - _gpsToCanvas] Final Canvas Coords: ${finalX.toStringAsFixed(2)}, ${finalY.toStringAsFixed(2)}\n\n');
    // <<< SLUT PÅ LOGGNINGARNA >>>

    return Offset(x + offsetX, y + offsetY);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {

    /**/
    print("shouldRepaint called and will return ${oldDelegate.routePositions.length != routePositions.length} because oldDelegate.routePositions.length == ${oldDelegate.routePositions.length} and routePositions.length == ${routePositions.length}");

    // Repaint bara om listan med punkter har ändrats (dvs. nya punkter har lagts till)
    // TODO: Will maybe need more detailed analysis than just comparing list *length*
    return oldDelegate.routePositions.length != routePositions.length;
    /**/
    //return true;
  }
}