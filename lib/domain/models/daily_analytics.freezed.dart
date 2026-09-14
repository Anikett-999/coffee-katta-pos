// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_analytics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DailyAnalytics _$DailyAnalyticsFromJson(Map<String, dynamic> json) {
  return _DailyAnalytics.fromJson(json);
}

/// @nodoc
mixin _$DailyAnalytics {
  double get totalSales => throw _privateConstructorUsedError;
  int get totalBills => throw _privateConstructorUsedError;
  double get totalDiscount => throw _privateConstructorUsedError;
  double get extraCharges => throw _privateConstructorUsedError;
  Map<String, ItemStat> get itemStats => throw _privateConstructorUsedError;
  Map<String, HourStat> get hourlyStats => throw _privateConstructorUsedError;
  Map<String, double> get paymentStats => throw _privateConstructorUsedError;
  Map<String, double> get categoryStats => throw _privateConstructorUsedError;
  Map<String, double> get deliveryMethodsStats =>
      throw _privateConstructorUsedError;
  Map<String, double> get userStats => throw _privateConstructorUsedError;

  /// Serializes this DailyAnalytics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DailyAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyAnalyticsCopyWith<DailyAnalytics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyAnalyticsCopyWith<$Res> {
  factory $DailyAnalyticsCopyWith(
    DailyAnalytics value,
    $Res Function(DailyAnalytics) then,
  ) = _$DailyAnalyticsCopyWithImpl<$Res, DailyAnalytics>;
  @useResult
  $Res call({
    double totalSales,
    int totalBills,
    double totalDiscount,
    double extraCharges,
    Map<String, ItemStat> itemStats,
    Map<String, HourStat> hourlyStats,
    Map<String, double> paymentStats,
    Map<String, double> categoryStats,
    Map<String, double> deliveryMethodsStats,
    Map<String, double> userStats,
  });
}

/// @nodoc
class _$DailyAnalyticsCopyWithImpl<$Res, $Val extends DailyAnalytics>
    implements $DailyAnalyticsCopyWith<$Res> {
  _$DailyAnalyticsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalSales = null,
    Object? totalBills = null,
    Object? totalDiscount = null,
    Object? extraCharges = null,
    Object? itemStats = null,
    Object? hourlyStats = null,
    Object? paymentStats = null,
    Object? categoryStats = null,
    Object? deliveryMethodsStats = null,
    Object? userStats = null,
  }) {
    return _then(
      _value.copyWith(
            totalSales: null == totalSales
                ? _value.totalSales
                : totalSales // ignore: cast_nullable_to_non_nullable
                      as double,
            totalBills: null == totalBills
                ? _value.totalBills
                : totalBills // ignore: cast_nullable_to_non_nullable
                      as int,
            totalDiscount: null == totalDiscount
                ? _value.totalDiscount
                : totalDiscount // ignore: cast_nullable_to_non_nullable
                      as double,
            extraCharges: null == extraCharges
                ? _value.extraCharges
                : extraCharges // ignore: cast_nullable_to_non_nullable
                      as double,
            itemStats: null == itemStats
                ? _value.itemStats
                : itemStats // ignore: cast_nullable_to_non_nullable
                      as Map<String, ItemStat>,
            hourlyStats: null == hourlyStats
                ? _value.hourlyStats
                : hourlyStats // ignore: cast_nullable_to_non_nullable
                      as Map<String, HourStat>,
            paymentStats: null == paymentStats
                ? _value.paymentStats
                : paymentStats // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>,
            categoryStats: null == categoryStats
                ? _value.categoryStats
                : categoryStats // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>,
            deliveryMethodsStats: null == deliveryMethodsStats
                ? _value.deliveryMethodsStats
                : deliveryMethodsStats // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>,
            userStats: null == userStats
                ? _value.userStats
                : userStats // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DailyAnalyticsImplCopyWith<$Res>
    implements $DailyAnalyticsCopyWith<$Res> {
  factory _$$DailyAnalyticsImplCopyWith(
    _$DailyAnalyticsImpl value,
    $Res Function(_$DailyAnalyticsImpl) then,
  ) = __$$DailyAnalyticsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double totalSales,
    int totalBills,
    double totalDiscount,
    double extraCharges,
    Map<String, ItemStat> itemStats,
    Map<String, HourStat> hourlyStats,
    Map<String, double> paymentStats,
    Map<String, double> categoryStats,
    Map<String, double> deliveryMethodsStats,
    Map<String, double> userStats,
  });
}

/// @nodoc
class __$$DailyAnalyticsImplCopyWithImpl<$Res>
    extends _$DailyAnalyticsCopyWithImpl<$Res, _$DailyAnalyticsImpl>
    implements _$$DailyAnalyticsImplCopyWith<$Res> {
  __$$DailyAnalyticsImplCopyWithImpl(
    _$DailyAnalyticsImpl _value,
    $Res Function(_$DailyAnalyticsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DailyAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalSales = null,
    Object? totalBills = null,
    Object? totalDiscount = null,
    Object? extraCharges = null,
    Object? itemStats = null,
    Object? hourlyStats = null,
    Object? paymentStats = null,
    Object? categoryStats = null,
    Object? deliveryMethodsStats = null,
    Object? userStats = null,
  }) {
    return _then(
      _$DailyAnalyticsImpl(
        totalSales: null == totalSales
            ? _value.totalSales
            : totalSales // ignore: cast_nullable_to_non_nullable
                  as double,
        totalBills: null == totalBills
            ? _value.totalBills
            : totalBills // ignore: cast_nullable_to_non_nullable
                  as int,
        totalDiscount: null == totalDiscount
            ? _value.totalDiscount
            : totalDiscount // ignore: cast_nullable_to_non_nullable
                  as double,
        extraCharges: null == extraCharges
            ? _value.extraCharges
            : extraCharges // ignore: cast_nullable_to_non_nullable
                  as double,
        itemStats: null == itemStats
            ? _value._itemStats
            : itemStats // ignore: cast_nullable_to_non_nullable
                  as Map<String, ItemStat>,
        hourlyStats: null == hourlyStats
            ? _value._hourlyStats
            : hourlyStats // ignore: cast_nullable_to_non_nullable
                  as Map<String, HourStat>,
        paymentStats: null == paymentStats
            ? _value._paymentStats
            : paymentStats // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>,
        categoryStats: null == categoryStats
            ? _value._categoryStats
            : categoryStats // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>,
        deliveryMethodsStats: null == deliveryMethodsStats
            ? _value._deliveryMethodsStats
            : deliveryMethodsStats // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>,
        userStats: null == userStats
            ? _value._userStats
            : userStats // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DailyAnalyticsImpl extends _DailyAnalytics {
  const _$DailyAnalyticsImpl({
    this.totalSales = 0.0,
    this.totalBills = 0,
    this.totalDiscount = 0.0,
    this.extraCharges = 0.0,
    final Map<String, ItemStat> itemStats = const {},
    final Map<String, HourStat> hourlyStats = const {},
    final Map<String, double> paymentStats = const {
      'cash': 0.0,
      'upi': 0.0,
      'card': 0.0,
    },
    final Map<String, double> categoryStats = const {},
    final Map<String, double> deliveryMethodsStats = const {},
    final Map<String, double> userStats = const {},
  }) : _itemStats = itemStats,
       _hourlyStats = hourlyStats,
       _paymentStats = paymentStats,
       _categoryStats = categoryStats,
       _deliveryMethodsStats = deliveryMethodsStats,
       _userStats = userStats,
       super._();

  factory _$DailyAnalyticsImpl.fromJson(Map<String, dynamic> json) =>
      _$$DailyAnalyticsImplFromJson(json);

  @override
  @JsonKey()
  final double totalSales;
  @override
  @JsonKey()
  final int totalBills;
  @override
  @JsonKey()
  final double totalDiscount;
  @override
  @JsonKey()
  final double extraCharges;
  final Map<String, ItemStat> _itemStats;
  @override
  @JsonKey()
  Map<String, ItemStat> get itemStats {
    if (_itemStats is EqualUnmodifiableMapView) return _itemStats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_itemStats);
  }

  final Map<String, HourStat> _hourlyStats;
  @override
  @JsonKey()
  Map<String, HourStat> get hourlyStats {
    if (_hourlyStats is EqualUnmodifiableMapView) return _hourlyStats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_hourlyStats);
  }

  final Map<String, double> _paymentStats;
  @override
  @JsonKey()
  Map<String, double> get paymentStats {
    if (_paymentStats is EqualUnmodifiableMapView) return _paymentStats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_paymentStats);
  }

  final Map<String, double> _categoryStats;
  @override
  @JsonKey()
  Map<String, double> get categoryStats {
    if (_categoryStats is EqualUnmodifiableMapView) return _categoryStats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_categoryStats);
  }

  final Map<String, double> _deliveryMethodsStats;
  @override
  @JsonKey()
  Map<String, double> get deliveryMethodsStats {
    if (_deliveryMethodsStats is EqualUnmodifiableMapView)
      return _deliveryMethodsStats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_deliveryMethodsStats);
  }

  final Map<String, double> _userStats;
  @override
  @JsonKey()
  Map<String, double> get userStats {
    if (_userStats is EqualUnmodifiableMapView) return _userStats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_userStats);
  }

  @override
  String toString() {
    return 'DailyAnalytics(totalSales: $totalSales, totalBills: $totalBills, totalDiscount: $totalDiscount, extraCharges: $extraCharges, itemStats: $itemStats, hourlyStats: $hourlyStats, paymentStats: $paymentStats, categoryStats: $categoryStats, deliveryMethodsStats: $deliveryMethodsStats, userStats: $userStats)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyAnalyticsImpl &&
            (identical(other.totalSales, totalSales) ||
                other.totalSales == totalSales) &&
            (identical(other.totalBills, totalBills) ||
                other.totalBills == totalBills) &&
            (identical(other.totalDiscount, totalDiscount) ||
                other.totalDiscount == totalDiscount) &&
            (identical(other.extraCharges, extraCharges) ||
                other.extraCharges == extraCharges) &&
            const DeepCollectionEquality().equals(
              other._itemStats,
              _itemStats,
            ) &&
            const DeepCollectionEquality().equals(
              other._hourlyStats,
              _hourlyStats,
            ) &&
            const DeepCollectionEquality().equals(
              other._paymentStats,
              _paymentStats,
            ) &&
            const DeepCollectionEquality().equals(
              other._categoryStats,
              _categoryStats,
            ) &&
            const DeepCollectionEquality().equals(
              other._deliveryMethodsStats,
              _deliveryMethodsStats,
            ) &&
            const DeepCollectionEquality().equals(
              other._userStats,
              _userStats,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    totalSales,
    totalBills,
    totalDiscount,
    extraCharges,
    const DeepCollectionEquality().hash(_itemStats),
    const DeepCollectionEquality().hash(_hourlyStats),
    const DeepCollectionEquality().hash(_paymentStats),
    const DeepCollectionEquality().hash(_categoryStats),
    const DeepCollectionEquality().hash(_deliveryMethodsStats),
    const DeepCollectionEquality().hash(_userStats),
  );

  /// Create a copy of DailyAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyAnalyticsImplCopyWith<_$DailyAnalyticsImpl> get copyWith =>
      __$$DailyAnalyticsImplCopyWithImpl<_$DailyAnalyticsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DailyAnalyticsImplToJson(this);
  }
}

abstract class _DailyAnalytics extends DailyAnalytics {
  const factory _DailyAnalytics({
    final double totalSales,
    final int totalBills,
    final double totalDiscount,
    final double extraCharges,
    final Map<String, ItemStat> itemStats,
    final Map<String, HourStat> hourlyStats,
    final Map<String, double> paymentStats,
    final Map<String, double> categoryStats,
    final Map<String, double> deliveryMethodsStats,
    final Map<String, double> userStats,
  }) = _$DailyAnalyticsImpl;
  const _DailyAnalytics._() : super._();

  factory _DailyAnalytics.fromJson(Map<String, dynamic> json) =
      _$DailyAnalyticsImpl.fromJson;

  @override
  double get totalSales;
  @override
  int get totalBills;
  @override
  double get totalDiscount;
  @override
  double get extraCharges;
  @override
  Map<String, ItemStat> get itemStats;
  @override
  Map<String, HourStat> get hourlyStats;
  @override
  Map<String, double> get paymentStats;
  @override
  Map<String, double> get categoryStats;
  @override
  Map<String, double> get deliveryMethodsStats;
  @override
  Map<String, double> get userStats;

  /// Create a copy of DailyAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyAnalyticsImplCopyWith<_$DailyAnalyticsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ItemStat _$ItemStatFromJson(Map<String, dynamic> json) {
  return _ItemStat.fromJson(json);
}

/// @nodoc
mixin _$ItemStat {
  String get name => throw _privateConstructorUsedError;
  int get qty => throw _privateConstructorUsedError;
  double get revenue => throw _privateConstructorUsedError;

  /// Serializes this ItemStat to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ItemStat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ItemStatCopyWith<ItemStat> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ItemStatCopyWith<$Res> {
  factory $ItemStatCopyWith(ItemStat value, $Res Function(ItemStat) then) =
      _$ItemStatCopyWithImpl<$Res, ItemStat>;
  @useResult
  $Res call({String name, int qty, double revenue});
}

/// @nodoc
class _$ItemStatCopyWithImpl<$Res, $Val extends ItemStat>
    implements $ItemStatCopyWith<$Res> {
  _$ItemStatCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ItemStat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? qty = null, Object? revenue = null}) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            qty: null == qty
                ? _value.qty
                : qty // ignore: cast_nullable_to_non_nullable
                      as int,
            revenue: null == revenue
                ? _value.revenue
                : revenue // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ItemStatImplCopyWith<$Res>
    implements $ItemStatCopyWith<$Res> {
  factory _$$ItemStatImplCopyWith(
    _$ItemStatImpl value,
    $Res Function(_$ItemStatImpl) then,
  ) = __$$ItemStatImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, int qty, double revenue});
}

/// @nodoc
class __$$ItemStatImplCopyWithImpl<$Res>
    extends _$ItemStatCopyWithImpl<$Res, _$ItemStatImpl>
    implements _$$ItemStatImplCopyWith<$Res> {
  __$$ItemStatImplCopyWithImpl(
    _$ItemStatImpl _value,
    $Res Function(_$ItemStatImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ItemStat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? name = null, Object? qty = null, Object? revenue = null}) {
    return _then(
      _$ItemStatImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        qty: null == qty
            ? _value.qty
            : qty // ignore: cast_nullable_to_non_nullable
                  as int,
        revenue: null == revenue
            ? _value.revenue
            : revenue // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ItemStatImpl implements _ItemStat {
  const _$ItemStatImpl({this.name = '', this.qty = 0, this.revenue = 0.0});

  factory _$ItemStatImpl.fromJson(Map<String, dynamic> json) =>
      _$$ItemStatImplFromJson(json);

  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final int qty;
  @override
  @JsonKey()
  final double revenue;

  @override
  String toString() {
    return 'ItemStat(name: $name, qty: $qty, revenue: $revenue)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ItemStatImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.qty, qty) || other.qty == qty) &&
            (identical(other.revenue, revenue) || other.revenue == revenue));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, qty, revenue);

  /// Create a copy of ItemStat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ItemStatImplCopyWith<_$ItemStatImpl> get copyWith =>
      __$$ItemStatImplCopyWithImpl<_$ItemStatImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ItemStatImplToJson(this);
  }
}

abstract class _ItemStat implements ItemStat {
  const factory _ItemStat({
    final String name,
    final int qty,
    final double revenue,
  }) = _$ItemStatImpl;

  factory _ItemStat.fromJson(Map<String, dynamic> json) =
      _$ItemStatImpl.fromJson;

  @override
  String get name;
  @override
  int get qty;
  @override
  double get revenue;

  /// Create a copy of ItemStat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ItemStatImplCopyWith<_$ItemStatImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

HourStat _$HourStatFromJson(Map<String, dynamic> json) {
  return _HourStat.fromJson(json);
}

/// @nodoc
mixin _$HourStat {
  double get sales => throw _privateConstructorUsedError;
  int get orders => throw _privateConstructorUsedError;

  /// Serializes this HourStat to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HourStat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HourStatCopyWith<HourStat> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HourStatCopyWith<$Res> {
  factory $HourStatCopyWith(HourStat value, $Res Function(HourStat) then) =
      _$HourStatCopyWithImpl<$Res, HourStat>;
  @useResult
  $Res call({double sales, int orders});
}

/// @nodoc
class _$HourStatCopyWithImpl<$Res, $Val extends HourStat>
    implements $HourStatCopyWith<$Res> {
  _$HourStatCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HourStat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sales = null, Object? orders = null}) {
    return _then(
      _value.copyWith(
            sales: null == sales
                ? _value.sales
                : sales // ignore: cast_nullable_to_non_nullable
                      as double,
            orders: null == orders
                ? _value.orders
                : orders // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HourStatImplCopyWith<$Res>
    implements $HourStatCopyWith<$Res> {
  factory _$$HourStatImplCopyWith(
    _$HourStatImpl value,
    $Res Function(_$HourStatImpl) then,
  ) = __$$HourStatImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double sales, int orders});
}

/// @nodoc
class __$$HourStatImplCopyWithImpl<$Res>
    extends _$HourStatCopyWithImpl<$Res, _$HourStatImpl>
    implements _$$HourStatImplCopyWith<$Res> {
  __$$HourStatImplCopyWithImpl(
    _$HourStatImpl _value,
    $Res Function(_$HourStatImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HourStat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sales = null, Object? orders = null}) {
    return _then(
      _$HourStatImpl(
        sales: null == sales
            ? _value.sales
            : sales // ignore: cast_nullable_to_non_nullable
                  as double,
        orders: null == orders
            ? _value.orders
            : orders // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HourStatImpl implements _HourStat {
  const _$HourStatImpl({this.sales = 0.0, this.orders = 0});

  factory _$HourStatImpl.fromJson(Map<String, dynamic> json) =>
      _$$HourStatImplFromJson(json);

  @override
  @JsonKey()
  final double sales;
  @override
  @JsonKey()
  final int orders;

  @override
  String toString() {
    return 'HourStat(sales: $sales, orders: $orders)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HourStatImpl &&
            (identical(other.sales, sales) || other.sales == sales) &&
            (identical(other.orders, orders) || other.orders == orders));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, sales, orders);

  /// Create a copy of HourStat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HourStatImplCopyWith<_$HourStatImpl> get copyWith =>
      __$$HourStatImplCopyWithImpl<_$HourStatImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HourStatImplToJson(this);
  }
}

abstract class _HourStat implements HourStat {
  const factory _HourStat({final double sales, final int orders}) =
      _$HourStatImpl;

  factory _HourStat.fromJson(Map<String, dynamic> json) =
      _$HourStatImpl.fromJson;

  @override
  double get sales;
  @override
  int get orders;

  /// Create a copy of HourStat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HourStatImplCopyWith<_$HourStatImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
