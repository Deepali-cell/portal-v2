# Strip debug/verbose/info logging from release builds: the call-detection
# service logs phone numbers and contact names while it works.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
