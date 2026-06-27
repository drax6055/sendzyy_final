import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iFloraBuzz/features/clients/data/models/group_model.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/group_repository.dart';

// Events
abstract class GroupsEvent {}

class FetchGroups extends GroupsEvent {}

class CreateGroup extends GroupsEvent {
  final String name;
  final List<String> clientIds;
  CreateGroup(this.name, this.clientIds);
}

class UpdateGroup extends GroupsEvent {
  final String id;
  final String name;
  final List<String> clientIds;
  UpdateGroup(this.id, this.name, this.clientIds);
}

class DeleteGroup extends GroupsEvent {
  final String id;
  DeleteGroup(this.id);
}

// States
abstract class GroupsState {}

class GroupsInitial extends GroupsState {}

class GroupsLoading extends GroupsState {}

class GroupsLoaded extends GroupsState {
  final List<GroupModel> groups;
  GroupsLoaded(this.groups);
}

class GroupsError extends GroupsState {
  final String message;
  GroupsError(this.message);
}

class GroupOperationSuccess extends GroupsState {
  final List<GroupModel> groups;
  GroupOperationSuccess(this.groups);
}

// Bloc
class GroupsBloc extends Bloc<GroupsEvent, GroupsState> {
  final GroupRepository _repository;

  GroupsBloc(this._repository) : super(GroupsInitial()) {
    on<FetchGroups>(_onFetchGroups);
    on<CreateGroup>(_onCreateGroup);
    on<UpdateGroup>(_onUpdateGroup);
    on<DeleteGroup>(_onDeleteGroup);
  }

  Future<void> _onFetchGroups(FetchGroups event, Emitter<GroupsState> emit) async {
    emit(GroupsLoading());
    try {
      final groups = await _repository.getGroups();
      emit(GroupsLoaded(groups));
    } catch (e) {
      emit(GroupsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateGroup(CreateGroup event, Emitter<GroupsState> emit) async {
    try {
      await _repository.createGroup(event.name, event.clientIds);
      final groups = await _repository.getGroups();
      emit(GroupOperationSuccess(groups));
    } catch (e) {
      emit(GroupsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onUpdateGroup(UpdateGroup event, Emitter<GroupsState> emit) async {
    try {
      await _repository.updateGroup(event.id, event.name, event.clientIds);
      final groups = await _repository.getGroups();
      emit(GroupOperationSuccess(groups));
    } catch (e) {
      emit(GroupsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onDeleteGroup(DeleteGroup event, Emitter<GroupsState> emit) async {
    try {
      await _repository.deleteGroup(event.id);
      final groups = await _repository.getGroups();
      emit(GroupOperationSuccess(groups));
    } catch (e) {
      emit(GroupsError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
