import '../../core/network/api_client.dart';
import 'shipment_detail.dart';
import 'shipment_summary.dart';

/// Mọi việc của shipper trên một lần giao. Mỗi thao tác ghi trả lại chi tiết mới nhất từ BE,
/// để màn hiện ngay kết quả (vd. mã QR sau khi giao) mà không phải tải lại.
class DeliveriesRepository {
  const DeliveriesRepository(this._api);

  final ApiClient _api;

  /// Các lần giao chưa kết thúc mà mình là shipper (`GET /shipments/mine`).
  Future<List<ShipmentSummary>> mine() async {
    final data = await _api.get('/shipments/mine') as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(ShipmentSummary.fromJson)
        .toList();
  }

  Future<ShipmentDetail> detail(String id) async =>
      _detail(await _api.get('/shipments/$id'));

  /// Tới kho nhận hàng: CREATED → PICKED_UP. Kho còn phải xác nhận xuất kho thì mới đi giao được.
  Future<ShipmentDetail> pickUp(String id, {String? note}) async =>
      _detail(await _api.post('/shipments/$id/pick-up', body: {'note': ?note}));

  /// Ghi nhật trình "Đang đi giao". Không bắt buộc: BE cho giao ngay từ IN_TRANSIT.
  Future<ShipmentDetail> markOutForDelivery(String id) async => _detail(
    await _api.post(
      '/shipments/$id/events',
      body: {'status': ShipmentStatus.outForDelivery},
    ),
  );

  /// Giao xong. `collectedAmount` phải đúng bằng số còn phải thu, BE từ chối số khác.
  Future<ShipmentDetail> deliver(
    String id, {
    required List<String> proofPhotoUrls,
    required String paymentMethod,
    required num collectedAmount,
    String? note,
  }) async => _detail(
    await _api.post(
      '/shipments/$id/deliver',
      body: {
        'proofPhotoUrls': proofPhotoUrls,
        'paymentMethod': paymentMethod,
        'collectedAmount': collectedAmount,
        'note': ?note,
      },
    ),
  );

  /// Giao không thành, lý do bắt buộc. Đơn vẫn ở chỗ shipper, giao lại được.
  Future<ShipmentDetail> fail(String id, String note) async =>
      _detail(await _api.post('/shipments/$id/fail', body: {'note': note}));

  /// Khách không chuyển khoản QR: huỷ mã, ghi đã thu tiền mặt đúng số còn lại.
  Future<ShipmentDetail> payCash(String id, {String? note}) async => _detail(
    await _api.post('/shipments/$id/pay-cash', body: {'note': ?note}),
  );

  /// Mã QR hết hạn: tạo mã mới. Còn hạn thì BE trả lại mã cũ.
  Future<ShipmentDetail> reissueQr(String id) async =>
      _detail(await _api.post('/shipments/$id/reissue-qr'));

  /// Tải một ảnh bằng chứng lên, trả URL để gửi kèm `deliver`.
  Future<String> uploadPhoto(String filePath) async {
    final data =
        await _api.upload('/uploads', filePath) as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Cửa hàng đã liên kết SePay chưa (`GET /tenant/me` → `hasSepayKey`). Chưa thì không thu QR được.
  /// Đọc không được thì trả `null`: để BE tự từ chối, như IKiot-FE.
  Future<bool?> canCollectByQr() async {
    try {
      final data = await _api.get('/tenant/me') as Map<String, dynamic>;
      return data['hasSepayKey'] as bool?;
    } catch (_) {
      return null;
    }
  }

  ShipmentDetail _detail(dynamic data) =>
      ShipmentDetail.fromJson(data as Map<String, dynamic>);
}
