// lib/cardroomgame/blocs/create_room/create_card_room_bloc.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/card_room_model.dart';
import '../../services/card_room_service.dart';

part 'create_card_room_event.dart';
part 'create_card_room_state.dart';

class CreateCardRoomBloc
    extends Bloc<CreateCardRoomEvent, CreateCardRoomState> {
  CreateCardRoomBloc() : super(const CreateCardRoomInitial()) {
    on<CreateCardRoomNameChanged>(_onNameChanged);
    on<CreateCardRoomMaxPlayersChanged>(_onMaxPlayersChanged);
    on<CreateCardRoomCardsPerPlayerChanged>(_onCardsPerPlayerChanged);
    on<CreateCardRoomHostModeChanged>(_onHostModeChanged);
    on<CreateCardRoomSubmitted>(_onSubmitted);
    on<CreateCardRoomReset>(_onReset);
  }

  // ── Private helpers ────────────────────────────────────────────────────

  CreateCardRoomInitial get _initial =>
      state is CreateCardRoomInitial
          ? state as CreateCardRoomInitial
          : const CreateCardRoomInitial();

  // ── Handlers ──────────────────────────────────────────────────────────

  void _onNameChanged(
    CreateCardRoomNameChanged event,
    Emitter<CreateCardRoomState> emit,
  ) =>
      emit(_initial.copyWith(name: event.name));

  void _onMaxPlayersChanged(
    CreateCardRoomMaxPlayersChanged event,
    Emitter<CreateCardRoomState> emit,
  ) =>
      emit(_initial.copyWith(maxPlayers: event.value));

  void _onCardsPerPlayerChanged(
    CreateCardRoomCardsPerPlayerChanged event,
    Emitter<CreateCardRoomState> emit,
  ) =>
      emit(_initial.copyWith(cardsPerPlayer: event.value));

  void _onHostModeChanged(
    CreateCardRoomHostModeChanged event,
    Emitter<CreateCardRoomState> emit,
  ) =>
      emit(_initial.copyWith(hostMode: event.mode));

  Future<void> _onSubmitted(
    CreateCardRoomSubmitted event,
    Emitter<CreateCardRoomState> emit,
  ) async {
    final s = _initial;
    emit(CreateCardRoomLoading());
    try {
      final room = await CardRoomService.createRoom(
        name: s.name.trim(),
        maxPlayers: s.maxPlayers,
        cardsPerPlayer: s.cardsPerPlayer,
        hostMode: s.hostMode,
      );
      if (room != null) {
        emit(CreateCardRoomSuccess(room.id));
      } else {
        emit(const CreateCardRoomFailure('Failed to create room. Please try again.'));
      }
    } catch (e) {
      emit(CreateCardRoomFailure(e.toString()));
    }
  }

  void _onReset(
    CreateCardRoomReset event,
    Emitter<CreateCardRoomState> emit,
  ) =>
      emit(const CreateCardRoomInitial());
}
