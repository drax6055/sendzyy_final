import 'dart:async';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/chat/data/services/socket_service.dart';

// Events
abstract class ReportEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchReportHistory extends ReportEvent {
  final bool isRefresh;
  FetchReportHistory({this.isRefresh = false});

  @override
  List<Object?> get props => [isRefresh];
}

class FetchNextPageReports extends ReportEvent {}

class DownloadReport extends ReportEvent {
  final DateTimeRange dateRange;
  DownloadReport(this.dateRange);
  @override
  List<Object?> get props => [dateRange];
}

class ReportsUpdated extends ReportEvent {
  final List<Map<String, dynamic>> campaigns;
  ReportsUpdated(this.campaigns);
  @override
  List<Object?> get props => [campaigns];
}

// States
abstract class ReportState extends Equatable {
  const ReportState();
  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportLoaded extends ReportState {
  final List<Map<String, dynamic>> campaigns;
  final int totalSent;
  final int totalDelivered;
  final int totalRead;
  final int totalFailed;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;

  const ReportLoaded({
    required this.campaigns,
    required this.totalSent,
    required this.totalDelivered,
    required this.totalRead,
    required this.totalFailed,
    this.currentPage = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  ReportLoaded copyWith({
    List<Map<String, dynamic>>? campaigns,
    int? totalSent,
    int? totalDelivered,
    int? totalRead,
    int? totalFailed,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ReportLoaded(
      campaigns: campaigns ?? this.campaigns,
      totalSent: totalSent ?? this.totalSent,
      totalDelivered: totalDelivered ?? this.totalDelivered,
      totalRead: totalRead ?? this.totalRead,
      totalFailed: totalFailed ?? this.totalFailed,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
        campaigns,
        totalSent,
        totalDelivered,
        totalRead,
        totalFailed,
        currentPage,
        hasMore,
        isLoadingMore,
      ];
}

class ReportError extends ReportState {
  final String message;
  const ReportError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final SocketService _socketService;
  final Dio _dio;
  StreamSubscription? _reportSubscription;

  ReportBloc(this._socketService, this._dio) : super(ReportInitial()) {
    on<FetchReportHistory>((event, emit) async {
      if (!event.isRefresh) {
        emit(ReportLoading());
      }
      await _fetchInitialPage(emit);
      await _reportSubscription?.cancel();
      _reportSubscription = _socketService.getCampaignsStream().listen(
        (campaigns) => add(ReportsUpdated(campaigns)),
        onError: (_) {},
      );
    });

    on<FetchNextPageReports>(_onFetchNextPage);

    on<ReportsUpdated>((event, emit) {
      if (state is ReportLoaded) {
        final currentLoaded = state as ReportLoaded;
        emit(currentLoaded.copyWith(campaigns: event.campaigns));
      }
    });

    on<DownloadReport>((event, emit) async {});
  }

  Future<void> _fetchInitialPage(Emitter<ReportState> emit) async {
    try {
      final response = await _dio.get('/campaigns', queryParameters: {
        'page': 1,
        'limit': 20,
      });

      if (response.statusCode != 200 || response.data is! Map) {
        emit(ReportError('Failed to load campaigns'));
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final campaigns = List<Map<String, dynamic>>.from(
        (data['campaigns'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );

      final totalStats = data['totalStats'] as Map<String, dynamic>?;
      int sent = (totalStats?['totalSent'] as num? ?? 0).toInt();
      int delivered = (totalStats?['totalDelivered'] as num? ?? 0).toInt();
      int read = (totalStats?['totalRead'] as num? ?? 0).toInt();
      int failed = (totalStats?['totalFailed'] as num? ?? 0).toInt();

      // Fallback if totalStats is missing or 0 but campaigns exist
      if (totalStats == null && campaigns.isNotEmpty) {
        for (var c in campaigns) {
          sent += (c['totalCount'] as num? ?? c['successCount'] as num? ?? 0).toInt();
          delivered += (c['deliveredCount'] as num? ?? 0).toInt();
          read += (c['readCount'] as num? ?? 0).toInt();
          failed += (c['failureCount'] as num? ?? 0).toInt();
        }
      }

      final hasMore = data['hasMore'] == true;

      emit(ReportLoaded(
        campaigns: campaigns,
        totalSent: sent,
        totalDelivered: delivered,
        totalRead: read,
        totalFailed: failed,
        currentPage: 1,
        hasMore: hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(ReportError('Failed to load campaigns: $e'));
    }
  }

  Future<void> _onFetchNextPage(
    FetchNextPageReports event,
    Emitter<ReportState> emit,
  ) async {
    if (state is! ReportLoaded) return;
    final currentState = state as ReportLoaded;
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = currentState.currentPage + 1;
      final response = await _dio.get('/campaigns', queryParameters: {
        'page': nextPage,
        'limit': 20,
      });

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final newCampaigns = List<Map<String, dynamic>>.from(
          (data['campaigns'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
        );

        final hasMore = data['hasMore'] == true;
        final updatedList = List<Map<String, dynamic>>.from(currentState.campaigns)
          ..addAll(newCampaigns);

        emit(currentState.copyWith(
          campaigns: updatedList,
          currentPage: nextPage,
          hasMore: hasMore,
          isLoadingMore: false,
        ));
      } else {
        emit(currentState.copyWith(isLoadingMore: false));
      }
    } catch (_) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  @override
  Future<void> close() {
    _reportSubscription?.cancel();
    return super.close();
  }
}
