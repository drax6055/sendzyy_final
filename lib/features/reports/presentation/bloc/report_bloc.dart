import 'dart:async';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/chat/data/services/socket_service.dart';

// Events
abstract class ReportEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchReportHistory extends ReportEvent {}

class DownloadReport extends ReportEvent {
  final DateTimeRange dateRange;
  DownloadReport(this.dateRange);
  @override
  List<Object> get props => [dateRange];
}

class ReportsUpdated extends ReportEvent {
  final List<Map<String, dynamic>> campaigns;
  ReportsUpdated(this.campaigns);
  @override
  List<Object> get props => [campaigns];
}

// States
abstract class ReportState extends Equatable {
  @override
  List<Object> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportLoaded extends ReportState {
  final List<Map<String, dynamic>> campaigns;
  final int totalSent;
  final int totalDelivered;
  final int totalRead;
  final int totalFailed;

  ReportLoaded({
    required this.campaigns,
    required this.totalSent,
    required this.totalDelivered,
    required this.totalRead,
    required this.totalFailed,
  });

  @override
  List<Object> get props => [campaigns, totalSent, totalDelivered, totalRead, totalFailed];
}

class ReportError extends ReportState {
  final String message;
  ReportError(this.message);
  @override
  List<Object> get props => [message];
}

// BLoC
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final SocketService _socketService;
  final Dio _dio;
  StreamSubscription? _reportSubscription;

  ReportBloc(this._socketService, this._dio) : super(ReportInitial()) {
    on<FetchReportHistory>((event, emit) async {
      emit(ReportLoading());
      await _fetchAll(emit);
      await _reportSubscription?.cancel();
      _reportSubscription = _socketService.getCampaignsStream().listen(
        (campaigns) => add(ReportsUpdated(campaigns)),
        onError: (_) {},
      );
    });

    on<ReportsUpdated>((event, emit) {
      _emitLoaded(emit, event.campaigns);
    });

    on<DownloadReport>((event, emit) async {});
  }

  Future<void> _fetchAll(Emitter<ReportState> emit) async {
    try {
      final campaignsResponse = await _dio.get('/campaigns');
      if (campaignsResponse.statusCode != 200 || campaignsResponse.data is! Map) {
        emit(ReportError('Failed to load campaigns'));
        return;
      }
      final data = campaignsResponse.data as Map<String, dynamic>;
      final campaigns = List<Map<String, dynamic>>.from(
        (data['campaigns'] as List).map((e) => Map<String, dynamic>.from(e)),
      );

      _emitLoaded(emit, campaigns);
    } catch (_) {
      emit(ReportError('Failed to load campaigns'));
    }
  }

  void _emitLoaded(Emitter<ReportState> emit, List<Map<String, dynamic>> campaigns) {
    int sent = 0, delivered = 0, read = 0, failed = 0;
    for (var c in campaigns) {
      sent += (c['successCount'] as num? ?? 0).toInt();
      delivered += (c['deliveredCount'] as num? ?? 0).toInt();
      read += (c['readCount'] as num? ?? 0).toInt();
      failed += (c['failureCount'] as num? ?? 0).toInt();
    }
    emit(ReportLoaded(
      campaigns: campaigns,
      totalSent: sent,
      totalDelivered: delivered,
      totalRead: read,
      totalFailed: failed,
    ));
  }

  @override
  Future<void> close() {
    _reportSubscription?.cancel();
    return super.close();
  }
}
