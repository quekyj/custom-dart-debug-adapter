import 'dart:developer';

void main(List<String> arguments) {
  // Run this app with F5..
  // It should print "Hello from Custom Debug Adapter!"
  // and also have a fake variable in the Variables window.
  final message = 'Hello!';
  debugger();
  print(message);
}
