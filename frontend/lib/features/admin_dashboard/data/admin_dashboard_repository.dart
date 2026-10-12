import 'package:dio/dio.dart';

import '../../../shared/services/dio_client.dart';
import '../domain/admin_dashboard_models.dart';

class AdminDashboardRepository {
  final Dio _dio = DioClient.instance;

  Future<DashboardKpis> getKpis() async {
    final r = await _dio.get('/admin/dashboard/kpis');
    return DashboardKpis.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<RevenuePoint>> getRevenue(String range) async {
    final r = await _dio.get('/admin/dashboard/revenue', queryParameters: {'range': range});
    return (r.data as List).map((e) => RevenuePoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<JobsByStatusPoint>> getJobsByStatus(String range) async {
    final r = await _dio.get('/admin/dashboard/jobs-by-status', queryParameters: {'range': range});
    return (r.data as List).map((e) => JobsByStatusPoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ActiveJobItem>> getActiveJobs({int limit = 12}) async {
    final r = await _dio.get('/admin/dashboard/active-jobs', queryParameters: {'limit': limit});
    return (r.data as List).map((e) => ActiveJobItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RecentJobItem>> getRecentJobs({String? filter, int limit = 20}) async {
    final r = await _dio.get(
      '/admin/dashboard/recent-jobs',
      queryParameters: {
        if (filter != null && filter != 'all') 'filter': filter,
        'limit': limit,
      },
    );
    return (r.data as List).map((e) => RecentJobItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TopUserItem>> getTopUsers(String range, {int limit = 5}) async {
    final r = await _dio.get(
      '/admin/dashboard/top-users',
      queryParameters: {'range': range, 'limit': limit},
    );
    return (r.data as List).map((e) => TopUserItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
