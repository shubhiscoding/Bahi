import 'package:flutter/material.dart';

enum HisabDatePreset { oneMonth, sixMonths, oneYear, allTime, custom }

@immutable
class HisabDateFilter {
  final HisabDatePreset preset;
  final DateTime asOf;
  final DateTime? customStart;
  final DateTime? customEnd;

  const HisabDateFilter._(this.preset, this.asOf, {this.customStart, this.customEnd});

  factory HisabDateFilter.oneMonth() => HisabDateFilter._(HisabDatePreset.oneMonth, DateTime.now());
  factory HisabDateFilter.sixMonths() => HisabDateFilter._(HisabDatePreset.sixMonths, DateTime.now());
  factory HisabDateFilter.oneYear() => HisabDateFilter._(HisabDatePreset.oneYear, DateTime.now());
  factory HisabDateFilter.allTime() => HisabDateFilter._(HisabDatePreset.allTime, DateTime.now());
  factory HisabDateFilter.custom(DateTime start, DateTime end) => HisabDateFilter._(
        HisabDatePreset.custom,
        end,
        customStart: DateTime(start.year, start.month, start.day),
        customEnd: DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
      );

  DateTime? get dateFrom {
    if (preset == HisabDatePreset.custom) return customStart;
    return switch (preset) {
      HisabDatePreset.oneMonth => _subtractMonths(asOf, 1),
      HisabDatePreset.sixMonths => _subtractMonths(asOf, 6),
      HisabDatePreset.oneYear => _subtractMonths(asOf, 12),
      HisabDatePreset.allTime => null,
      HisabDatePreset.custom => customStart,
    };
  }

  DateTime? get dateTo => switch (preset) {
        HisabDatePreset.custom => customEnd,
        HisabDatePreset.allTime => null,
        _ => asOf,
      };

  DateTimeRange? get dateRange {
    final start = dateFrom;
    final end = dateTo;
    if (start == null || end == null) return null;
    return DateTimeRange(start: start, end: end);
  }

  String get cacheKey {
    if (preset == HisabDatePreset.allTime) return preset.name;
    return '${preset.name}:${dateFrom!.toUtc().toIso8601String()}:${dateTo!.toUtc().toIso8601String()}';
  }

  @override
  bool operator ==(Object other) =>
      other is HisabDateFilter &&
      other.preset == preset &&
      other.asOf == asOf &&
      other.customStart == customStart &&
      other.customEnd == customEnd;

  @override
  int get hashCode => Object.hash(preset, asOf, customStart, customEnd);

  static DateTime _subtractMonths(DateTime value, int count) {
    final monthIndex = value.year * 12 + value.month - 1 - count;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      value.day > lastDay ? lastDay : value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }
}
