/// Spec section 16. There is no "failed": with no route, a message waits.
enum DeliveryStatus { queued, propagating, delivered, read }

class MeshMessage {
  const MeshMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.status = DeliveryStatus.delivered,
  });

  final String id;
  final String channelId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final DeliveryStatus status;

  MeshMessage copyWith({DeliveryStatus? status}) => MeshMessage(
        id: id,
        channelId: channelId,
        senderId: senderId,
        senderName: senderName,
        text: text,
        timestamp: timestamp,
        status: status ?? this.status,
      );
}
