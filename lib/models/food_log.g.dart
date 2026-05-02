import 'package:hive/hive.dart';

import 'food_item.dart';
import 'food_log.dart';

class FoodLogAdapter extends TypeAdapter<FoodLog> {
  @override
  final int typeId = 1;

  @override
  FoodLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodLog(
      id: fields[0] as String,
      foodItem: fields[1] as FoodItem,
      quantity: fields[2] as double,
      mealType: fields[3] as String,
      loggedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FoodLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.foodItem)
      ..writeByte(2)..write(obj.quantity)
      ..writeByte(3)..write(obj.mealType)
      ..writeByte(4)..write(obj.loggedAt);
  }
}