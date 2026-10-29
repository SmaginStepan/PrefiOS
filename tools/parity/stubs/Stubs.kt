package android.util
object Log {
    @JvmStatic fun w(tag: String, msg: String, tr: Throwable? = null): Int = 0
    @JvmStatic fun e(tag: String, msg: String, tr: Throwable? = null): Int = 0
}
