import 'package:flutter/material.dart';

class DateTimeUtils {
  static DateTime dateOnly(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return DateTime(localDateTime.year, localDateTime.month, localDateTime.day);
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    final local1 = date1.toLocal();
    final local2 = date2.toLocal();
    return local1.year == local2.year &&
        local1.month == local2.month &&
        local1.day == local2.day;
  }

  static String formatTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';
  }

  static String formatDate(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return '${localDateTime.year}-${localDateTime.month.toString().padLeft(2, '0')}-${localDateTime.day.toString().padLeft(2, '0')}';
  }

  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${formatTime(dateTime)}';
  }

  static DateTime toLocalTime(DateTime dateTime) {
    return dateTime.toLocal();
  }

  static DateTime toUTC(DateTime dateTime) {
    return dateTime.toUtc();
  }

  static DateTime timeOfDayToDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}