import 'package:file_picker/file_picker.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sendzyy/features/templates/data/models/app_entry.dart';
import 'package:sendzyy/features/whatsapp/data/repositories/whatsapp_repository.dart';

// Events
abstract class TemplateEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchTemplates extends TemplateEvent {}

class SearchTemplates extends TemplateEvent {
  final String query;
  SearchTemplates(this.query);
  @override
  List<Object> get props => [query];
}

class FilterByCategory extends TemplateEvent {
  final String? category; // null = show all
  FilterByCategory(this.category);
  @override
  List<Object> get props => [category ?? ''];
}

class CreateTemplate extends TemplateEvent {
  final String name;
  final String category;
  final String? subCategory;
  final String language;
  final String? header;
  final String? mediaSample;
  final String? variableType;
  final String body;
  final String? footer;
  final List<Map<String, dynamic>>? buttons;
  final PlatformFile? mediaFile;

  // validity period (Utility + Auth)
  final int? messageSendTtlSeconds;

  // auth-specific
  final String? codeDeliveryType;
  final List<AppEntry>? appEntries;
  final bool? addSecurityRecommendation;
  final bool? addExpiryTime;
  final int? codeExpirationMinutes;
  final bool? zeroTapTosAccepted;

  CreateTemplate({
    required this.name,
    required this.category,
    this.subCategory,
    required this.language,
    this.header,
    this.mediaSample,
    this.variableType,
    required this.body,
    this.footer,
    this.buttons,
    this.mediaFile,
    this.messageSendTtlSeconds,
    this.codeDeliveryType,
    this.appEntries,
    this.addSecurityRecommendation,
    this.addExpiryTime,
    this.codeExpirationMinutes,
    this.zeroTapTosAccepted,
  });

  @override
  List<Object> get props => [
    name,
    category,
    language,
    body,
    if (buttons != null) buttons!,
    if (messageSendTtlSeconds != null) messageSendTtlSeconds!,
    if (codeDeliveryType != null) codeDeliveryType!,
    if (appEntries != null) appEntries!,
    if (addSecurityRecommendation != null) addSecurityRecommendation!,
    if (addExpiryTime != null) addExpiryTime!,
    if (codeExpirationMinutes != null) codeExpirationMinutes!,
    if (zeroTapTosAccepted != null) zeroTapTosAccepted!,
  ];
}

class DeleteTemplate extends TemplateEvent {
  final String name;
  DeleteTemplate(this.name);
  @override
  List<Object> get props => [name];
}

// States
abstract class TemplateState extends Equatable {
  @override
  List<Object> get props => [];
}

class TemplateInitial extends TemplateState {}

class TemplateLoading extends TemplateState {}

class TemplateLoaded extends TemplateState {
  final List<dynamic> templates;
  final List<dynamic> filteredTemplates;
  final String? selectedCategory; // null = all
  final String searchQuery;

  TemplateLoaded(
    this.templates, {
    List<dynamic>? filteredTemplates,
    this.selectedCategory,
    this.searchQuery = '',
  }) : filteredTemplates = filteredTemplates ?? templates;

  @override
  List<Object> get props => [templates, filteredTemplates, searchQuery, selectedCategory ?? ''];

  /// Re-applies both search and category filters against [templates].
  TemplateLoaded withFilters({String? searchQuery, String? selectedCategory, bool clearCategory = false}) {
    final q = searchQuery ?? this.searchQuery;
    final cat = clearCategory ? null : (selectedCategory ?? this.selectedCategory);
    final filtered = templates.where((t) {
      final nameMatch = q.isEmpty || (t['name'] as String).toLowerCase().contains(q.toLowerCase());
      final catMatch = cat == null || (t['category'] as String?)?.toUpperCase() == cat.toUpperCase();
      return nameMatch && catMatch;
    }).toList();
    return TemplateLoaded(templates, filteredTemplates: filtered, selectedCategory: cat, searchQuery: q);
  }
}

class TemplateCreateSuccess extends TemplateState {}

class TemplateError extends TemplateState {
  final String message;
  TemplateError(this.message);
  @override
  List<Object> get props => [message];
}

// BLoC
class TemplateBloc extends Bloc<TemplateEvent, TemplateState> {
  final WhatsAppRepository _repository;

  TemplateBloc(this._repository) : super(TemplateInitial()) {
    on<FetchTemplates>((event, emit) async {
      emit(TemplateLoading());
      try {
        final templates = await _repository.fetchTemplates();
        emit(TemplateLoaded(templates));
      } catch (e) {
        emit(TemplateError(e.toString()));
      }
    });

    on<CreateTemplate>((event, emit) async {
      emit(TemplateLoading());
      try {
        final isAuth = event.category == 'AUTHENTICATION';
        final isUtilityOrAuth =
            event.category == 'UTILITY' || isAuth;

        final success = await _repository.createTemplate(
          name: event.name,
          category: event.category,
          subCategory: event.subCategory,
          language: event.language,
          header: event.header,
          mediaSample: event.mediaSample,
          variableType: event.variableType,
          body: event.body,
          footer: event.footer,
          buttons: event.buttons,
          mediaFile: event.mediaFile,
          // Pass TTL for UTILITY and AUTHENTICATION when non-null
          messageSendTtlSeconds:
              isUtilityOrAuth ? event.messageSendTtlSeconds : null,
          // Pass auth-specific fields only for AUTHENTICATION
          codeDeliveryType: isAuth ? event.codeDeliveryType : null,
          appEntries: isAuth ? event.appEntries : null,
          addSecurityRecommendation:
              isAuth ? event.addSecurityRecommendation : null,
          addExpiryTime: isAuth ? event.addExpiryTime : null,
          codeExpirationMinutes:
              isAuth ? event.codeExpirationMinutes : null,
          zeroTapTosAccepted: isAuth ? event.zeroTapTosAccepted : null,
        );
        if (success) {
          emit(TemplateCreateSuccess());
          add(FetchTemplates()); // Refresh list
        } else {
          emit(TemplateError('Failed to create template'));
        }
      } catch (e) {
        emit(TemplateError(e.toString()));
      }
    });

    on<DeleteTemplate>((event, emit) async {
      emit(TemplateLoading());
      try {
        final success = await _repository.deleteTemplate(event.name);
        if (success) {
          add(FetchTemplates()); // Refresh list
        } else {
          emit(TemplateError('Failed to delete template'));
        }
      } catch (e) {
        emit(TemplateError(e.toString()));
      }
    });

    on<SearchTemplates>((event, emit) {
      if (state is TemplateLoaded) {
        emit((state as TemplateLoaded).withFilters(searchQuery: event.query));
      }
    });

    on<FilterByCategory>((event, emit) {
      if (state is TemplateLoaded) {
        emit((state as TemplateLoaded).withFilters(
          selectedCategory: event.category,
          clearCategory: event.category == null,
        ));
      }
    });
  }
}

