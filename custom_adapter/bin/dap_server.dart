import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dds/dap.dart';

/// A DAP server that binds to a port and runs in multi-session mode.
class DapServer {
  final ServerSocket _socket;

  /// ByteStreamServerChannel
  ///
  /// A wrapper over a Stream/StreamSink that encodes/decores
  /// DAP/LSP request/response/event messages.
  final _channels = <ByteStreamServerChannel>{};

  /// A base DAP Debug Adapter implementation for running and
  /// debugging Dart-based applications (including Flutter and Tests).
  final _adapters = <DartDebugAdapter>{};
  final DartDebugAdapter Function(ByteStreamServerChannel channel)
      adapterConstructor;

  /// ._ is a private constructor
  ///
  /// When we create DAPServer, we need to pass the DAPServer the socket and
  /// adapter Constructor
  DapServer._(this._socket, this.adapterConstructor) {
    _socket.listen(_acceptConnection);
  }

  /// getter for host and port.
  String get host => _socket.address.host;
  int get port => _socket.port;

  /// stop debug adapter function that called when client is
  /// destroyed
  Future<void> stop() async {
    _channels.forEach((client) => client.close());
    await _socket.close();
  }

  /// Create the accept connection.
  void _acceptConnection(Socket client) {
    final address = client.remoteAddress;
    print('Accepted connection from $address');
    client.done.then((_) {
      print('Connection from $address closed');
    });
    _createAdapter(client.transform(Uint8ListTransformer()), client);
  }

  /// Create adapter
  void _createAdapter(Stream<List<int>> _input, StreamSink<List<int>> _output) {
    final channel = ByteStreamServerChannel(_input, _output, null);
    final adapter = adapterConstructor(channel);
    _channels.add(channel);
    _adapters.add(adapter);
    unawaited(channel.closed.then((_) {
      _channels.remove(channel);
      _adapters.remove(adapter);
      adapter.shutdown();
    }));
  }

  /// Starts a DAP Server listening on [host]:[port].
  static Future<DapServer> create({
    String? host,
    int port = 0,
    Logger? logger,
    required DartDebugAdapter Function(ByteStreamServerChannel channel)
        adapterConstructor,
  }) async {
    final _socket = await ServerSocket.bind(
      host ?? InternetAddress.loopbackIPv4,
      port,
    );
    return DapServer._(_socket, adapterConstructor);
  }
}

/// Transforms a stream of [Uint8List]s to [List<int>]s. Used because
/// [ServerSocket] and [Socket] use [Uint8List] but stdin and stdout use
/// [List<int>] and the LSP server needs to operate against both.
class Uint8ListTransformer extends StreamTransformerBase<Uint8List, List<int>> {
  @override
  Stream<List<int>> bind(Stream<Uint8List> stream) {
    late StreamSubscription<Uint8List> input;
    late StreamController<List<int>> _output;
    _output = StreamController<List<int>>(
      onListen: () {
        input = stream.listen(
          (uints) => _output.add(uints),
          onError: _output.addError,
          onDone: _output.close,
        );
      },
      onPause: () => input.pause(),
      onResume: () => input.resume(),
      onCancel: () => input.cancel(),
    );
    return _output.stream;
  }
}
