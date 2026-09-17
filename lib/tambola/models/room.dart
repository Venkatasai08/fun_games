// lib/tambola/models/room.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ticket_model.dart';

class Room {
  final String id;
  final String name;
  final String hostId;
  final String hostUsername;
  final bool hasPassword;
  final int maxNumber;
  final String status;
  final List<int> calledNumbers;
  final int? lastCalled;
  final bool autoCall;
  final int autoCallInterval;
  final String? winnerId;
  final String? winnerUsername;
  final DateTime createdAt;
  final String? roomCode;
  final bool isPaused;
  final bool suggestionMode;
  final bool soundEnabled;
  int memberCount;
  bool isCurrentUserMember;

  Room({
    required this.id,
    required this.name,
    required this.hostId,
    required this.hostUsername,
    required this.hasPassword,
    required this.maxNumber,
    required this.status,
    required this.calledNumbers,
    this.lastCalled,
    required this.autoCall,
    required this.autoCallInterval,
    this.winnerId,
    this.winnerUsername,
    required this.createdAt,
    this.roomCode,
    this.isPaused = false,
    this.suggestionMode = false,
    this.soundEnabled = false,
    this.memberCount = 0,
    this.isCurrentUserMember = false,
  });

  factory Room.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Room(
      id: doc.id,
      name: map['name'] as String,
      hostId: map['host_id'] as String,
      hostUsername: map['host_username'] as String? ?? 'Unknown',
      hasPassword: map['password'] != null &&
          (map['password'] as String).isNotEmpty,
      maxNumber: map['max_number'] as int? ?? 90,
      status: map['status'] as String? ?? 'waiting',
      calledNumbers: map['called_numbers'] != null
          ? List<int>.from(map['called_numbers'] as List)
          : [],
      lastCalled: map['last_called'] as int?,
      autoCall: map['auto_call'] as bool? ?? false,
      autoCallInterval: map['auto_call_interval'] as int? ?? 5,
      winnerId: map['winner_id'] as String?,
      winnerUsername: map['winner_username'] as String?,
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      roomCode: map['room_code'] as String?,
      isPaused: map['is_paused'] as bool? ?? false,
      suggestionMode: map['suggestion_mode'] as bool? ?? false,
      soundEnabled: map['sound_enabled'] as bool? ?? false,
      memberCount: map['member_count'] as int? ?? 0,
    );
  }

  Room copyWith({
    String? status,
    List<int>? calledNumbers,
    int? lastCalled,
    int? memberCount,
    String? winnerId,
    String? winnerUsername,
    bool? isPaused,
    // live-editable settings
    bool? autoCall,
    int? autoCallInterval,
    bool? suggestionMode,
    bool? soundEnabled,
  }) {
    return Room(
      id: id,
      name: name,
      hostId: hostId,
      hostUsername: hostUsername,
      hasPassword: hasPassword,
      maxNumber: maxNumber,
      status: status ?? this.status,
      calledNumbers: calledNumbers ?? this.calledNumbers,
      lastCalled: lastCalled ?? this.lastCalled,
      autoCall: autoCall ?? this.autoCall,
      autoCallInterval: autoCallInterval ?? this.autoCallInterval,
      winnerId: winnerId ?? this.winnerId,
      winnerUsername: winnerUsername ?? this.winnerUsername,
      createdAt: createdAt,
      roomCode: roomCode,
      isPaused: isPaused ?? this.isPaused,
      suggestionMode: suggestionMode ?? this.suggestionMode,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  int get totalRows => (maxNumber / 10).ceil();

  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
  bool get isCancelled => status == 'cancelled';
}

class RoomMember {
  final String id;
  final String roomId;
  final String userId;
  final String username;
  final List<List<int?>> ticket;
  final List<int> markedNumbers;
  final bool hasClaimedHousie;

  RoomMember({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.ticket,
    required this.markedNumbers,
    required this.hasClaimedHousie,
  });

  /// Ticket is stored as a flat list of 30 ints (0 = blank cell).
  factory RoomMember.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    final rawTicket = map['ticket'] as List<dynamic>;
    final ticket = TicketGenerator.fromJson(rawTicket);

    return RoomMember(
      id: doc.id,
      roomId: map['room_id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String? ?? 'Unknown',
      ticket: ticket,
      markedNumbers: map['marked_numbers'] != null
          ? List<int>.from(map['marked_numbers'] as List)
          : [],
      hasClaimedHousie: map['has_claimed_housie'] as bool? ?? false,
    );
  }
}
