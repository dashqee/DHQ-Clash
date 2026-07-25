import 'package:fl_clash/widgets/donut_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('donut chart preserves zero traffic values', () {
    const data = DonutChartData(value: 0, color: Colors.blue);

    expect(data.value, 0);
  });

  test('donut chart rejects negative traffic values', () {
    const data = DonutChartData(value: -10, color: Colors.blue);

    expect(data.value, 0);
  });
}
