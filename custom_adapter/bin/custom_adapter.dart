import 'dart:async';
import 'dart:io';

import 'package:dap/src/protocol_generated.dart';
import 'package:dds/dap.dart' show ByteStreamServerChannel;
import 'package:dds/src/dap/adapters/dart_cli_adapter.dart';

import 'dap_server.dart';
import 'package:vm_service/vm_service.dart' as vm;
import 'package:dds/src/dap/variables.dart';
import 'package:dds/src/dap/protocol_converter.dart';

import 'package:dds/src/dap/protocol_stream.dart';

import 'package:collection/collection.dart';

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

  // evaluateRequest is called by the client to evaluate a string expression.

  // This could come from the user typing into an input
  // (for example VS Code's Debug Console), automatic refresh of a
  // Watch window, or called as part of an operation like "Copy Value" for
  // an item in the watch/variables window.

  // If execution is not paused, the frameId will not be provided.
  @override
  Future<void> evaluateRequest(Request request, EvaluateArguments args,
      void Function(EvaluateResponseBody p1) sendResponse) {
    // TODO: implement evaluateRequest
    return super.evaluateRequest(request, args, sendResponse);
  }

  // scopesRequest is called by the client to request all of the variables
  // scopes available for a given stack frame.
  @override
  Future<void> scopesRequest(Request request, ScopesArguments args,
      void Function(ScopesResponseBody p1) sendResponse) {
    return super.scopesRequest(request, args, (response) {
      final storedData = super.isolateManager.getStoredData(args.frameId);
      final thread = storedData?.thread;
      final data = storedData?.data;
      final frameData = data is vm.Frame ? data : null;

      response.scopes.add(
        Scope(
          name: 'ROHD',
          presentationHint: 'ROHD Debug',
          // TODO: I use "!" to check, which is weird.
          variablesReference: thread!.storeData(
            /// A wrapper around variables for use in `variablesRequest` that can
            /// hold additional data, such as a formatting information supplied
            /// in an evaluation request.
            FrameScopeData(frameData!, FrameScopeDataKind.rohd),
          ),
          expensive: false,
        ),
      );
      sendResponse(response);
    });
  }

  @override
  Future<void> variablesRequest(Request request, VariablesArguments args,
      void Function(VariablesResponseBody) sendResponse) async {
    // [variablesRequest] is called by the client to request child variables
    // for a given variables variablesReference.

    // The variablesReference provided by the client will be a reference the
    // server has previously provided, for example in response
    // to a scopesRequest or an evaluateRequest.

    // We use the reference to look up the stored data and then
    // create variables based on the type of data.
    // For a Frame, we will return the local variables, for a
    // List/MapAssociation we will return items from it, and for an
    // instance we will return the fields (and possibly getters) for
    // that instance.

    // Quek: Basically client use this to request the data based on the
    // reference only

    return super.variablesRequest(
      request,
      args,
      (response) async {
        final service = vmService;
        final childStart = args.start;
        final childCount = args.count;
        final storedData =
            isolateManager.getStoredData(args.variablesReference);
        if (storedData == null) {
          throw StateError('variablesReference is no longer valid');
        }
        final thread = storedData.thread;
        var data = storedData.data;

        VariableFormat? format;
        // Unwrap any variable we stored with formatting info.
        if (data is VariableData) {
          format = data.format;
          data = data.data;
        }

        // If no explicit formatting, use from args.
        format ??= VariableFormat.fromDapValueFormat(args.format);

        final variables = <Variable>[];

        // data kind is ROHD
        if (data is FrameScopeData && data.kind == FrameScopeDataKind.rohd) {
          final vars = data.frame.vars;
          print(vars);
          if (vars != null) {
            Future<Variable> convert(int index, vm.BoundVariable variable) {
              // Store the expression that gets this object as we may need it to
              // compute evaluateNames for child objects later.
              final value = variable.value;

              if (value is vm.InstanceRef) {
                storeEvaluateName(value, variable.name);
              }
              final _converter = ProtocolConverter(this);
              final maxToStringsPerEvaluation = 10;

              return _converter.convertVmResponseToVariable(
                thread,
                variable.value,
                name: variable.name,
                allowCallingToString: evaluateToStringInDebugViews &&
                    index <= maxToStringsPerEvaluation,
                evaluateName: variable.name,
                format: format,
              );
            }

            final List<Variable> resVarCandidate = [];
            var resVar;
            for (int i = 0; i < vars.length; i++) {
              if (vars[i].value.classRef?.name == 'Logic') {
                resVar = await convert(i, vars[i]);
                resVarCandidate.add(resVar);
              }
            }

            response.variables.addAll(resVarCandidate);

            // Sort the variables by name.
            // variables.sortBy((v) => v.name);
          }
        }

        // Get all the variables
        // for (int i = 0; i < response.variables.length; i++) {
        //   if (response.variables[i].name == 'andG') {
        //     // print(response.variables[i].name);
        //     // print(response.variables[i].value);
        //     // print(response.variables[i].variablesReference);

        //     args = VariablesArguments.fromMap({
        //       'variablesReference': response.variables[i].variablesReference
        //     });

        //     super.variablesRequest(request, args, (response) {
        //       print(response.variables[1].name);
        //     });
        //   }
        // }
        sendResponse(response);
      },
    );
  }
}
