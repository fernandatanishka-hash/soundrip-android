import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  runApp(const SoundRipApp());
}

class SoundRipApp extends StatelessWidget {
  const SoundRipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundRip Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0D11),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F076),
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFF14171F),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  bool _isAudio = true;
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = "Ready. Paste a link to begin.";
  String _videoTitle = "No video loaded";
  String _savedFilePath = "";

  // Quality settings
  String _selectedAudioQuality = "320 kbps (HQ)";
  String _selectedVideoQuality = "720p (HD)";

  final List<String> _audioQualities = ["320 kbps (HQ)", "192 kbps (Standard)", "128 kbps (Fast)"];
  final List<String> _videoQualities = ["1080p (Full HD)", "720p (HD)", "480p", "360p"];

  Future<void> _pasteFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _urlController.text = data!.text!.trim();
      });
      _fetchVideoInfo();
    }
  }

  Future<void> _fetchVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    try {
      setState(() => _statusText = "Fetching stream details...");
      var video = await _yt.videos.get(url);
      setState(() {
        _videoTitle = video.title;
        _statusText = "Channel: ${video.author} • ${video.duration?.inMinutes ?? 0} mins";
      });
    } catch (_) {
      setState(() => _statusText = "Ready to download");
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    // Attempt standard Android public Downloads folder
    List<String> paths = [
      '/storage/emulated/0/Download',
      '/sdcard/Download',
      '/storage/emulated/0/Music',
    ];

    for (String p in paths) {
      Directory d = Directory(p);
      if (await d.exists()) {
        return d;
      }
    }

    // Fallback: create Download directory
    Directory fallback = Directory('/storage/emulated/0/Download');
    try {
      await fallback.create(recursive: true);
      return fallback;
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid YouTube link")),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = "Connecting to high-speed stream...";
      _savedFilePath = "";
    });

    try {
      var video = await _yt.videos.get(url);
      var manifest = await _yt.videos.streamsClient.getManifest(url);

      StreamInfo streamInfo;
      String extension;

      if (_isAudio) {
        streamInfo = manifest.audioOnly.withHighestBitrate();
        extension = "mp3";
      } else {
        streamInfo = manifest.muxed.withHighestBitrate();
        extension = "mp4";
      }

      var stream = _yt.videos.streamsClient.get(streamInfo);
      Directory saveDir = await _getDownloadDirectory();

      String cleanTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      if (cleanTitle.length > 50) {
        cleanTitle = cleanTitle.substring(0, 50);
      }

      var file = File('${saveDir.path}/$cleanTitle.$extension');
      var fileStream = file.openWrite();

      int totalBytes = streamInfo.size.totalBytes;
      int receivedBytes = 0;

      await for (var chunk in stream) {
        fileStream.add(chunk);
        receivedBytes += chunk.length;
        setState(() {
          _progress = receivedBytes / totalBytes;
          _statusText = "Downloading: ${(_progress * 100).toStringAsFixed(1)}%";
        });
      }

      await fileStream.flush();
      await fileStream.close();

      setState(() {
        _isDownloading = false;
        _savedFilePath = file.path;
        _statusText = "Saved to: ${file.path}";
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00F076),
            duration: const Duration(seconds: 4),
            content: Text(
              "Saved to Downloads:\n$cleanTitle.$extension", 
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusText = "Error: $e";
      });
    }
  }

  @override
  void dispose() {
    _yt.close();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ SOUNDRIP STUDIO', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00F076))),
        backgroundColor: const Color(0xFF14171F),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // URL Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF14171F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF282F3E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SOURCE URL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            hintText: "Paste YouTube link here...",
                            filled: true,
                            fillColor: Color(0xFF1D222D),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) => _fetchVideoInfo(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _pasteFromClipboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A3345),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Paste"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metadata Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10131A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E2433)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_videoTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(_statusText, style: const TextStyle(fontSize: 11, color: Color(0xFF00F076))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Format Switcher (MP3 vs MP4)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.music_note),
                    label: const Text("🎵 MP3 Audio"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAudio ? const Color(0xFF00F076) : const Color(0xFF1D222D),
                      foregroundColor: _isAudio ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => setState(() => _isAudio = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.videocam),
                    label: const Text("🎬 MP4 Video"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isAudio ? const Color(0xFF3B82F6) : const Color(0xFF1D222D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => setState(() => _isAudio = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quality Dropdown Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF14171F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF282F3E)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isAudio ? "Audio Bitrate:" : "Video Quality:", 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)
                  ),
                  DropdownButton<String>(
                    value: _isAudio ? _selectedAudioQuality : _selectedVideoQuality,
                    dropdownColor: const Color(0xFF1D222D),
                    underline: const SizedBox(),
                    items: (_isAudio ? _audioQualities : _videoQualities).map((String q) {
                      return DropdownMenuItem<String>(
                        value: q,
                        child: Text(q, style: const TextStyle(fontSize: 12, color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          if (_isAudio) {
                            _selectedAudioQuality = val;
                          } else {
                            _selectedVideoQuality = val;
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Progress bar
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress, color: const Color(0xFF00F076), backgroundColor: const Color(0xFF1D222D)),
              const SizedBox(height: 14),
            ],

            // Action Button
            ElevatedButton(
              onPressed: _isDownloading ? null : _startDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F076),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                _isDownloading ? "DOWNLOADING..." : "⚡ START INSTANT DOWNLOAD",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),

            if (_savedFilePath.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF102619),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00F076)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00F076)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "File successfully saved to your phone's Downloads folder!",
                        style: TextStyle(color: Color(0xFF00F076), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
