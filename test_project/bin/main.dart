import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';

/// An abstract class for all adder module.
abstract class Adder extends Module {
  /// The input to the adder pin [a].
  @protected
  late final Logic a;

  /// The input to the adder pin [b].
  @protected
  late final Logic b;

  /// The addition results [sum].
  Logic get sum;

  /// Takes in input [a] and input [b] and return the [sum] of the addition
  /// result. The width of input [a] and [b] must be the same.
  Adder(Logic a, Logic b, {super.name}) {
    if (a.width != b.width) {
      throw Exception('inputs of a and b should have same width.');
    }
    this.a = addInput('a', a, width: a.width);
    this.b = addInput('b', b, width: b.width);
  }
}

/// A simple full-adder with inputs `a` and `b` to be added with a `carryIn`.
class FullAdder extends Module {
  /// The addition's result [sum].
  Logic get sum => output('sum');

  /// The carry bit's result [carryOut].
  Logic get carryOut => output('carry_out');

  /// Constructs a [FullAdder] with value [a], [b] and [carryIn] based on
  /// full adder truth table.
  FullAdder({
    required Logic a,
    required Logic b,
    required Logic carryIn,
    super.name = 'full_adder',
  }) {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    carryIn = addInput('carry_in', carryIn, width: carryIn.width);

    final carryOut = addOutput('carry_out');
    final sum = addOutput('sum');

    final and1 = carryIn & (a ^ b);
    final and2 = b & a;

    sum <= (a ^ b) ^ carryIn;
    carryOut <= and1 | and2;
  }
}

class RippleCarryAdder extends Adder {
  /// The List of results returned from the [FullAdder].
  final _sum = <Logic>[];

  /// The final result of the NBitAdder in a list of Logic.
  @override
  Logic get sum => _sum.rswizzle();

  /// Constructs an n-bit adder based on inputs List of inputs.
  RippleCarryAdder(super.a, super.b, {super.name = 'ripple_carry_adder'}) {
    Logic carry = Const(0);

    for (var i = 0; i < a.width; i++) {
      final fullAdder = FullAdder(a: a[i], b: b[i], carryIn: carry);

      carry = fullAdder.carryOut;
      _sum.add(fullAdder.sum);
    }

    _sum.add(carry);
  }
}

void main() async {
  // Run this app with F5..
  // It should print "Hello from Custom Debug Adapter!"
  // and also have a fake variable in the Variables window.
  final message = 'Hello!';

  final a = Logic(width: 3);
  final b = Logic(width: 3);

  final adder = RippleCarryAdder(a, b);
  await adder.build();
  print(adder.generateSynth());

  a.put(2);
  b.put(4);

  print(adder.sum.value.toInt());
}
