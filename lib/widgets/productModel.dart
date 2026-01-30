class Product {
  final int id;
  final String name;
  final String category;
  final double price;
  final String unit;
  final String image;
  final String description;
  final String detailedDescription;
  final double deliveryPricePerKm;
  final String dealer;
  final String dealerLocation;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    required this.image,
    required this.description,
    required this.detailedDescription,
    required this.deliveryPricePerKm,
    required this.dealer,
    required this.dealerLocation,
  });
}
