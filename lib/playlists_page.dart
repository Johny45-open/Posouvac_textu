import 'package:flutter/material.dart';
import 'database.dart';
import 'player_page.dart';

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
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await widget.db.createPlaylist(controller.text);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              }
            },
            child: const Text("Vytvořit"),
          ),
        ],
      ),
    );
  }

  Future<void> _managePlaylist(Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Spravovat playlist"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Název")),
        actions: [
          TextButton(
            onPressed: () async {
              await widget.db.deletePlaylist(playlist.id);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text("Smazat", style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zavřít")),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await widget.db.renamePlaylist(playlist.id, controller.text);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              }
            },
            child: const Text("Přejmenovat"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Moje playlisty")),
      body: FutureBuilder<List<Playlist>>(
        future: widget.db.getAllPlaylists(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();

          final playlists = snapshot.data!;
          if (playlists.isEmpty) {
            return const Center(child: Text("Zatím nemáte žádné playlisty."));
          }

          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, i) {
              final pl = playlists[i];
              return ListTile(
                leading: const Icon(Icons.playlist_play),
                title: Text(pl.name),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlaylistSongsPage(playlist: pl, db: widget.db)),
                ),
                onLongPress: () => _managePlaylist(pl),
              );
            },
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

class PlaylistSongsPage extends StatelessWidget {
  final Playlist playlist;
  final AppDatabase db;

  const PlaylistSongsPage({super.key, required this.playlist, required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Playlist: ${playlist.name}")),
      body: StreamBuilder<List<SongEntry>>(
        stream: db.watchSongsInPlaylist(playlist.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final songs = snapshot.data!;

          if (songs.isEmpty) {
            return const Center(child: Text("V tomto playlistu nejsou žádné písně."));
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final song = songs[i];
              return ListTile(
                title: Text(song.artist),
                subtitle: Text(song.title),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => db.removeSongFromPlaylist(playlist.id, song.id),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlayerPage(songId: song.id, db: db)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
