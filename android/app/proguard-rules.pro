# Keep speech_to_text
-keep class com.csdcorp.** { *; }
-keep class io.flutter.plugins.speechtotext.** { *; }

# Keep flutter_tts
-keep class com.fluttertts.** { *; }

# Keep llama
-keep class com.llama.** { *; }

# Keep all flutter plugins
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
