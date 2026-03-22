import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Full-screen Leaflet.js map picker with search bar for Flutter Web.
///
/// • Google Hybrid/Roads/Satellite tiles — Google Maps quality, free
/// • Search bar — type any city, village, address → map jumps there
/// • Draggable pin — tap to drop, drag to fine-tune
/// • No API key needed for any feature
///
/// Returns LatLng on confirm, null on cancel.
class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const MapPickerScreen({super.key, this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _defaultCenter = LatLng(22.9734, 78.6569);
  static const _defaultZoom = 5;
  static const _streetZoom = 17;

  late LatLng _pin;
  late String _iframeId;
  bool _pinDropped = false;

  @override
  void initState() {
    super.initState();
    _pin = widget.initial ?? _defaultCenter;
    _pinDropped = widget.initial != null;
    _iframeId = 'leaflet-map-${DateTime.now().millisecondsSinceEpoch}';
    _registerIframe();
    _listenForPinUpdates();
  }

  void _registerIframe() {
    final iframe = html.IFrameElement()
      ..srcdoc = _buildLeafletHtml()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _iframeId,
      (int viewId) => iframe,
    );
  }

  void _listenForPinUpdates() {
    html.window.onMessage.listen((event) {
      try {
        final data = jsonDecode(event.data.toString());
        if (data['type'] == 'pin_moved') {
          setState(() {
            _pin = LatLng(
              (data['lat'] as num).toDouble(),
              (data['lng'] as num).toDouble(),
            );
            _pinDropped = true;
          });
        }
      } catch (_) {}
    });
  }

  void _confirm() => Navigator.pop(context, _pinDropped ? _pin : null);
  void _cancel() => Navigator.pop(context, null);

  // ── Leaflet HTML with search bar ───────────────────────────────────────────
  String _buildLeafletHtml() {
    final lat = _pin.latitude;
    final lng = _pin.longitude;
    final zoom = widget.initial != null ? _streetZoom : _defaultZoom;
    final pinOnLoad = widget.initial != null;

    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<!-- Leaflet core -->
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

<!-- Leaflet Geocoder (search bar) — uses Nominatim, no API key -->
<link rel="stylesheet" href="https://unpkg.com/leaflet-control-geocoder/dist/Control.Geocoder.css"/>
<script src="https://unpkg.com/leaflet-control-geocoder/dist/Control.Geocoder.js"></script>

<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html, body, #map { width:100%; height:100%; font-family: sans-serif; }

  /* Search bar styling */
  .leaflet-control-geocoder {
    border: none !important;
    border-radius: 12px !important;
    box-shadow: 0 2px 14px rgba(0,0,0,0.18) !important;
    min-width: 280px !important;
  }
  .leaflet-control-geocoder-form input {
    width: 100% !important;
    padding: 10px 14px !important;
    font-size: 13px !important;
    border: none !important;
    border-radius: 12px !important;
    outline: none !important;
    background: white !important;
    color: #222 !important;
  }
  .leaflet-control-geocoder-icon {
    border-radius: 12px !important;
    background-color: white !important;
    background-size: 18px !important;
    width: 42px !important;
    height: 42px !important;
    box-shadow: 0 2px 14px rgba(0,0,0,0.18) !important;
  }
  .leaflet-control-geocoder-alternatives {
    border-radius: 0 0 12px 12px !important;
    box-shadow: 0 4px 14px rgba(0,0,0,0.12) !important;
    border-top: 1px solid #eee !important;
  }
  .leaflet-control-geocoder-alternatives li a {
    font-size: 12px !important;
    padding: 8px 14px !important;
  }

  /* Zoom controls */
  .leaflet-control-zoom {
    border: none !important;
    box-shadow: 0 2px 10px rgba(0,0,0,0.15) !important;
    border-radius: 12px !important;
    overflow: hidden;
  }
  .leaflet-control-zoom a {
    width: 40px !important; height: 40px !important;
    line-height: 40px !important; font-size: 18px !important;
    color: #333 !important; font-weight: 300 !important;
  }
  .leaflet-control-zoom-in  { border-radius: 12px 12px 0 0 !important; }
  .leaflet-control-zoom-out { border-radius: 0 0 12px 12px !important; }

  .leaflet-control-attribution { font-size: 9px !important; }
</style>
</head>
<body>
<div id="map"></div>
<script>
  // ── Tile layers ────────────────────────────────────────────────────────────
  var googleHybrid = L.tileLayer(
    'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
    { maxZoom: 20, attribution: '© Google' }
  );
  var googleRoads = L.tileLayer(
    'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    { maxZoom: 20, attribution: '© Google' }
  );
  var googleSatellite = L.tileLayer(
    'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
    { maxZoom: 20, attribution: '© Google' }
  );
  var osm = L.tileLayer(
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    { maxZoom: 19, attribution: '© OpenStreetMap contributors' }
  );

  // ── Map init ───────────────────────────────────────────────────────────────
  var map = L.map('map', {
    center: [$lat, $lng],
    zoom: $zoom,
    zoomControl: true,
    layers: [googleHybrid],
  });

  // ── Layer switcher ─────────────────────────────────────────────────────────
  L.control.layers({
    '🛣 Roads':     googleRoads,
    '🛰 Hybrid':    googleHybrid,
    '🌍 Satellite': googleSatellite,
    '🗺 OSM':       osm,
  }, {}, { position: 'topright' }).addTo(map);

  // ── Search bar (Nominatim geocoder) ────────────────────────────────────────
  var geocoder = L.Control.geocoder({
    defaultMarkGeocode: false,       // we handle pin ourselves
    position: 'topleft',
    placeholder: 'Search city, area, address...',
    errorMessage: 'Nothing found.',
    geocoder: L.Control.Geocoder.nominatim({
      geocodingQueryParams: {
        countrycodes: 'in',          // bias results to India
        limit: 5,
      }
    }),
  })
  .on('markgeocode', function(e) {
    var center = e.geocode.center;
    map.setView(center, 17);
    dropPin(center.lat, center.lng);
  })
  .addTo(map);

  // ── Custom green pin icon ──────────────────────────────────────────────────
  var pinIcon = L.divIcon({
    className: '',
    html: \`<div style="
      display:flex; flex-direction:column; align-items:center;
      filter: drop-shadow(0 4px 8px rgba(0,0,0,0.35));
    ">
      <div style="
        width:38px; height:38px; border-radius:50%;
        background:#1B5E20; border:3px solid white;
        display:flex; align-items:center; justify-content:center;
      ">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="white">
          <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75
            7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5
            s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
        </svg>
      </div>
      <div style="width:3px;height:18px;background:#1B5E20;border-radius:2px;"></div>
      <div style="width:8px;height:8px;border-radius:50%;background:rgba(27,94,32,0.35);"></div>
    </div>\`,
    iconSize:   [42, 66],
    iconAnchor: [21, 66],
  });

  // ── Pin logic ──────────────────────────────────────────────────────────────
  var marker = null;

  function dropPin(lat, lng) {
    if (marker) { map.removeLayer(marker); }
    marker = L.marker([lat, lng], {
      icon: pinIcon,
      draggable: true,
    }).addTo(map);

    marker.on('dragend', function() {
      var pos = marker.getLatLng();
      sendPin(pos.lat, pos.lng);
    });

    sendPin(lat, lng);
  }

  function sendPin(lat, lng) {
    window.parent.postMessage(
      JSON.stringify({ type: 'pin_moved', lat: lat, lng: lng }), '*'
    );
  }

  // Drop pin on map click
  map.on('click', function(e) {
    dropPin(e.latlng.lat, e.latlng.lng);
  });

  // Pre-load pin if editing an existing address
  ${pinOnLoad ? 'dropPin($lat, $lng);' : ''}
</script>
</body>
</html>
''';
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 18,
          ),
          onPressed: _cancel,
        ),
        title: const Text(
          'Pin your location',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8E8E8)),
        ),
      ),
      body: Column(
        children: [
          // ── Leaflet map (takes all available space) ────────────────────────
          Expanded(child: HtmlElementView(viewType: _iframeId)),

          // ── Bottom sheet ───────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.09),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Coordinate row
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _pinDropped
                            ? const Color(0xFF1B5E20).withOpacity(0.10)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _pinDropped
                            ? Icons.location_on_rounded
                            : Icons.location_off_outlined,
                        color: _pinDropped
                            ? const Color(0xFF1B5E20)
                            : Colors.grey.shade400,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pinDropped
                                ? 'Selected location'
                                : 'No location selected',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pinDropped
                                ? '${_pin.latitude.toStringAsFixed(6)},  '
                                      '${_pin.longitude.toStringAsFixed(6)}'
                                : 'Search above or tap the map to pin',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _pinDropped
                                  ? Colors.black87
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_pinDropped)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _pinDropped ? _confirm : null,
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text(
                      'Confirm Location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      disabledForegroundColor: Colors.grey.shade400,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
