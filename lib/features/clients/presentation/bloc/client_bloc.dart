import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sendzyy/features/clients/data/models/client_model.dart';
import 'package:sendzyy/features/clients/data/repositories/client_repository.dart';

// Events
abstract class ClientsEvent {}

class FetchClients extends ClientsEvent {
  final int page;
  final int limit;
  FetchClients({this.page = 1, this.limit = 50});
}

class SearchClients extends ClientsEvent {
  final String query;
  final int page;
  final int limit;
  SearchClients(this.query, {this.page = 1, this.limit = 50});
}

class CreateClient extends ClientsEvent {
  final ClientModel client;
  CreateClient(this.client);
}

class DeleteClient extends ClientsEvent {
  final String id;
  DeleteClient(this.id);
}

class DeleteClients extends ClientsEvent {
  final List<String> ids;
  DeleteClients(this.ids);
}

class BulkImportClients extends ClientsEvent {
  final List<ClientModel> clients;
  BulkImportClients(this.clients);
}

// States
abstract class ClientsState {}

class ClientsInitial extends ClientsState {}

class ClientsLoading extends ClientsState {}

class ClientsLoaded extends ClientsState {
  final List<ClientModel> filteredClients;
  final String searchQuery;
  final int currentPage;
  final int totalPages;
  final int totalClients;
  final int limit;

  ClientsLoaded({
    required this.filteredClients,
    required this.currentPage,
    required this.totalPages,
    required this.totalClients,
    required this.limit,
    this.searchQuery = '',
  });
}

class ClientsError extends ClientsState {
  final String message;
  ClientsError(this.message);
}

// Bloc
class ClientsBloc extends Bloc<ClientsEvent, ClientsState> {
  final ClientRepository _repository;

  ClientsBloc(this._repository) : super(ClientsInitial()) {
    on<FetchClients>(_onFetchClients);
    on<SearchClients>(_onSearchClients);
    on<CreateClient>(_onCreateClient);
    on<DeleteClient>(_onDeleteClient);
    on<DeleteClients>(_onDeleteClients);
    on<BulkImportClients>(_onBulkImportClients);
  }

  Future<void> _onFetchClients(FetchClients event, Emitter<ClientsState> emit) async {
    emit(ClientsLoading());
    await _loadAll(emit, page: event.page, limit: event.limit, search: '');
  }

  Future<void> _onSearchClients(SearchClients event, Emitter<ClientsState> emit) async {
    emit(ClientsLoading());
    await _loadAll(emit, page: event.page, limit: event.limit, search: event.query);
  }

  Future<void> _loadAll(
    Emitter<ClientsState> emit, {
    required int page,
    required int limit,
    required String search,
  }) async {
    try {
      final paginatedResult = await _repository.getClients(page: page, limit: limit, search: search);
      emit(ClientsLoaded(
        filteredClients: paginatedResult.clients,
        searchQuery: search,
        currentPage: paginatedResult.currentPage,
        totalPages: paginatedResult.totalPages,
        totalClients: paginatedResult.totalClients,
        limit: limit,
      ));
    } catch (e) {
      emit(ClientsError(e.toString()));
    }
  }

  Future<void> _onCreateClient(CreateClient event, Emitter<ClientsState> emit) async {
    final prev = state is ClientsLoaded ? state as ClientsLoaded : null;
    emit(ClientsLoading());
    try {
      await _repository.createClient(event.client);
      await _loadAll(
        emit,
        page: prev?.currentPage ?? 1,
        limit: prev?.limit ?? 50,
        search: prev?.searchQuery ?? '',
      );
    } catch (e) {
      emit(ClientsError(e.toString().replaceAll('Exception: ', '')));
      if (prev != null) emit(prev);
    }
  }

  Future<void> _onDeleteClient(DeleteClient event, Emitter<ClientsState> emit) async {
    final prev = state is ClientsLoaded ? state as ClientsLoaded : null;
    try {
      await _repository.deleteClient(event.id);
      await _loadAll(
        emit,
        page: prev?.currentPage ?? 1,
        limit: prev?.limit ?? 50,
        search: prev?.searchQuery ?? '',
      );
    } catch (e) {
      emit(ClientsError(e.toString().replaceAll('Exception: ', '')));
      if (prev != null) emit(prev);
    }
  }

  Future<void> _onDeleteClients(DeleteClients event, Emitter<ClientsState> emit) async {
    final prev = state is ClientsLoaded ? state as ClientsLoaded : null;
    emit(ClientsLoading());
    try {
      await _repository.deleteClients(event.ids);
      await _loadAll(
        emit,
        page: prev?.currentPage ?? 1,
        limit: prev?.limit ?? 50,
        search: prev?.searchQuery ?? '',
      );
    } catch (e) {
      emit(ClientsError(e.toString().replaceAll('Exception: ', '')));
      if (prev != null) emit(prev);
    }
  }

  Future<void> _onBulkImportClients(BulkImportClients event, Emitter<ClientsState> emit) async {
    final prev = state is ClientsLoaded ? state as ClientsLoaded : null;
    emit(ClientsLoading());
    try {
      await _repository.bulkImportClients(event.clients);
      await _loadAll(
        emit,
        page: 1,
        limit: prev?.limit ?? 50,
        search: '',
      );
    } catch (e) {
      emit(ClientsError(e.toString().replaceAll('Exception: ', '')));
      if (prev != null) emit(prev);
    }
  }
}

