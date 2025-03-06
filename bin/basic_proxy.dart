import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.time}: ${record.level.name}: ${record.message}');
  });

  final logger = Logger('ProxyLogger');
  final server = await ServerSocket.bind('localhost', 8080);
  print('Proxy server running on port 8080');

  await for (final client in server) {
    handleConnection(client, logger);
  }
}

void handleConnection(Socket client, Logger logger) {
  var buffer = StringBuffer();

  client.listen((data) {
    buffer.write(utf8.decode(data));
    var request = buffer.toString();

    if (request.contains('\r\n\r\n')) {
      processRequest(client, request, logger);
      buffer.clear();
    }
  });
}

void processRequest(Socket client, String request, Logger logger) async {
  var firstLine = request.split('\r\n')[0];
  var parts = firstLine.split(' ');

  if (parts[0] == 'CONNECT') {
    var hostPort = parts[1].split(':');
    var host = hostPort[0];
    var port = int.parse(hostPort[1]);

    try {
      var server = await Socket.connect(host, port);
      logger.info('Connected to $host:$port');

      client.write('HTTP/1.1 200 Connection Established\r\n\r\n');

      // Forwarding data bidirectionally
      server.listen((data) => client.add(data), onDone: () {
        client.close();
        server.close();
      }, onError: (e) {
        logger.severe('Server error: $e');
        client.destroy();
        server.destroy();
      });

      client.listen((data) => server.add(data), onDone: () {
        server.close();
        client.close();
      }, onError: (e) {
        logger.severe('Client error: $e');
        server.destroy();
        client.destroy();
      });
    } catch (e) {
      logger.severe('Connection error: $e');
      client.destroy();
    }
  }
}
