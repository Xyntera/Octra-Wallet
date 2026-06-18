/// Direction of a bridge operation.
enum BridgeDirection { wrap, unwrap }

/// Lifecycle of a bridge operation.
enum BridgeStatus {
  /// Octra lock submitted (wrap) / burn submitted (unwrap), awaiting the bridge.
  pending,

  /// Wrap only: the epoch header is on Ethereum; wOCT can be claimed.
  claimable,

  /// A signed Ethereum action (claim/approve/burn) is in flight.
  submitting,

  /// Completed (wOCT claimed, or OCT released).
  completed,

  /// Failed or timed out.
  failed,
}

/// A persisted record of one bridge operation (history + resumable claim).
class BridgeRecord {
  final String id;
  final BridgeDirection direction;

  /// Raw amount in micro units (OCT and wOCT share 6 decimals, 1:1).
  final String amountRaw;

  /// Ethereum address (wrap recipient / unwrap source).
  final String ethAddress;

  /// Octra address (wrap source / unwrap recipient).
  final String octraAddress;

  // Wrap (OCT -> wOCT)
  final String? lockTxHash;
  final String? epoch;
  final String? claimTxHash;

  // Unwrap (wOCT -> OCT)
  final String? approveTxHash;
  final String? burnTxHash;

  BridgeStatus status;
  String? error;
  final int createdAt;

  BridgeRecord({
    required this.id,
    required this.direction,
    required this.amountRaw,
    required this.ethAddress,
    required this.octraAddress,
    this.lockTxHash,
    this.epoch,
    this.claimTxHash,
    this.approveTxHash,
    this.burnTxHash,
    this.status = BridgeStatus.pending,
    this.error,
    required this.createdAt,
  });

  BridgeRecord copyWith({
    String? lockTxHash,
    String? epoch,
    String? claimTxHash,
    String? approveTxHash,
    String? burnTxHash,
    BridgeStatus? status,
    String? error,
  }) {
    return BridgeRecord(
      id: id,
      direction: direction,
      amountRaw: amountRaw,
      ethAddress: ethAddress,
      octraAddress: octraAddress,
      lockTxHash: lockTxHash ?? this.lockTxHash,
      epoch: epoch ?? this.epoch,
      claimTxHash: claimTxHash ?? this.claimTxHash,
      approveTxHash: approveTxHash ?? this.approveTxHash,
      burnTxHash: burnTxHash ?? this.burnTxHash,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'direction': direction.name,
        'amountRaw': amountRaw,
        'ethAddress': ethAddress,
        'octraAddress': octraAddress,
        'lockTxHash': lockTxHash,
        'epoch': epoch,
        'claimTxHash': claimTxHash,
        'approveTxHash': approveTxHash,
        'burnTxHash': burnTxHash,
        'status': status.name,
        'error': error,
        'createdAt': createdAt,
      };

  factory BridgeRecord.fromJson(Map<String, dynamic> j) => BridgeRecord(
        id: j['id'].toString(),
        direction: BridgeDirection.values.firstWhere(
          (d) => d.name == j['direction'],
          orElse: () => BridgeDirection.wrap,
        ),
        amountRaw: j['amountRaw']?.toString() ?? '0',
        ethAddress: j['ethAddress']?.toString() ?? '',
        octraAddress: j['octraAddress']?.toString() ?? '',
        lockTxHash: j['lockTxHash']?.toString(),
        epoch: j['epoch']?.toString(),
        claimTxHash: j['claimTxHash']?.toString(),
        approveTxHash: j['approveTxHash']?.toString(),
        burnTxHash: j['burnTxHash']?.toString(),
        status: BridgeStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => BridgeStatus.pending,
        ),
        error: j['error']?.toString(),
        createdAt:
            int.tryParse(j['createdAt']?.toString() ?? '') ?? 0,
      );
}
