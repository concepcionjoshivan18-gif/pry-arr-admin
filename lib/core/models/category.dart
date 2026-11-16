class CategoryModel {
  final String id;
  final String name;

  CategoryModel({required this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, String docId) {
    return CategoryModel(
      id: docId,
      name: map['name'] ?? '',
    );
  }
}
