import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';

class PaginatedClients {
  final List<ClientModel> clients;
  final int currentPage;
  final int totalPages;
  final int totalClients;

  PaginatedClients({
    required this.clients,
    required this.currentPage,
    required this.totalPages,
    required this.totalClients,
  });

  factory PaginatedClients.fromJson(Map<String, dynamic> json) {
    final clientsList = (json['clients'] as List?)
            ?.map((item) => ClientModel.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];
    return PaginatedClients(
      clients: clientsList,
      currentPage: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      totalClients: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
