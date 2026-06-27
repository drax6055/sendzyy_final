import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/clients/data/models/client_model.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/client_repository.dart';

// Events
abstract class ClientsEvent {}

class FetchClients extends ClientsEvent {}

class SearchClients extends ClientsEvent {
  final String query;
  SearchClients(this.query);
}

class CreateClient extends ClientsEvent {
  final ClientModel client;
  CreateClient(this.client);
}

class DeleteClient extends ClientsEvent {
  final String id;
  DeleteClient(this.id);
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

  ClientsLoaded({
    required this.filteredClients,
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
    on<BulkImportClients>(_onBulkImportClients);
  }

  Future<void> _onFetchClients(FetchClients event, Emitter<ClientsState> emit) async {
    emit(ClientsLoading());
    await _loadAll(emit, search: '');
  }

  Future<void> _onSearchClients(SearchClients event, Emitter<ClientsState> emit) async {
    emit(ClientsLoading());
    await _loadAll(emit, search: event.query);
  }

  Future<void> _loadAll(Emitter<ClientsState> emit, {required String search}) async {
    try {
      final clients = await _repository.getClients(search: search);
      emit(ClientsLoaded(filteredClients: clients, searchQuery: search));
    } catch (e) {
      emit(ClientsError(e.toString()));
    }
  }

  Future<void> _onCreateClient(CreateClient event, Emitter<ClientsState> emit) async {
    final prev = state is ClientsLoaded ? state as ClientsLoaded : null;
    emit(ClientsLoading());
    try {
      await _repository.createClient(event.client);
      await _loadAll(emit, search: prev?.searchQuery ?? '');
    } catch (e) {
      emit(ClientsError(e.toString().replaceAll('Exception: ', '')));
      if (prev != null) emit(prev);
    }
  }

  Future<void> _onDeleteClient(DeleteClient event, Emitter<ClientsState> emit) async {
    final prev = state is ClientsLoaded ? state as ClientsLoaded : null;
    try {
      await _repository.deleteClient(event.id);
      await _loadAll(emit, search: prev?.searchQuery ?? '');
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
      await _loadAll(emit, search: prev?.searchQuery ?? '');
    } catch (e) {
      emit(ClientsError(e.toString().replaceAll('Exception: ', '')));
      if (prev != null) emit(prev);
    }
  }
}
