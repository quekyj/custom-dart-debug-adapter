import 'dart:developer';
import 'package:rohd/rohd.dart';

class AndGate extends Module {
  List twoDimensionLogic = <Logic>[];

  Logic get c => output('c');
  AndGate(Logic a, Logic b) {
    a = addInput('a', a);
    b = addInput('b', b);
    final c = addOutput('c');

    twoDimensionLogic.add(a);
    twoDimensionLogic.add(b);

    c <= a & b;
  }
}

void main() async {
  // Run this app with F5..
  // It should print "Hello from Custom Debug Adapter!"
  // and also have a fake variable in the Variables window.
  final message = 'Hello!';

  final a = Logic(name: 'a');
  final b = Logic(width: 1);
  final c = Logic(name: 'c', width: 10);

  final andG = AndGate(a, b);

  await andG.build();

  print(andG.generateSynth());

  a.put(1);
  b.put(0);
  c.put(200);

  print(andG.c);

  debugger();
  print(message);
}
