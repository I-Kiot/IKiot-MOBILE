# iKiot Giao hàng

Ứng dụng di động (Android + iOS) cho **nhân viên giao hàng** của cửa hàng dùng iKiot. Shipper xem đơn được
giao, lấy hàng ở kho, đi giao, thu tiền (tiền mặt hoặc QR chuyển khoản), báo giao không thành và xem lại
lịch sử giao. Dữ liệu lấy từ IKiot-BE, cùng API mà màn "Đơn giao của tôi" của web IKiot-FE dùng.

## Chạy

```bash
flutter pub get
flutter run                     # máy ảo Android gọi BE ở 10.0.2.2:3003, iOS ở localhost:3003
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3003   # máy thật: IP LAN của máy chạy BE
flutter analyze
flutter test
```

BE phải đang chạy (`pnpm run start:dev` trong IKiot-BE). Tài khoản đăng nhập là tài khoản STAFF mà cửa hàng
đã gán làm shipper cho đơn.

## Màn hình

- **Cần giao**: các lần giao chưa xong (`GET /shipments/mine`), chia nhóm theo việc phải làm tiếp.
- **Chi tiết lần giao**: lấy hàng, báo đang đi giao, đã giao (ảnh bằng chứng + thu tiền), giao không thành,
  màn mã QR cho khách quét.
- **Lịch sử**: lọc theo khoảng ngày và trạng thái, kèm số đã giao và tiền đã thu.
- **Thông báo**: hộp thư của mình; thông báo giao hàng mở thẳng lần giao.
- **Tôi**: hồ sơ, đổi ảnh đại diện, đổi mật khẩu, giao diện sáng/tối.

## Cấu trúc

```
lib/
  core/        mạng (ApiClient, ApiException), lưu token, cài đặt máy, widget dùng chung
  features/    auth, deliveries, history, notifications, profile
  router/      go_router + StatefulShellRoute (3 tab)
tool/          make-icons.js: dựng icon app từ logo của IKiot-FE
```

UI dùng [forui](https://forui.dev) 0.28, theme neutral (cùng tông shadcn của IKiot-FE).

## Lưu ý

- Sau khi shipper bấm "Đã lấy hàng", **kho phải xác nhận xuất kho** thì mới giao được (BE yêu cầu đơn ở
  trạng thái Đang vận chuyển). App hiện "Chờ kho xuất hàng" ở bước này.
- **Realtime**: app nghe sự kiện `entity:changed` của BE qua Socket.IO. Danh sách Cần giao, chi tiết lần giao,
  màn QR và Lịch sử tự tải lại khi cửa hàng gán đơn, kho xuất hàng hay tiền QR về. Màn QR vẫn hỏi lại BE mỗi
  15 giây làm dự phòng khi mất kết nối.
- Chưa có thông báo đẩy (cần cấu hình Firebase cho app).

## Đổi icon app

```bash
cd ../IKiot-FE && node ../IKiot-MOBILE/tool/make-icons.js "$PWD/node_modules/.pnpm/sharp@0.34.5/node_modules/sharp" ../IKiot-MOBILE/assets/icon
cd ../IKiot-MOBILE && dart run flutter_launcher_icons
```
