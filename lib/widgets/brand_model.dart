class BrandModel {
  final int id;
  final String name;
  final int categoryId;

  BrandModel({required this.id, required this.name, required this.categoryId});

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'],
      name: json['name'],
      categoryId: json['category_id'],
    );
  }
}
