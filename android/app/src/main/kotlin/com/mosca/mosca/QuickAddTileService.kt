package com.mosca.mosca

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

// Quick Settings tile — Android equivalent of the iOS Action Button shortcut.
// Register in AndroidManifest.xml inside <application>:
//
//   <service
//       android:name=".QuickAddTileService"
//       android:icon="@drawable/ic_add"
//       android:label="Gasto rápido"
//       android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"
//       android:exported="true">
//     <intent-filter>
//       <action android:name="android.service.quicksettings.action.QS_TILE" />
//     </intent-filter>
//   </service>

@RequiresApi(Build.VERSION_CODES.N)
class QuickAddTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            state = Tile.STATE_ACTIVE
            label = "Gasto rápido"
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = android.net.Uri.parse("mosca://quick-add")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pending = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            startActivityAndCollapse(pending)
        } else {
            startActivityAndCollapse(intent)
        }
    }
}
