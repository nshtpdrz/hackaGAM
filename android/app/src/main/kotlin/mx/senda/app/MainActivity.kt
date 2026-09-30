package mx.senda.app

import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (y no FlutterActivity): local_auth la necesita para entrar con huella o rostro.
class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sobrePantallaBloqueada(esAlarmaDeToma(intent))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sobrePantallaBloqueada(esAlarmaDeToma(intent))
    }

    // Al salir de la app se vuelve a exigir el desbloqueo: solo la alarma se muestra sin desbloquear.
    override fun onStop() {
        super.onStop()
        sobrePantallaBloqueada(false)
    }

    // Alarma de toma (lib/core/reminders.dart): flutter_local_notifications abre la app con la acción
    // SELECT_NOTIFICATION y el id de la notificación; las alarmas usan los ids 700000-809999.
    private fun esAlarmaDeToma(intent: Intent?): Boolean {
        if (intent?.action != "SELECT_NOTIFICATION") return false
        val id = intent.getIntExtra("notificationId", -1)
        return id in 700000..809999
    }

    // Enciende la pantalla y muestra la alarma encima del bloqueo (pantalla completa del canal "alarma_tomas").
    @Suppress("DEPRECATION")
    private fun sobrePantallaBloqueada(activo: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(activo)
            setTurnScreenOn(activo)
        } else {
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (activo) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    // Canal para Preferencias > Avisos (lib/core/avisos_nativos.dart): lo que los plugins no dicen.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mx.senda.app/avisos").setMethodCallHandler { call, result ->
            when (call.method) {
                "estado" -> result.success(mapOf(
                    "pantallaCompleta" to puedePantallaCompleta(),
                    "sinRestriccionBateria" to sinRestriccionBateria(),
                    "fabricante" to Build.MANUFACTURER.lowercase()))
                "abrirAjustesApp" -> result.success(abrir(ajustesDeLaApp()))
                "abrirAjustesBateria" -> result.success(abrir(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)))
                else -> result.notImplemented()
            }
        }
    }

    // Android 14+: la alarma a pantalla completa necesita permiso; antes siempre estaba permitida.
    private fun puedePantallaCompleta(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
            getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
        else true

    // Con "optimización de batería" el sistema puede retrasar alarmas y push (Xiaomi, Samsung, Huawei...).
    private fun sinRestriccionBateria(): Boolean =
        getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)

    private fun ajustesDeLaApp() =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))

    // Si el fabricante quitó esa pantalla de Ajustes, se abre la ficha de la app.
    private fun abrir(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); true
    } catch (e: Exception) {
        try { startActivity(ajustesDeLaApp().addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); true } catch (e2: Exception) { false }
    }
}
