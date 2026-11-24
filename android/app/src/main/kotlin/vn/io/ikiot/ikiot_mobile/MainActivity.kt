package vn.io.ikiot.ikiot_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDeliveryChannel()
    }

    /**
     * Kênh mà push FCM rơi vào (khai báo trong AndroidManifest). Không có nó, FCM dùng kênh dự phòng mức mặc định:
     * thông báo chỉ nằm trong khay, không hiện nổi, và shipper đang chạy xe dễ bỏ lỡ đơn mới.
     * Tạo lại mỗi lần mở app là an toàn: kênh đã có thì Android giữ nguyên cài đặt người dùng đã chỉnh.
     */
    private fun createDeliveryChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            getString(R.string.delivery_channel_id),
            getString(R.string.delivery_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = getString(R.string.delivery_channel_description) }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
