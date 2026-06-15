class Product {
  final int? id;
  final String name;
  final String initial;
  final String imageUrl;
  final int purchaseCount;
  final double price;
  final int stock;

  Product({
    this.id,
    required this.name,
    required this.initial,
    required this.imageUrl,
    required this.purchaseCount,
    required this.price,
    required this.stock,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'initial': initial,
      'imageUrl': imageUrl,
      'purchaseCount': purchaseCount,
      'price': price,
      'stock': stock,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      initial: map['initial'],
      imageUrl: map['imageUrl'],
      purchaseCount: map['purchaseCount'],
      price: map['price'],
      stock: map['stock'],
    );
  }
}
