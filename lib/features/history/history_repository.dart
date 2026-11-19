import '../../core/network/api_client.dart';
import '../../core/paged.dart';
import 'history_item.dart';

class HistoryRepository {
  const HistoryRepository(this._api);

  final ApiClient _api;

  Future<(Paged<HistoryItem>, HistorySummary)> list({
    required String from,
    required String to,
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final body = await _api.get(
      '/shipments/mine/history',
      query: {
        'from': from,
        'to': to,
        'page': page,
        'limit': limit,
        'status': ?status,
        'search': ?search,
      },
    ) as Map<String, dynamic>;
    return (
      Paged.fromJson(body, HistoryItem.fromJson),
      HistorySummary.fromJson(body['summary'] as Map<String, dynamic>?),
    );
  }
}
