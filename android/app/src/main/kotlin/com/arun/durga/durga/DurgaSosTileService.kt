package com.arun.durga.durga

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

/**
 * Quick Settings tile that provides a one-tap SOS action from the
 * notification shade. When tapped, immediately opens the phone dialer
 * with the emergency number pre-filled.
 */
@RequiresApi(Build.VERSION_CODES.N)
class DurgaSosTileService : TileService() {

    override fun onClick() {
        super.onClick()

        val callIntent = Intent(Intent.ACTION_DIAL).apply {
            data = Uri.parse("tel:100")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        // startActivityAndCollapse closes the notification shade and launches
        // the dialer. On Android 14+ (API 34) the method signature changed to
        // accept a PendingIntent, but the Intent overload still works on lower APIs.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = android.app.PendingIntent.getActivity(
                this,
                0,
                callIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(callIntent)
        }
    }

    override fun onTileAdded() {
        super.onTileAdded()
        // Update tile state when first added
        qsTile?.let { tile ->
            tile.label = "Durga SOS"
            tile.state = android.service.quicksettings.Tile.STATE_INACTIVE
            tile.updateTile()
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        // Keep tile active whenever it's visible
        qsTile?.let { tile ->
            tile.state = android.service.quicksettings.Tile.STATE_ACTIVE
            tile.updateTile()
        }
    }
}
