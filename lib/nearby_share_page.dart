import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import 'song_export.dart';
import 'app_strings.dart';
import 'nearby_service.dart';
import 'dev_log.dart';

/// Stránka pro odeslání písně nebo setlistu přes Nearby (offline P2P).
class NearbySharePage extends StatefulWidget {
  final AppDatabase db;
  // Pro jednu píseň
  final String? songTitle;
  final String? songArtist;
  final String? songContent;
  final double? tempo;
  final double? scrollSpeed;
  final double? fontSize;
  final double? introDuration;
  final int? duration;
  final int? transpose;
  final List<Map<String, dynamic>>? stopMarks;

  // Pro setlist
  final int? playlistId;
  final String? playlistName;
  final List<Map<String, dynamic>>? songs;
  final int? totalDuration;
  final int? unknownCount;

  const NearbySharePage({
    super.key,
    required this.db,
    this.songTitle,
    this.songArtist,
    this.songContent,
    this.tempo,
    this.scrollSpeed,
    this.fontSize,
    this.introDuration,
    this.duration,
    this.transpose,
    this.stopMarks,
    this.playlistId,
    this.playlistName,
    this.songs,
    this.totalDuration,
    this.unknownCount,
  });

  @override
  State<NearbySharePage> createState() => _NearbySharePageState();
}

class _NearbySharePageState extends State<NearbySharePage> {
  final FlutterTts _tts = FlutterTts();
  final NearbyService _nearby = NearbyService.instance;
  Map<String, String> _discovered = {};
  bool _searching = false;
  String _status = "";
  String? _sendingTo;
  bool _advertising = false;

  bool get _isSingleSong => widget.songTitle != null && widget.songContent != null;
  bool get _isPlaylist => widget.playlistId != null || widget.playlistName != null;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("cs-CZ");
    _tts.setSpeechRate(0.5);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tts.speak(AppStrings.nearbySearching);
      _startDiscovery();
      _startAdvertisingQuiet();
    });
  }

  Future<void> _startAdvertisingQuiet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('nearbyAutoReceive') ?? true;
      if (!enabled) return;
      final ok = await _nearby.startAdvertising();
      if (mounted) setState(() => _advertising = ok);
    } catch (_) {}
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _searching = true;
      _status = AppStrings.nearbySearching;
      _discovered.clear();
    });
    final ok = await _nearby.startDiscovery(
      onUpdated: (map) {
        if (!mounted) return;
        setState(() => _discovered = Map.from(map));
      },
      onStatus: (s) {
        if (!mounted) return;
        setState(() => _status = s);
      },
    );
    if (!ok && mounted) {
      setState(() {
        _status = AppStrings.nearbyUnavailable;
        _searching = false;
      });
      _tts.speak(AppStrings.nearbyUnavailable);
    } else if (mounted) {
      setState(() => _searching = true);
    }
  }

  Future<void> _stopDiscovery() async {
    await _nearby.stopDiscovery();
    if (mounted) setState(() => _searching = false);
  }

  Future<String> _buildJson() async {
    if (_isSingleSong) {
      return buildSongPackageJson(
        title: widget.songTitle!,
        artist: widget.songArtist ?? "Neznámý interpret",
        content: widget.songContent!,
        tempo: widget.tempo,
        scrollSpeed: widget.scrollSpeed,
        fontSize: widget.fontSize,
        introDuration: widget.introDuration,
        duration: widget.duration,
        transpose: widget.transpose,
        stopMarks: widget.stopMarks,
      );
    }
    // Playlist
    int? pid = widget.playlistId;
    String name = widget.playlistName ?? "Setlist";
    List<Map<String, dynamic>> songsPayload = widget.songs ?? [];
    int totalDuration = widget.totalDuration ?? 0;
    int unknown = widget.unknownCount ?? 0;

    if (pid != null) {
      // Získat fresh data z DB včetně obsahu pokud ještě není
      try {
        final exported = await widget.db.exportPlaylistToJson(pid, includeContents: true);
        return jsonEncode(exported);
      } catch (_) {}
    }
    // Fallback: sestavit z předaných songs (bez filePath, s obsahem pokud byl)
    if (songsPayload.isNotEmpty && songsPayload.first.containsKey('filePath')) {
      // doplnit content z filePath pokud chybí
      final withContent = <Map<String, dynamic>>[];
      for (final s in songsPayload) {
        final entry = Map<String, dynamic>.from(s);
        if (!entry.containsKey('content') || (entry['content'] as String?)?.isEmpty == true) {
          final path = entry['filePath'] as String?;
          if (path != null) {
            try {
              final file = File(path);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                String content;
                try { content = utf8.decode(bytes); } catch (_) { content = latin1.decode(bytes); }
                entry['content'] = content;
              }
            } catch (_) {}
          }
        }
        entry.remove('filePath');
        withContent.add(entry);
      }
      songsPayload = withContent;
    } else {
      songsPayload = songsPayload.map((e) { final m = Map<String, dynamic>.from(e); m.remove('filePath'); return m; }).toList();
    }
    return buildPlaylistPackageJson(name: name, songs: songsPayload, totalDuration: totalDuration, unknownCount: unknown);
  }

  Future<void> _sendTo(String endpointId, String endpointName) async {
    setState(() => _sendingTo = endpointId);
    _tts.speak(AppStrings.nearbySending);
    try {
      // Nejprve navázat spojení pokud ještě není
      await _nearby.requestConnection(endpointId);
      await Future.delayed(const Duration(milliseconds: 800));
      final jsonStr = await _buildJson();
      DevLog.log("Nearby sending json length ${jsonStr.length} to $endpointId $endpointName");
      final ok = await _nearby.sendJson(endpointId, jsonStr);
      if (!mounted) return;
      if (ok) {
        _tts.speak(AppStrings.nearbySent);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.nearbySent)));
      } else {
        _tts.speak(AppStrings.nearbySendError);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.nearbySendError)));
      }
    } catch (e) {
      DevLog.log("Nearby _sendTo error $e");
      if (mounted) {
        _tts.speak(AppStrings.nearbySendError);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Chyba: $e")));
      }
    } finally {
      if (mounted) setState(() => _sendingTo = null);
    }
  }

  @override
  void dispose() {
    _stopDiscovery();
    // Neukončovat advertising pokud byl auto – příjemce má zůstat viditelný
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSingleSong
        ? "Poslat píseň: ${widget.songTitle}"
        : "Poslat setlist: ${widget.playlistName ?? 'Setlist'}";
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.search_off : Icons.search),
            tooltip: _searching ? "Zastavit hledání" : "Hledat znovu",
            onPressed: () {
              if (_searching) _stopDiscovery();
              else _startDiscovery();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  Text(_status.isEmpty ? AppStrings.nearbySearching : _status, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(AppStrings.nearbyInstruction, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (_advertising) ...[
                    const SizedBox(height: 4),
                    Text("Jste viditelní pro ostatní", style: TextStyle(fontSize: 11, color: Colors.green[700])),
                  ],
                ],
              ),
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Expanded(
            child: _discovered.isEmpty
                ? Center(
                    child: Semantics(
                      liveRegion: true,
                      label: _searching ? AppStrings.nearbyNoDevices : AppStrings.nearbySearching,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sensors_off, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(_searching ? AppStrings.nearbyNoDevices : "Hledání zastaveno"),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: Text(_searching ? "Hledat znovu" : "Spustit hledání"),
                            onPressed: _startDiscovery,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _discovered.length,
                    itemBuilder: (context, i) {
                      final id = _discovered.keys.elementAt(i);
                      final name = _discovered[id]!;
                      final isSending = _sendingTo == id;
                      return Semantics(
                        label: "Zařízení $name, poklepáním odeslat ${_isSingleSong ? 'píseň' : 'setlist'}",
                        button: true,
                        child: ListTile(
                          leading: const Icon(Icons.phone_android),
                          title: Text(name),
                          subtitle: Text(isSending ? AppStrings.nearbySending : "Klepněte pro odeslání"),
                          trailing: isSending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send),
                          onTap: isSending ? null : () => _sendTo(id, name),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              liveRegion: true,
              child: Text(
                "Nalezeno ${_discovered.length} zařízení",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
