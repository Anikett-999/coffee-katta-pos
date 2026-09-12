class CustomizationGroup {
  final String id;
  final String name; // e.g. "SUGAR LEVEL", "ICE / CHILL LEVEL", "PREPARATION STYLE"
  final List<String> options; // e.g. ["No Sugar", "Less Sugar", "Normal Sugar"]
  final String defaultOption; // e.g. "Normal Sugar"
  final List<String> categoryIds; // Empty = applies to all categories; or specific categories
  final bool isAvailable;

  const CustomizationGroup({
    required this.id,
    required this.name,
    required this.options,
    this.defaultOption = '',
    this.categoryIds = const [],
    this.isAvailable = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'options': options,
    'defaultOption': defaultOption,
    'categoryIds': categoryIds,
    'isAvailable': isAvailable,
  };

  factory CustomizationGroup.fromJson(Map<String, dynamic> json, {String? id}) => CustomizationGroup(
    id: id ?? (json['id'] as String? ?? ''),
    name: json['name'] as String? ?? '',
    options: (json['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    defaultOption: json['defaultOption'] as String? ?? '',
    categoryIds: (json['categoryIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    isAvailable: json['isAvailable'] as bool? ?? true,
  );

  CustomizationGroup copyWith({
    String? id,
    String? name,
    List<String>? options,
    String? defaultOption,
    List<String>? categoryIds,
    bool? isAvailable,
  }) => CustomizationGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    options: options ?? this.options,
    defaultOption: defaultOption ?? this.defaultOption,
    categoryIds: categoryIds ?? this.categoryIds,
    isAvailable: isAvailable ?? this.isAvailable,
  );
}
