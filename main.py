import os
import threading
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.button import Button
from kivy.uix.spinner import Spinner
from kivy.uix.progressbar import ProgressBar
from kivy.utils import platform
import yt_dlp

class SoundRipMobile(App):
    def build(self):
        self.title = "SoundRip Mobile"
        
        # Main Layout (Dark Studio Aesthetic)
        layout = BoxLayout(orientation='vertical', padding=25, spacing=15)
        
        # 1. Header
        header = Label(
            text="⚡ SOUNDRIP STUDIO", 
            font_size='22sp', 
            bold=True, 
            color=(0, 0.94, 0.46, 1), # Mint Green
            size_hint_y=None, 
            height=40
        )
        layout.add_widget(header)

        sub_header = Label(
            text="YouTube MP3 & MP4 Downloader", 
            font_size='13sp', 
            color=(0.55, 0.60, 0.66, 1), 
            size_hint_y=None, 
            height=25
        )
        layout.add_widget(sub_header)

        # 2. URL Input Box
        layout.add_widget(Label(
            text="PASTE YOUTUBE URL:", 
            font_size='11sp', 
            bold=True, 
            color=(0.7, 0.7, 0.7, 1), 
            size_hint_y=None, 
            height=20
        ))

        self.url_input = TextInput(
            hint_text="https://youtu.be/...", 
            multiline=False, 
            size_hint_y=None, 
            height=50,
            background_color=(0.12, 0.14, 0.18, 1),
            foreground_color=(1, 1, 1, 1),
            cursor_color=(0, 0.94, 0.46, 1),
            padding=[12, 12, 12, 12]
        )
        layout.add_widget(self.url_input)

        # 3. Format Selector (Audio vs Video)
        layout.add_widget(Label(
            text="SELECT FORMAT:", 
            font_size='11sp', 
            bold=True, 
            color=(0.7, 0.7, 0.7, 1), 
            size_hint_y=None, 
            height=20
        ))

        self.format_spinner = Spinner(
            text="🎵 Audio (MP3)",
            values=["🎵 Audio (MP3)", "🎬 Video (MP4)"],
            size_hint_y=None,
            height=45,
            background_color=(0.15, 0.20, 0.28, 1),
            color=(1, 1, 1, 1)
        )
        layout.add_widget(self.format_spinner)

        # 4. Big Download Button
        self.download_btn = Button(
            text="⚡ DOWNLOAD NOW",
            font_size='15sp',
            bold=True,
            size_hint_y=None,
            height=55,
            background_normal='',
            background_color=(0, 0.94, 0.46, 1),
            color=(0.04, 0.08, 0.05, 1)
        )
        self.download_btn.bind(on_press=self.start_download)
        layout.add_widget(self.download_btn)

        # 5. Status Label
        self.status_lbl = Label(
            text="Ready. Paste a link above.",
            font_size='12sp',
            color=(0.55, 0.60, 0.66, 1),
            size_hint_y=None,
            height=40
        )
        layout.add_widget(self.status_lbl)

        # 6. Community / Sponsor Footer
        footer = Label(
            text="💬 SoundRip Engine • 100% Free Hardware Client",
            font_size='10sp',
            color=(0.35, 0.40, 0.48, 1),
            size_hint_y=None,
            height=30
        )
        layout.add_widget(footer)

        return layout

    def start_download(self, instance):
        url = self.url_input.text.strip()
        if not url:
            self.status_lbl.text = "Please enter a YouTube URL!"
            self.status_lbl.color = (1, 0.27, 0.23, 1)
            return

        self.download_btn.disabled = True
        self.download_btn.text = "DOWNLOADING..."
        self.status_lbl.text = "Connecting to YouTube stream..."
        self.status_lbl.color = (0, 0.94, 0.46, 1)

        threading.Thread(target=self.download_worker, args=(url,), daemon=True).start()

    def download_worker(self, url):
        is_audio = "Audio" in self.format_spinner.text

        # On Android, save directly to the phone's public Download folder
        if platform == 'android':
            from android.storage import primary_external_storage_path
            download_dir = os.path.join(primary_external_storage_path(), "Download")
        else:
            download_dir = os.path.join(os.path.expanduser("~"), "Downloads")

        out_template = os.path.join(download_dir, "%(title)s.%(ext)s")

        ydl_opts = {
            'outtmpl': out_template,
            'quiet': True,
            'no_warnings': True,
        }

        if is_audio:
            ydl_opts['format'] = 'bestaudio/best'
            ydl_opts['postprocessors'] = [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '192',
            }]
        else:
            ydl_opts['format'] = 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'
            ydl_opts['merge_output_format'] = 'mp4'

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                title = info.get('title', 'Media')
            self._update_status(f"Saved: {title[:30]}...", success=True)
        except Exception as e:
            self._update_status(f"Error: {str(e)[:40]}", success=False)

    def _update_status(self, msg, success):
        def update():
            self.status_lbl.text = msg
            self.status_lbl.color = (0, 0.94, 0.46, 1) if success else (1, 0.27, 0.23, 1)
            self.download_btn.disabled = False
            self.download_btn.text = "⚡ DOWNLOAD NOW"
        from kivy.clock import Clock
        Clock.schedule_once(lambda dt: update(), 0)

if __name__ == '__main__':
    SoundRipMobile().run()
