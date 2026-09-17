import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/room_service.dart';

part 'create_room_event.dart';
part 'create_room_state.dart';

class CreateRoomBloc extends Bloc<CreateRoomEvent, CreateRoomState> {
  CreateRoomBloc() : super(const CreateRoomInitial()) {
    on<CreateRoomAutoCallToggled>(_onAutoCallToggled);
    on<CreateRoomAutoCallIntervalChanged>(_onIntervalChanged);
    on<CreateRoomPasswordToggled>(_onPasswordToggled);
    on<CreateRoomPasswordVisibilityToggled>(_onPasswordVisibility);
    on<CreateRoomMaxNumberChanged>(_onMaxNumberChanged);
    on<CreateRoomSubmitted>(_onSubmit);
    on<CreateRoomSuggestionModeToggled>(_onSuggestionModeToggled);
    on<CreateRoomSoundToggled>(_onSoundToggled);
    on<CreateRoomReset>(_onReset);
  }

  CreateRoomInitial get _current =>
      state is CreateRoomInitial ? state as CreateRoomInitial : const CreateRoomInitial();

  void _onAutoCallToggled(
      CreateRoomAutoCallToggled event, Emitter<CreateRoomState> emit) {
    emit(_current.copyWith(autoCall: event.value));
  }

  void _onIntervalChanged(
      CreateRoomAutoCallIntervalChanged event, Emitter<CreateRoomState> emit) {
    emit(_current.copyWith(autoCallInterval: event.seconds));
  }

  void _onPasswordToggled(
      CreateRoomPasswordToggled event, Emitter<CreateRoomState> emit) {
    emit(_current.copyWith(hasPassword: event.value));
  }

  void _onPasswordVisibility(
      CreateRoomPasswordVisibilityToggled event, Emitter<CreateRoomState> emit) {
    emit(_current.copyWith(obscurePassword: !_current.obscurePassword));
  }

  void _onMaxNumberChanged(
      CreateRoomMaxNumberChanged event, Emitter<CreateRoomState> emit) {
    emit(_current.copyWith(maxNumber: event.maxNumber));
  }

  void _onSuggestionModeToggled(
      CreateRoomSuggestionModeToggled event, Emitter<CreateRoomState> emit) {
    emit(_current.copyWith(suggestionMode: event.value));
  }

  void _onSoundToggled(
      CreateRoomSoundToggled event, Emitter<CreateRoomState> emit) {
    emit(_current.copyWith(soundEnabled: event.value));
  }

  Future<void> _onSubmit(
      CreateRoomSubmitted event, Emitter<CreateRoomState> emit) async {
    // Capture all settings BEFORE emitting CreateRoomLoading,
    // because emitting changes the state and _current would fall back
    // to default values (including suggestionMode = false).
    final settings = _current;
    emit(CreateRoomLoading());
    try {
      final room = await RoomService.createRoom(
        name: event.name.trim(),
        maxNumber: settings.maxNumber,
        password: (settings.hasPassword && event.password != null && event.password!.isNotEmpty)
            ? event.password
            : null,
        autoCall: settings.autoCall,
        autoCallInterval: settings.autoCallInterval,
        suggestionMode: settings.suggestionMode,
        soundEnabled: settings.soundEnabled,
      );
      if (room != null) {
        emit(CreateRoomSuccess(room.id));
      } else {
        emit(const CreateRoomFailure('Failed to create room'));
      }
    } catch (e) {
      emit(CreateRoomFailure(e.toString()));
    }
  }

  void _onReset(CreateRoomReset event, Emitter<CreateRoomState> emit) {
    emit(const CreateRoomInitial());
  }
}
