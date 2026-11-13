# google_mlkit_text_recognition references the optional Chinese, Devanagari,
# Japanese and Korean recognizers. The app only bundles the Latin model, so
# those classes are absent and R8 fails the release build without these rules.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
