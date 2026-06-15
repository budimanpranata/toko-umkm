class FinancialRecordModel {
  final int? id;
  final String type;
  final double amount;
  final String description;
  final String date;

  FinancialRecordModel({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
  });

  factory FinancialRecordModel.fromMap(Map<String, dynamic> map) {
    return FinancialRecordModel(
      id: map['id'],
      type: map['type'],
      amount: map['amount'],
      description: map['description'],
      date: map['date'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'date': date,
    };
  }
}

class TransactionItemModel {
  final int? id;
  final int transactionId;
  final int productId;
  final String productName;
  final int quantity;
  final double price;

  TransactionItemModel({
    this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory TransactionItemModel.fromMap(Map<String, dynamic> map) {
    return TransactionItemModel(
      id: map['id'],
      transactionId: map['transaction_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      quantity: map['quantity'],
      price: map['price'],
    );
  }
}

class TransactionModel {
  final int? id;
  final String date;
  final int totalItems;
  final double totalPrice;
  final List<TransactionItemModel>? items;

  TransactionModel({
    this.id,
    required this.date,
    required this.totalItems,
    required this.totalPrice,
    this.items,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      date: map['date'],
      totalItems: map['total_items'],
      totalPrice: map['total_price'],
    );
  }
}
