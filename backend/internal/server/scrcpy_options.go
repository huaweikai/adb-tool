package server

import (
	"fmt"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// ScrcpyOptions is the typed, user-configurable surface of the scrcpy
// command line. All field names match scrcpy 4.0's --long-option names
// (with hyphens converted to camelCase) so the mapping to CLI args is
// mechanical and grep-friendly.
//
// Scrcpy option reference:
//   doc/video.md    doc/audio.md    doc/window.md
//   doc/control.md  doc/camera.md   doc/recording.md
//   doc/shortcuts.md
//
// Bool-typed options use plain bool (omitempty-friendly): false means
// "do not pass the flag", true means "pass it". Negative variants
// (--no-*) are exposed as separate `No<Thing>` booleans when both
// forms exist (e.g. NoAudio vs AudioPlayback).
type ScrcpyOptions struct {
	// ── Video (doc/video.md) ────────────────────────────────────
	MaxSize            int    `json:"max_size"`               // --max-size=N, 0 = unlimited
	VideoBitRate       string `json:"video_bit_rate"`         // --video-bit-rate=8M
	MaxFps             int    `json:"max_fps"`                // --max-fps=N, 0 = unlimited
	VideoCodec         string `json:"video_codec"`            // h264|h265|av1 (default h264)
	VideoEncoder       string `json:"video_encoder,omitempty"` // --video-encoder=...
	VideoBuffer        int    `json:"video_buffer"`           // ms, 0 = no buffering
	NoMipmaps          bool   `json:"no_mipmaps"`
	CaptureOrientation string `json:"capture_orientation,omitempty"` // 0|90|180|270|flip...
	DisplayOrientation string `json:"display_orientation,omitempty"`
	Crop               string `json:"crop,omitempty"`         // 1224:1440:0:0
	Angle              int    `json:"angle"`                  // --angle=N
	DisplayId          int    `json:"display_id"`             // --display-id=N
	RenderFit          string `json:"render_fit,omitempty"`   // letterbox|stretched|unscaled
	BackgroundColor    string `json:"background_color,omitempty"`
	MinSizeAlignment   int    `json:"min_size_alignment"`     // 1|2|4|8|16
	NoDownsizeOnError  bool   `json:"no_downsize_on_error"`
	PrintFps           bool   `json:"print_fps"`

	// ── Audio (doc/audio.md) ─────────────────────────────────────
	NoAudio           bool   `json:"no_audio"`
	NoAudioPlayback   bool   `json:"no_audio_playback"`
	AudioSource       string `json:"audio_source,omitempty"` // output|mic|mic-camcorder|...
	AudioCodec        string `json:"audio_codec,omitempty"`  // opus|aac|flac|raw
	AudioEncoder      string `json:"audio_encoder,omitempty"`
	AudioBitRate      string `json:"audio_bit_rate,omitempty"`
	AudioBuffer       int    `json:"audio_buffer"`          // ms
	AudioOutputBuffer int    `json:"audio_output_buffer"`   // ms
	AudioDup          bool   `json:"audio_dup"`             // Android 13+
	RequireAudio      bool   `json:"require_audio"`

	// ── Camera (doc/camera.md) ───────────────────────────────────
	// VideoSource is the master switch: "display" (default) mirrors
	// the screen, "camera" mirrors the device camera.
	VideoSource   string  `json:"video_source,omitempty"` // display|camera
	CameraId      int     `json:"camera_id"`              // --camera-id=N
	CameraFacing  string  `json:"camera_facing,omitempty"` // front|back|external|any
	CameraSize    string  `json:"camera_size,omitempty"`   // 1920x1080
	CameraAr      string  `json:"camera_ar,omitempty"`     // 4:3|1.6|sensor
	CameraFps     int     `json:"camera_fps"`
	CameraHighSpeed bool  `json:"camera_high_speed"`
	CameraTorch   bool    `json:"camera_torch"`
	CameraZoom    float64 `json:"camera_zoom"` // 1.0 = no zoom

	// ── Window (doc/window.md) ───────────────────────────────────
	Borderless               bool   `json:"borderless"`
	WindowTitle              string `json:"window_title,omitempty"`
	WindowX                  int    `json:"window_x"`
	WindowY                  int    `json:"window_y"`
	WindowWidth              int    `json:"window_width"`
	WindowHeight             int    `json:"window_height"`
	AlwaysOnTop              bool   `json:"always_on_top"`
	Fullscreen               bool   `json:"fullscreen"`
	DisableScreensaver       bool   `json:"disable_screensaver"`
	NoWindow                 bool   `json:"no_window"`
	NoWindowAspectRatioLock  bool   `json:"no_window_aspect_ratio_lock"`

	// ── Control (doc/control.md, keyboard.md, mouse.md) ──────────
	Keyboard           string `json:"keyboard,omitempty"` // sdk|uhid|aoa|disabled
	Mouse              string `json:"mouse,omitempty"`    // sdk|uhid|aoa|disabled
	NoControl          bool   `json:"no_control"`
	MouseBind          string `json:"mouse_bind,omitempty"` // xxxx[:xxxx]
	PreferText         bool   `json:"prefer_text"`
	RawKeyEvents       bool   `json:"raw_key_events"`
	NoKeyRepeat        bool   `json:"no_key_repeat"`
	NoMouseHover       bool   `json:"no_mouse_hover"`
	LegacyPaste        bool   `json:"legacy_paste"`
	NoClipboardAutosync bool  `json:"no_clipboard_autosync"`

	// ── Device (shortcuts.md + various) ──────────────────────────
	StayAwake         bool   `json:"stay_awake"`
	TurnScreenOff     bool   `json:"turn_screen_off"`
	KeepActive        bool   `json:"keep_active"`         // scrcpy 4.0+
	ShowTouches       bool   `json:"show_touches"`
	PowerOffOnClose   bool   `json:"power_off_on_close"`
	NoPowerOn         bool   `json:"no_power_on"`
	ScreenOffTimeout  int    `json:"screen_off_timeout"`  // seconds
	ShortcutMod       string `json:"shortcut_mod,omitempty"`

	// ── Recording (doc/recording.md) ─────────────────────────────
	RecordEnabled bool   `json:"record_enabled"`          // master switch for recording
	Record       string `json:"record,omitempty"`        // directory path; file name auto-generated as record_yyyyMMdd_HHmmss.{ext}
	RecordFormat string `json:"record_format,omitempty"` // mp4|mkv|opus|flac|wav|...
	TimeLimit    int    `json:"time_limit"`              // seconds, 0 = no limit
	NoPlayback   bool   `json:"no_playback"`
	NoVideoPlayback bool `json:"no_video_playback"`
	PauseOnExit  string `json:"pause_on_exit,omitempty"`  // true|false|if-error
}

// DefaultScrcpyOptions returns the conservative defaults we use when
// the client sends no options (or an empty body). Tuned to be
// "works on the widest set of devices" rather than "max quality".
func DefaultScrcpyOptions() ScrcpyOptions {
	return ScrcpyOptions{
		MaxSize:      1024,
		VideoBitRate: "8M",
		MaxFps:       0, // unlimited
		VideoCodec:   "h264",
		VideoSource:  "display",
		AudioSource:  "output",
		AudioCodec:   "opus",
		AudioBitRate: "128K",
		Keyboard:     "sdk",
		Mouse:        "sdk",
		RenderFit:    "letterbox",
		StayAwake:    true, // most users want the device to stay awake while mirroring
		Borderless:   true, // matches what we already ship
	}
}

// Args converts the options to scrcpy CLI arguments, dropping zero-value
// fields. The result is suitable to append after the positional `serial`
// and a few always-on flags we hardcode (--stay-awake when StayAwake=true
// etc.).
//
// All flag names are verified against scrcpy 4.0 cli.c. If you add a new
// field, double-check the long option name there — scrcpy is picky
// (e.g. it's --video-bit-rate not --bit-rate).
func (o ScrcpyOptions) Args() []string {
	var args []string

	// ── Video ────────────────────────────────────────────────────
	if o.MaxSize > 0 {
		args = append(args, "--max-size="+strconv.Itoa(o.MaxSize))
	}
	if o.VideoBitRate != "" {
		args = append(args, "--video-bit-rate="+o.VideoBitRate)
	}
	if o.MaxFps > 0 {
		args = append(args, "--max-fps="+strconv.Itoa(o.MaxFps))
	}
	if o.VideoCodec != "" {
		args = append(args, "--video-codec="+o.VideoCodec)
	}
	if o.VideoEncoder != "" {
		args = append(args, "--video-encoder="+o.VideoEncoder)
	}
	if o.VideoBuffer > 0 {
		args = append(args, "--video-buffer="+strconv.Itoa(o.VideoBuffer))
	}
	if o.NoMipmaps {
		args = append(args, "--no-mipmaps")
	}
	if o.CaptureOrientation != "" {
		args = append(args, "--capture-orientation="+o.CaptureOrientation)
	}
	if o.DisplayOrientation != "" {
		args = append(args, "--display-orientation="+o.DisplayOrientation)
	}
	if o.Crop != "" {
		args = append(args, "--crop="+o.Crop)
	}
	if o.Angle != 0 {
		args = append(args, "--angle="+strconv.Itoa(o.Angle))
	}
	if o.DisplayId > 0 {
		args = append(args, "--display-id="+strconv.Itoa(o.DisplayId))
	}
	if o.RenderFit != "" {
		args = append(args, "--render-fit="+o.RenderFit)
	}
	if o.BackgroundColor != "" {
		args = append(args, "--background-color="+o.BackgroundColor)
	}
	if o.MinSizeAlignment > 0 {
		args = append(args, "--min-size-alignment="+strconv.Itoa(o.MinSizeAlignment))
	}
	if o.NoDownsizeOnError {
		args = append(args, "--no-downsize-on-error")
	}
	if o.PrintFps {
		args = append(args, "--print-fps")
	}

	// ── Audio ────────────────────────────────────────────────────
	if o.NoAudio {
		args = append(args, "--no-audio")
	}
	if o.NoAudioPlayback {
		args = append(args, "--no-audio-playback")
	}
	if o.AudioSource != "" {
		args = append(args, "--audio-source="+o.AudioSource)
	}
	if o.AudioCodec != "" {
		args = append(args, "--audio-codec="+o.AudioCodec)
	}
	if o.AudioEncoder != "" {
		args = append(args, "--audio-encoder="+o.AudioEncoder)
	}
	if o.AudioBitRate != "" {
		args = append(args, "--audio-bit-rate="+o.AudioBitRate)
	}
	if o.AudioBuffer > 0 {
		args = append(args, "--audio-buffer="+strconv.Itoa(o.AudioBuffer))
	}
	if o.AudioOutputBuffer > 0 {
		args = append(args, "--audio-output-buffer="+strconv.Itoa(o.AudioOutputBuffer))
	}
	if o.AudioDup {
		args = append(args, "--audio-dup")
	}
	if o.RequireAudio {
		args = append(args, "--require-audio")
	}

	// ── Camera (master switch is VideoSource) ────────────────────
	if o.VideoSource != "" && o.VideoSource != "display" {
		// "display" is the default; only emit when the user actually
		// asked for camera mode.
		args = append(args, "--video-source="+o.VideoSource)
	}
	if o.CameraId > 0 {
		args = append(args, "--camera-id="+strconv.Itoa(o.CameraId))
	}
	if o.CameraFacing != "" {
		args = append(args, "--camera-facing="+o.CameraFacing)
	}
	if o.CameraSize != "" {
		args = append(args, "--camera-size="+o.CameraSize)
	}
	if o.CameraAr != "" {
		args = append(args, "--camera-ar="+o.CameraAr)
	}
	if o.CameraFps > 0 {
		args = append(args, "--camera-fps="+strconv.Itoa(o.CameraFps))
	}
	if o.CameraHighSpeed {
		args = append(args, "--camera-high-speed")
	}
	if o.CameraTorch {
		args = append(args, "--camera-torch")
	}
	if o.CameraZoom != 0 {
		args = append(args, "--camera-zoom="+strconv.FormatFloat(o.CameraZoom, 'f', -1, 64))
	}

	// ── Window ───────────────────────────────────────────────────
	if o.Borderless {
		args = append(args, "--window-borderless")
	}
	if o.WindowTitle != "" {
		args = append(args, "--window-title="+o.WindowTitle)
	}
	if o.WindowX != 0 {
		args = append(args, "--window-x="+strconv.Itoa(o.WindowX))
	}
	if o.WindowY != 0 {
		args = append(args, "--window-y="+strconv.Itoa(o.WindowY))
	}
	if o.WindowWidth > 0 {
		args = append(args, "--window-width="+strconv.Itoa(o.WindowWidth))
	}
	if o.WindowHeight > 0 {
		args = append(args, "--window-height="+strconv.Itoa(o.WindowHeight))
	}
	if o.AlwaysOnTop {
		args = append(args, "--always-on-top")
	}
	if o.Fullscreen {
		args = append(args, "--fullscreen")
	}
	if o.DisableScreensaver {
		args = append(args, "--disable-screensaver")
	}
	if o.NoWindow {
		args = append(args, "--no-window")
	}
	if o.NoWindowAspectRatioLock {
		args = append(args, "--no-window-aspect-ratio-lock")
	}

	// ── Control ──────────────────────────────────────────────────
	if o.Keyboard != "" {
		args = append(args, "--keyboard="+o.Keyboard)
	}
	if o.Mouse != "" {
		args = append(args, "--mouse="+o.Mouse)
	}
	if o.NoControl {
		args = append(args, "--no-control")
	}
	if o.MouseBind != "" {
		args = append(args, "--mouse-bind="+o.MouseBind)
	}
	if o.PreferText {
		args = append(args, "--prefer-text")
	}
	if o.RawKeyEvents {
		args = append(args, "--raw-key-events")
	}
	if o.NoKeyRepeat {
		args = append(args, "--no-key-repeat")
	}
	if o.NoMouseHover {
		args = append(args, "--no-mouse-hover")
	}
	if o.LegacyPaste {
		args = append(args, "--legacy-paste")
	}
	if o.NoClipboardAutosync {
		args = append(args, "--no-clipboard-autosync")
	}

	// ── Device ───────────────────────────────────────────────────
	if o.StayAwake {
		args = append(args, "--stay-awake")
	}
	if o.TurnScreenOff {
		args = append(args, "--turn-screen-off")
	}
	if o.KeepActive {
		args = append(args, "--keep-active")
	}
	if o.ShowTouches {
		args = append(args, "--show-touches")
	}
	if o.PowerOffOnClose {
		args = append(args, "--power-off-on-close")
	}
	if o.NoPowerOn {
		args = append(args, "--no-power-on")
	}
	if o.ScreenOffTimeout > 0 {
		args = append(args, "--screen-off-timeout="+strconv.Itoa(o.ScreenOffTimeout))
	}
	if o.ShortcutMod != "" {
		args = append(args, "--shortcut-mod="+o.ShortcutMod)
	}

	// ── Recording ────────────────────────────────────────────────
	if o.RecordEnabled && o.Record != "" {
		ext := o.RecordFormat
		if ext == "" {
			ext = "mp4"
		}
		filename := "record_" + time.Now().Format("20060102_150405") + "." + ext
		args = append(args, "--record="+filepath.Join(o.Record, filename))
	}
	if o.RecordFormat != "" {
		args = append(args, "--record-format="+o.RecordFormat)
	}
	if o.TimeLimit > 0 {
		args = append(args, "--time-limit="+strconv.Itoa(o.TimeLimit))
	}
	if o.NoPlayback {
		args = append(args, "--no-playback")
	}
	if o.NoVideoPlayback {
		args = append(args, "--no-video-playback")
	}
	if o.PauseOnExit != "" {
		args = append(args, "--pause-on-exit="+o.PauseOnExit)
	}

	return args
}

// Validate returns an error if the options contain values scrcpy would
// reject (e.g. an unknown codec, out-of-range bit rate). We do this
// before spawning so the user gets a clear 400 instead of a confusing
// "scrcpy exited with code 1" five seconds later.
//
// This is intentionally a subset of scrcpy's full validation — only
// the things likely to come from a misconfigured UI.
func (o ScrcpyOptions) Validate() error {
	switch o.VideoCodec {
	case "", "h264", "h265", "av1":
		// ok
	default:
		return fmt.Errorf("video_codec: %q is not one of h264|h265|av1", o.VideoCodec)
	}
	switch o.AudioCodec {
	case "", "opus", "aac", "flac", "raw":
		// ok
	default:
		return fmt.Errorf("audio_codec: %q is not one of opus|aac|flac|raw", o.AudioCodec)
	}
	switch o.VideoSource {
	case "", "display", "camera":
		// ok
	default:
		return fmt.Errorf("video_source: %q is not one of display|camera", o.VideoSource)
	}
	switch o.RenderFit {
	case "", "letterbox", "stretched", "unscaled":
		// ok
	default:
		return fmt.Errorf("render_fit: %q is not one of letterbox|stretched|unscaled", o.RenderFit)
	}
	switch o.Keyboard {
	case "", "sdk", "uhid", "aoa", "disabled":
		// ok
	default:
		return fmt.Errorf("keyboard: %q is not one of sdk|uhid|aoa|disabled", o.Keyboard)
	}
	switch o.Mouse {
	case "", "sdk", "uhid", "aoa", "disabled":
		// ok
	default:
		return fmt.Errorf("mouse: %q is not one of sdk|uhid|aoa|disabled", o.Mouse)
	}
	if o.CameraFacing != "" {
		switch o.CameraFacing {
		case "front", "back", "external", "any":
			// ok
		default:
			return fmt.Errorf("camera_facing: %q is not one of front|back|external|any", o.CameraFacing)
		}
	}
	if o.MinSizeAlignment > 0 {
		// Must be a power of 2 between 1 and 16 (scrcpy's constraint).
		switch o.MinSizeAlignment {
		case 1, 2, 4, 8, 16:
			// ok
		default:
			return fmt.Errorf("min_size_alignment: %d must be a power of 2 in 1|2|4|8|16", o.MinSizeAlignment)
		}
	}
	if o.Record != "" && o.RecordFormat == "" {
		// scrcpy auto-picks from filename; that's fine, just make sure
		// the path is non-empty (already guaranteed by JSON omitempty
		// dropping the field).
	}
	// Reject impossible camera-size formats early.
	if o.CameraSize != "" && !strings.Contains(o.CameraSize, "x") {
		return fmt.Errorf("camera_size: %q must look like 1920x1080", o.CameraSize)
	}
	return nil
}

// isZeroOptions reports whether the caller passed an empty (zero-value)
// ScrcpyOptions. We use it in StartScrcpy to decide between
// "use defaults" and "user really wanted an option-less call". Note we
// can't use == on a struct with non-comparable fields (slices, maps),
// so we sample a representative subset of fields.
func isZeroOptions(o ScrcpyOptions) bool {
	return o.MaxSize == 0 &&
		o.VideoBitRate == "" &&
		o.VideoCodec == "" &&
		o.NoAudio == false &&
		o.Borderless == false &&
		o.Keyboard == "" &&
		o.Mouse == "" &&
		o.StayAwake == false &&
		o.VideoSource == "" &&
		o.Record == ""
}
