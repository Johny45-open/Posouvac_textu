import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database.dart';
import 'song_import_service.dart';
import 'dev_log.dart';

// Conditional import – if nearby_connections not available, fallback to no-op
// ignore: uri_does_not_exist
import 'package:nearby_connections/nearby_connections.dart' as nearby;

/// Služba pro Nearby P2P přenos bez internetu.
class NearbyService {
  static final NearbyService instance = NearbyService._();
  NearbyService._();

  final FlutterTts _tts = FlutterTts();
  AppDatabase? _db;
  GlobalKey<NavigatorState>? _navKey;
  String _serviceId = "posouvac_textu_service";
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  final Map<String, String> _discovered = {}; // endpointId -> name
  Function(Map<String, String>)? _onDiscoveredUpdated;
  Function(String status)? _onStatus;

  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  Map<String, String> get discovered => Map.unmodifiable(_discovered);

  void init({required AppDatabase db, required GlobalKey<NavigatorState> navKey}) {
    _db = db;
    _navKey = navKey;
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);
    // Auto-start advertising pokud povoleno a na Android/iOS
    _maybeAutoAdvertise();
  }

  Future<void> _maybeAutoAdvertise() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('nearbyAutoReceive') ?? true;
      if (!enabled) return;
      if (!Platform.isAndroid && !Platform.isIOS) return;
      // Neauto-start ihned – až když je app v popředí, začneme v LibraryPage
    } catch (_) {}
  }

  Future<bool> ensurePermissions() async {
    if (!Platform.isAndroid) return true;
    // Android 12+ needs BLUETOOTH_SCAN/ADVERTISE/CONNECT, 13+ NEARBY_WIFI_DEVICES
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();
    final allGranted = statuses.values.every((s) => s == PermissionStatus.granted || s == PermissionStatus.limited);
    // Pokud location není udělen na Android 13+, nearby může stále fungovat s WIFI_DEVICES
    // Takže povolíme i když location denied na novějších
    if (!allGranted) {
      DevLog.log("Nearby permissions not all granted: $statuses");
    }
    return true; // zkusíme i tak
  }

  Future<bool> startAdvertising({String? userName}) async {
    if (_isAdvertising) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final ok = await ensurePermissions();
      if (!ok) return false;
      final prefs = await SharedPreferences.getInstance();
      final deviceName = userName ?? prefs.getString('nearbyDeviceName') ?? "Posouvac-${Platform.operatingSystem}";
      _isAdvertising = true;
      _onStatus?.call("Inzeruji jako $deviceName");
      // ignore: avoid_dynamic_calls
      await nearby.Nearby().startAdvertising(
        deviceName,
        nearby.Strategy.P2P_STAR,
        onConnectionInitiated: (id, info) {
          DevLog.log("Nearby onConnectionInitiated $id ${info.endpointName}");
          _tts.speak("Zařízení ${info.endpointName} se připojuje");
          // Auto-accept pro přístupnost
          try {
            nearby.Nearby().acceptConnection(
              id,
              onPayLoadRecieved: (endpointId, payload) async {
                await _handlePayload(endpointId, payload);
              },
              onPayloadTransferUpdate: (endpointId, update) {
                DevLog.log("Nearby transfer update $endpointId ${update.status} ${update.bytesTransferred}/${update.totalBytes}");
              },
            );
          } catch (e) {
            DevLog.log("Nearby acceptConnection error $e");
          }
        },
        onConnectionResult: (id, status) {
          DevLog.log("Nearby onConnectionResult $id $status");
          _onStatus?.call(status == nearby.Status.CONNECTED ? "Připojeno $id" : "Spojení $status");
          if (status == nearby.Status.CONNECTED) {
            _tts.speak("Připojeno");
          }
        },
        onDisconnected: (id) {
          DevLog.log("Nearby disconnected $id");
        },
        serviceId: _serviceId,
      );
      return true;
    } catch (e) {
      DevLog.log("Nearby startAdvertising error $e");
      _isAdvertising = false;
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    try {
      await nearby.Nearby().stopAdvertising();
    } catch (_) {}
    _isAdvertising = false;
  }

  Future<bool> startDiscovery({Function(Map<String, String>)? onUpdated, Function(String)? onStatus}) async {
    if (_isDiscovering) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    _onDiscoveredUpdated = onUpdated;
    _onStatus = onStatus;
    _discovered.clear();
    try {
      await ensurePermissions();
      _isDiscovering = true;
      _onStatus?.call("Hledám zařízení...");
      await nearby.Nearby().startDiscovery(
        "Posouvac",
        nearby.Strategy.P2P_STAR,
        onEndpointFound: (id, name, serviceId) {
          DevLog.log("Nearby found $id $name");
          _discovered[id] = name;
          _onDiscoveredUpdated?.call(Map.from(_discovered));
          _tts.speak("Nalezeno ${name}");
        },
        onEndpointLost: (id) {
          _discovered.remove(id);
          _onDiscoveredUpdated?.call(Map.from(_discovered));
        },
        serviceId: _serviceId,
      );
      return true;
    } catch (e) {
      DevLog.log("Nearby startDiscovery error $e");
      _isDiscovering = false;
      return false;
    }
  }

  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    try {
      await nearby.Nearby().stopDiscovery();
    } catch (_) {}
    _isDiscovering = false;
  }

  Future<void> stopAll() async {
    await stopAdvertising();
    await stopDiscovery();
    try {
      await nearby.Nearby().stopAllEndpoints();
    } catch (_) {}
  }

  Future<void> requestConnection(String endpointId) async {
    try {
      await nearby.Nearby().requestConnection(
        "Posouvac",
        endpointId,
        onConnectionInitiated: (id, info) {
          DevLog.log("Nearby request onConnectionInitiated $id");
          nearby.Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (eid, payload) async => _handlePayload(eid, payload),
            onPayloadTransferUpdate: (eid, update) {},
          );
        },
        onConnectionResult: (id, status) {
          DevLog.log("Nearby request result $id $status");
        },
        onDisconnected: (id) {},
      );
    } catch (e) {
      DevLog.log("Nearby requestConnection error $e");
    }
  }

  Future<bool> sendJson(String endpointId, String jsonStr) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      // Nearby bytes limit ~32KB – pokud větší, pošleme jako file
      if (bytes.length < 30000) {
        await nearby.Nearby().sendBytesPayload(endpointId, bytes);
        DevLog.log("Nearby sendBytes ${bytes.length} to $endpointId");
        return true;
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/nearby_payload_${DateTime.now().millisecondsSinceEpoch}.json');
        await file.writeAsString(jsonStr, encoding: utf8);
        final payloadId = await nearby.Nearby().sendFilePayload(endpointId, file.path);
        DevLog.log("Nearby sendFile $payloadId to $endpointId ${bytes.length} bytes");
        return true;
      }
    } catch (e) {
      DevLog.log("Nearby sendJson error $e");
      return false;
    }
  }

  Future<void> _handlePayload(String endpointId, dynamic payload) async {
    try {
      DevLog.log("Nearby payload from $endpointId type ${payload.runtimeType}");
      // payload can be Payload with type BYTES or FILE
      // nearby_connections payload has .type, .bytes, .uri
      String jsonStr = "";
      // Try bytes
      try {
        final type = payload.type;
        if (type == nearby.PayloadType.BYTES) {
          final bytes = payload.bytes as Uint8List?;
          if (bytes != null) jsonStr = utf8.decode(bytes);
        } else if (type == nearby.PayloadType.FILE) {
          final uri = payload.uri as String?;
          if (uri != null) {
            final file = File(uri);
            if (await file.exists()) {
              jsonStr = await file.readAsString(encoding: utf8);
            } else {
              // někdy uri je content:// – zkusit payload.filePath
              final alt = payload.toString();
              DevLog.log("Nearby file payload uri not found $uri alt $alt");
            }
          }
        }
      } catch (e) {
        // Fallback: payload is Uint8List directly
        if (payload is Uint8List) {
          jsonStr = utf8.decode(payload);
        } else if (payload is String) {
          jsonStr = payload;
        } else {
          DevLog.log("Nearby payload parse error $e payload=$payload");
        }
      }
      if (jsonStr.trim().isEmpty) {
        DevLog.log("Nearby empty payload from $endpointId");
        return;
      }
      final db = _db;
      final nav = _navKey;
      if (db == null || nav == null) return;
      await SongImportService.handleRawJson(jsonStr, db, nav);
    } catch (e) {
      DevLog.log("Nearby _handlePayload error $e");
    }
  }

  void setStatusCallback(Function(String)? cb) => _onStatus = cb;
}
