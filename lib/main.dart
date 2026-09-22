import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

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
  String _statusText = "Ready. Paste a YouTube link to begin.";
  String _videoTitle = "No video loaded";
  String? _savedFilePath;

  String _selectedAudioQuality = "320 kbps (HQ)";
  String _selectedVideoQuality = "720p (HD)";

  final List<String> _audioQualities = ["320 kbps (HQ)", "192 kbps (Standard)", "128 kbps (Fast)"];
  final List<String> _videoQualities = ["720p (HD)", "480p", "360p"];

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
      setState(() => _statusText = "Fetching video details...");
      var video = await _yt.videos.get(url);
      setState(() {
        _videoTitle = video.title;
        _statusText = "Channel: ${video.author} • ${video.duration?.inMinutes ?? 0} mins";
      });
    } catch (_) {
      setState(() => _statusText = "Ready to download");
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
      _savedFilePath = null;
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
        // Choose best matching video quality
        if (_selectedVideoQuality == "720p (HD)") {
          streamInfo = manifest.muxed.firstWhere(
            (s) => s.videoQualityLabel.contains('720'),
            orElse: () => manifest.muxed.withHighestBitrate(),
          );
        } else if (_selectedVideoQuality == "480p") {
          streamInfo = manifest.muxed.firstWhere(
            (s) => s.videoQualityLabel.contains('480'),
            orElse: () => manifest.muxed.withHighestBitrate(),
          );
        } else {
          streamInfo = manifest.muxed.firstWhere(
            (s) => s.videoQualityLabel.contains('360'),
            orElse: () => manifest.muxed.withHighestBitrate(),
          );
        }
        extension = "mp4";
      }

      // Safe saving directory (works on all Android 10, 11, 12, 13, 14)
      Directory? baseDir = await getExternalStorageDirectory();
      baseDir ??= await getApplicationDocumentsDirectory();

      String cleanTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (cleanTitle.length > 40) {
        cleanTitle = cleanTitle.substring(0, 40);
      }

      File file = File('${baseDir.path}/$cleanTitle.$extension');
      var fileStream = file.openWrite();

      var stream = _yt.videos.streamsClient.get(streamInfo);
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

      // Also copy to public Downloads if permitted
      try {
        Directory publicDownloads = Directory('/storage/emulated/0/Download');
        if (await publicDownloads.exists()) {
          await file.copy('${publicDownloads.path}/$cleanTitle.$extension');
        }
      } catch (_) {}

      setState(() {
        _isDownloading = false;
        _savedFilePath = file.path;
        _statusText = "Download Complete!";
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusText = "Error: $e";
      });
    }
  }

  void _openFile() {
    if (_savedFilePath != null) {
      OpenFilex.open(_savedFilePath!);
    }
  }

  void _shareFile() {
    if (_savedFilePath != null) {
      Share.shareXFiles([XFile(_savedFilePath!)], text: "Downloaded with SoundRip Studio");
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
            // URL Input Card
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
                            hintText: "Paste YouTube link...",
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
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A3345), foregroundColor: Colors.white),
                        child: const Text("Paste"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metadata Card
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

            // Format Selection
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

            // Quality Dropdown
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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
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

            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress, color: const Color(0xFF00F076), backgroundColor: const Color(0xFF1D222D)),
              const SizedBox(height: 14),
            ],

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

            // Success Action Buttons (Play & Share)
            if (_savedFilePath != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF102619),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00F076)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF00F076)),
                        SizedBox(width: 8),
                        Text("Download Ready!", style: TextStyle(color: Color(0xFF00F076), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text("▶ PLAY NOW"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00F076),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _openFile,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.share),
                            label: const Text("📤 SHARE"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A3345),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _shareFile,
                          ),
                        ),
                      ],
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
