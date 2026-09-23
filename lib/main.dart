
--- orig/main.dart.orig	2026-09-23 01:14:47.435468339 +0000
+++ soundrip-android-main/lib/main.dart	2026-09-23 01:14:18.757101210 +0000
@@ -38,6 +38,34 @@
   State<HomeScreen> createState() => _HomeScreenState();
 }
 
+/// Ordered groups of YouTube "internal client" personas to try when asking
+/// YouTube for a stream manifest.
+///
+/// Root cause of the `VideoUnplayableException` / "Sign in to confirm
+/// you're not a bot" failures this app was hitting: the previous code
+/// always requested `YoutubeApiClient.safari` + `YoutubeApiClient.androidVr`
+/// only. Neither of those is the client youtube_explode_dart's own
+/// maintainers currently recommend as the safe default -- `safari` needs a
+/// JavaScript signature-challenge solver (a Deno subprocess) that cannot
+/// run inside an Android APK, and when YouTube's anti-bot / PO-Token check
+/// flags a client (which it increasingly does for "safari"/"androidVr" on
+/// data-center-like or already-flagged IPs), the whole call throws instead
+/// of silently degrading.
+///
+/// `androidSdkless` is the client the library switched its own internal
+/// default to (see Hexer10/youtube_explode_dart PR #371): it is a copy of
+/// the Android client with the `androidSdkVersion` field removed, which is
+/// specifically the field that makes YouTube demand a PO Token. `ios` is
+/// documented as not requiring signature deciphering at all. Trying several
+/// independent groups in order means that if one "persona" is rate-limited
+/// or blocked for a particular video/IP, the app still has other, unrelated
+/// personas to fall back to instead of failing outright.
+const List<List<YoutubeApiClient>> _kClientFallbackGroups = [
+  [YoutubeApiClient.androidSdkless, YoutubeApiClient.ios],
+  [YoutubeApiClient.tv, YoutubeApiClient.androidVr],
+  [YoutubeApiClient.safari],
+];
+
 class _HomeScreenState extends State<HomeScreen> {
   final TextEditingController _urlController = TextEditingController();
   final YoutubeExplode _yt = YoutubeExplode();
@@ -74,6 +102,44 @@
     }
   }
 
+  /// Requests the stream manifest, trying each client group in
+  /// [_kClientFallbackGroups] in order until one succeeds.
+  ///
+  /// This is what makes extraction resilient instead of crashing outright:
+  /// previously a single blocked client aborted the whole download with a
+  /// raw [VideoUnplayableException]. Now a block on one client persona just
+  /// moves on to the next, independent one.
+  Future<StreamManifest> _getManifestWithFallback(String url) async {
+    Object? lastError;
+    for (final clients in _kClientFallbackGroups) {
+      try {
+        final manifest = await _yt.videos.streamsClient.getManifest(
+          url,
+          ytClients: clients,
+        );
+        if (manifest.streams.isNotEmpty) {
+          return manifest;
+        }
+      } catch (e) {
+        lastError = e;
+        // Try the next independent client group.
+        continue;
+      }
+    }
+    final isBotCheck = lastError != null &&
+        lastError.toString().toLowerCase().contains('bot');
+    throw Exception(
+      isBotCheck
+          ? 'YouTube blocked this download as a bot-check on every '
+              'available client. This is a server-side restriction from '
+              'YouTube (often tied to your network/IP), not an app bug -- '
+              'it can be temporary. Try again in a bit, on a different '
+              'network, or with a different video.'
+          : 'Could not fetch this video\'s streams from YouTube. '
+              '($lastError)',
+    );
+  }
+
   Future<void> _startDownload() async {
     final url = _urlController.text.trim();
     if (url.isEmpty) {
@@ -92,15 +158,10 @@
 
     try {
       var video = await _yt.videos.get(url);
-      
-      // Request manifest with unblocked clients
-      var manifest = await _yt.videos.streamsClient.getManifest(
-        url,
-               ytClients: [
-          YoutubeApiClient.safari,
-          YoutubeApiClient.androidVr,
-        ],
-      );
+
+      // Request manifest, falling back across several independent YouTube
+      // client personas so a bot-check on one doesn't fail the whole thing.
+      var manifest = await _getManifestWithFallback(url);
 
       StreamInfo streamInfo;
       String extension;
 
