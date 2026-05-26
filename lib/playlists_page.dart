import 'package:flutter/material.dart';
import 'database.dart';
import 'app_progress_indicator.dart';

class PlaylistsPage extends StatefulWidget {
  final AppDatabase db;
  const PlaylistsPage({super.key, required this.db});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nový playlist"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Název")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zrušit")),
          TextButton(
            onPressed: () {
              widget.db.createPlaylist(controller.text);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Vytvořit"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Playlisty")),
      body: FutureBuilder<List<Playlist>>(
        future: widget.db.getAllPlaylists(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();

          final playlists = snapshot.data!;
          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, i) => Semantics(
              label: "Playlist ${playlists[i].name}",
              button: true,
              child: ListTile(title: Text(playlists[i].name)),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPlaylist,
        tooltip: "Vytvořit nový playlist",
        child: const Icon(Icons.add),
      ),
    );
  }
}
