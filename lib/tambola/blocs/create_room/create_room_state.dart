part of 'create_room_bloc.dart';

abstract class CreateRoomState extends Equatable {
  const CreateRoomState();
  @override
  List<Object?> get props => [];
}

class CreateRoomInitial extends CreateRoomState {
  final bool autoCall;
  final int autoCallInterval;
  final bool hasPassword;
  final bool obscurePassword;
  final int maxNumber;
  final bool suggestionMode;
  final bool soundEnabled;

  const CreateRoomInitial({
    this.autoCall = false,
    this.autoCallInterval = 5,
    this.hasPassword = false,
    this.obscurePassword = true,
    this.maxNumber = 100,
    this.suggestionMode = false,
    this.soundEnabled = false,
  });

  CreateRoomInitial copyWith({
    bool? autoCall,
    int? autoCallInterval,
    bool? hasPassword,
    bool? obscurePassword,
    int? maxNumber,
    bool? suggestionMode,
    bool? soundEnabled,
  }) =>
      CreateRoomInitial(
        autoCall: autoCall ?? this.autoCall,
        autoCallInterval: autoCallInterval ?? this.autoCallInterval,
        hasPassword: hasPassword ?? this.hasPassword,
        obscurePassword: obscurePassword ?? this.obscurePassword,
        maxNumber: maxNumber ?? this.maxNumber,
        suggestionMode: suggestionMode ?? this.suggestionMode,
        soundEnabled: soundEnabled ?? this.soundEnabled,
      );

  @override
  List<Object?> get props => [
        autoCall,
        autoCallInterval,
        hasPassword,
        obscurePassword,
        maxNumber,
        suggestionMode,
        soundEnabled,
      ];
}

class CreateRoomLoading extends CreateRoomState {}

class CreateRoomSuccess extends CreateRoomState {
  final String roomId;
  const CreateRoomSuccess(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class CreateRoomFailure extends CreateRoomState {
  final String message;
  const CreateRoomFailure(this.message);
  @override
  List<Object?> get props => [message];
}
