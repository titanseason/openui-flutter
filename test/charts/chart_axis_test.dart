import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter/openui_flutter.dart';

void main() {
  test('niceDomain widens to round ticks and runs through zero', () {
    final d = niceDomain(0, 24, 180);
    expect(d.min, 0);
    expect(d.max, 25);
    expect(d.ticks, [0, 5, 10, 15, 20, 25]);
  });

  test('niceDomain covers negatives with a zero line', () {
    // Target 4 ticks: d3 step logic lands on 10, not 5.
    final d = niceDomain(-10, 20, 180);
    expect(d.min, -10);
    expect(d.max, 20);
    expect(d.ticks, [-10, 0, 10, 20]);
    // Target 5 ticks: step 5.
    final e = niceDomain(-10, 20, 200);
    expect(e.ticks, [-10, -5, 0, 5, 10, 15, 20]);
  });

  test('niceDomain handles all-zero and all-equal data', () {
    final zero = niceDomain(0, 0, 180);
    expect(zero.min, 0);
    expect(zero.max, 1);
    expect(zero.ticks.length, 6);
    expect(zero.ticks.first, 0);
    expect(zero.ticks.last, 1);
    expect(zero.ticks[3], closeTo(0.6, 1e-9));
    final equal = niceDomain(5, 5, 180);
    expect(equal.min, 0);
    expect(equal.max, 5);
    expect(equal.ticks, [0, 1, 2, 3, 4, 5]);
  });

  test('niceDomain without zero anchoring is for data axes', () {
    final d = niceDomain(2, 4, 200, throughZero: false);
    expect(d.min, 2);
    expect(d.max, 4);
    expect(d.ticks, [2, 2.5, 3, 3.5, 4]);
    final wide = niceDomain(0, 100, 600, throughZero: false, pixelsPerTick: 60);
    expect(wide.ticks, [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]);
  });

  test('niceDomain floors the tick target at 2', () {
    final d = niceDomain(0, 100, 10);
    expect(d.ticks.length, greaterThanOrEqualTo(2));
    expect(d.min, 0);
    expect(d.max, 100);
  });

  test('minMaxOf and stackedMinMax', () {
    expect(minMaxOf(const [
      [1.0, 2.0],
      [3.0]
    ]), (min: 1.0, max: 3.0));
    expect(minMaxOf(const <List<double>>[]), (min: 0.0, max: 0.0));
    expect(
      stackedMinMax(const [
        [10.0, -5.0],
        [20.0, 3.0]
      ], 2),
      (min: -5.0, max: 30.0),
    );
  });

  test('yForValue maps the domain onto the plot', () {
    const domain = (min: 0.0, max: 25.0, ticks: <double>[0, 5, 10, 15, 20, 25]);
    expect(yForValue(0, domain, 100), 100);
    expect(yForValue(25, domain, 100), 0);
    expect(yForValue(12.5, domain, 100), 50);
  });

  test('cartesianLayout fits short labels without scrolling', () {
    final layout = cartesianLayout(categories: const ['A', 'B'], all: const [
      [22.0, 24.0]
    ], stacked: false, viewport: const Size(200, 200));
    expect(layout.domain.max, 25);
    expect(layout.labelH, 30);
    expect(layout.plotH, 170);
    expect(layout.needsScroll, isFalse);
    expect(layout.contentWidth + layout.axisW, 200);
  });

  test('cartesianLayout widens slots and grows the label band for a long label', () {
    final layout = cartesianLayout(categories: const ['A very long category label here', 'B'], all: const [
      [22.0, 24.0]
    ], stacked: false, viewport: const Size(400, 200));
    expect(layout.slotWidth, greaterThan(72));
    expect(layout.labelH, greaterThan(30));
    expect(layout.needsScroll, isFalse);
  });

  test('cartesianLayout scrolls at the default slot width for many categories', () {
    final layout = cartesianLayout(categories: const ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'], all: const [
      [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
    ], stacked: false, viewport: const Size(400, 200));
    expect(layout.needsScroll, isTrue);
    expect(layout.slotWidth, 72);
  });
}
