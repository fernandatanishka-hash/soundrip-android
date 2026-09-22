[app]

title = SoundRip
package.name = soundrip
package.domain = org.soundrip
source.dir = .
source.include_exts = py,png,jpg,kv,atlas
version = 1.0.0

requirements = python3,kivy,yt-dlp,urllib3,certifi,charset-normalizer,idna

orientation = portrait
android.permissions = INTERNET,WRITE_EXTERNAL_STORAGE,READ_EXTERNAL_STORAGE

android.api = 33
android.minapi = 21
android.ndk = 25b
android.archs = arm64-v8a
android.accept_sdk_license = True
android.skip_update = False

[buildozer]
log_level = 2
warn_on_root = 1
