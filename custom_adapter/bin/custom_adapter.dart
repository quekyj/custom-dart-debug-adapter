import 'dart:async';
import 'dart:io';

import 'package:dap/src/protocol_generated.dart';
import 'package:dds/dap.dart' show ByteStreamServerChannel;
import 'package:dds/src/dap/adapters/dart_cli_adapter.dart';

import 'dap_server.dart';

Future<void> main(List<String> arguments) async {
  final portEnv = Platform.environment['CUSTOM_DAP_SERVER_PORT'];
  final port = portEnv != null ? int.tryParse(portEnv) : null;

  if (port != null) {
    final server = await DapServer.create(
      port: port,
      adapterConstructor: (channel) => MyCustomDebugAdapter(channel, true),
    );
  } else {
    final adapter = MyCustomDebugAdapter(
        ByteStreamServerChannel(stdin, stdout, null), false);
  }
}

/// NOTE: DartCliDebugAdapter is not current public API, so this could break.
/// However, extending just DartDebugAdapter would require re-implementing
/// some things.
class MyCustomDebugAdapter extends DartCliDebugAdapter {
  final bool isServerMode;

  MyCustomDebugAdapter(super.channel, this.isServerMode);

  @override
  Future<void> launchAndRespond(void Function() sendResponse) async {
    await super.launchAndRespond(sendResponse);

    final mode = isServerMode ? "SERVER" : "SINGLE SESSION";
    sendOutput(
      'stdout',
      'Hello from Custom Debug Adapter ($mode MODE)!\n',
    );
  }

  @override
  Future<void> variablesRequest(Request request, VariablesArguments args,
      void Function(VariablesResponseBody) sendResponse) async {
    return super.variablesRequest(
      request,
      args,
      (response) {
        response.variables.add(
          Variable(
            name: 'My Fake Variable',
            value: 'Fake Value',
            variablesReference: 0,
          ),
        );
        sendResponse(response);
      },
    );
  }
}
