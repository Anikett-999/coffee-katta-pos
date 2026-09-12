class AddOnItem {
  final String id;
  final String name;
  final double price;
  final List<String> categoryIds; // If empty, applies to all categories
  final bool isAvailable;

  const AddOnItem({
    required this.id,
    required this.name,
    required this.price,
    this.categoryIds = const [],
    this.isAvailable = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'categoryIds': categoryIds,
    'isAvailable': isAvailable,
  };

  factory AddOnItem.fromJson(Map<String, dynamic> json, {String? id}) => AddOnItem(
    id: id ?? (json['id'] as String? ?? ''),
    name: json['name'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
    categoryIds: (json['categoryIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    isAvailable: json['isAvailable'] as bool? ?? true,
  );

  AddOnItem copyWith({
    String? id,
    String? name,
    double? price,
    List<String>? categoryIds,
    bool? isAvailable,
  }) => AddOnItem(
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
    categoryIds: categoryIds ?? this.categoryIds,
    isAvailable: isAvailable ?? this.isAvailable,
  );
}
