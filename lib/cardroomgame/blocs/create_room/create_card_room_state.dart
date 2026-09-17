// lib/cardroomgame/blocs/create_room/create_card_room_state.dart
part of 'create_card_room_bloc.dart';

abstract class CreateCardRoomState extends Equatable {
  const CreateCardRoomState();
  @override
  List<Object?> get props => [];
}

// ── Form state (default / in-progress editing) ────────────────────────────

class CreateCardRoomInitial extends CreateCardRoomState {
  final String name;
  final int maxPlayers;
  final int cardsPerPlayer;
  final HostMode hostMode;

  const CreateCardRoomInitial({
    this.name = '',
    this.maxPlayers = 4,
    this.cardsPerPlayer = 13,
    this.hostMode = HostMode.player,
  });

  CreateCardRoomInitial copyWith({
    String? name,
    int? maxPlayers,
    int? cardsPerPlayer,
    HostMode? hostMode,
  }) =>
      CreateCardRoomInitial(
        name: name ?? this.name,
        maxPlayers: maxPlayers ?? this.maxPlayers,
        cardsPerPlayer: cardsPerPlayer ?? this.cardsPerPlayer,
        hostMode: hostMode ?? this.hostMode,
      );

  @override
  List<Object?> get props => [name, maxPlayers, cardsPerPlayer, hostMode];
}

// ── Async states ──────────────────────────────────────────────────────────

class CreateCardRoomLoading extends CreateCardRoomState {}

class CreateCardRoomSuccess extends CreateCardRoomState {
  final String roomId;
  const CreateCardRoomSuccess(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class CreateCardRoomFailure extends CreateCardRoomState {
  final String message;
  const CreateCardRoomFailure(this.message);
  @override
  List<Object?> get props => [message];
}
