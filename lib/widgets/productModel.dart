class ProductModel {
  final int id;
  final String name;
  final String shortDescription;
  final String detailedDescription;
  final String unit;
  final List<String> specifications;

  ProductModel({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.detailedDescription,
    required this.unit,
    required this.specifications,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'],
      shortDescription: json['short_description'] ?? '',
      detailedDescription: json['detailed_description'] ?? '',
      unit: json['unit'] ?? '',
      specifications: (json['specifications'] ?? [])
          .map<String>((spec) => spec['value'].toString())
          .toList(),
    );
  }
}
