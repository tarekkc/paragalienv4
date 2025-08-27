class OrderHistory {
  final String id;
  final DateTime date;
  final bool isApproved;
  final double total;
  final String userId;
  final String? approvedBy;
  final String? approvedByName;
  final String? userName;
  final String? userEmail;
  final List<OrderItem> items;

  OrderHistory({
    required this.id,
    required this.date,
    required this.isApproved,
    required this.total,
    required this.userId,
    this.approvedBy,
    this.approvedByName,
    this.userName,
    this.userEmail,
    required this.items,
  });
  

  factory OrderHistory.empty() => OrderHistory(
        id: '',
        date: DateTime.now(),
        isApproved: false,
        total: 0.0,
        userId: '',
        items: [],
      );

  factory OrderHistory.fromJson(Map<String, dynamic> json) {
    return OrderHistory(
      id: json['id']?.toString() ?? '',
      date: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toString()),
      isApproved: _parseApprovalStatus(json['is_approved']),
      total: _parseDouble(json['total']),
      userId: json['user_id']?.toString() ?? '',
      approvedBy: json['approved_by']?.toString(),
      approvedByName: _parseApproverName(json),
      userName: json['user']?['name']?.toString(),
      userEmail: json['user']?['email']?.toString(),
      items: _parseItems(json['items']),
    );
  }

  static String? _parseApproverName(Map<String, dynamic> json) {
    return json['approver']?['name']?.toString() ??
           json['approved_by_profile']?['name']?.toString() ??
           json['admin_name']?.toString();
  }

  static bool _parseApprovalStatus(dynamic status) {
    if (status == null) return false;
    if (status is bool) return status;
    if (status is String) return status.toLowerCase() == 'true';
    return false;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static List<OrderItem> _parseItems(dynamic items) {
    if (items == null) return [];
    if (items is! List) return [];
    
    return items.map<OrderItem>((item) {
      try {
        if (item is Map<String, dynamic>) {
          return OrderItem.fromJson(item);
        }
        return OrderItem.empty();
      } catch (e) {
        print('Error parsing order item: $e');
        return OrderItem.empty();
      }
    }).toList();
  }

  OrderHistory copyWith({
    String? id,
    DateTime? date,
    bool? isApproved,
    double? total,
    String? userId,
    String? approvedBy,
    String? approvedByName,
    String? userName,
    String? userEmail,
    List<OrderItem>? items,
  }) {
    return OrderHistory(
      id: id ?? this.id,
      date: date ?? this.date,
      isApproved: isApproved ?? this.isApproved,
      total: total ?? this.total,
      userId: userId ?? this.userId,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      items: items ?? this.items,
    );
  }
}

class OrderItem {
  final String id;
  final String name;
  final double price;
  final double quantity;

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.empty() => OrderItem(
        id: '',
        name: 'Unknown',
        price: 0.0,
        quantity: 0.0,
      );

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['produit']?['name']?.toString() ?? 'Unknown',
      price: _parsePrice(json),
      quantity: _parseQuantity(json),
    );
  }

  static double _parsePrice(Map<String, dynamic> json) {
    final price = json['price'] ?? json['produit']?['price'];
    if (price == null) return 0.0;
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  static double _parseQuantity(Map<String, dynamic> json) {
    final quantity = json['quantity'];
    if (quantity == null) return 0.0;
    if (quantity is double) return quantity;
    if (quantity is int) return quantity.toDouble();
    if (quantity is String) {
      if (quantity.isEmpty) return 0.0;
      return double.tryParse(quantity) ?? 0.0;
    }
    return 0.0;
  }
}