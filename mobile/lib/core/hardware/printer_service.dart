import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../models/order_model.dart';
import '../utils/currency_formatter.dart';

// Supports:
//   - Bluetooth ESC/POS printers (via flutter_blue_plus)
//   - WiFi ESC/POS printers (via raw TCP socket)
// Cash drawer: pulse is sent as an ESC/POS command after receipt.

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  BluetoothDevice? _connectedBtDevice;
  BluetoothCharacteristic? _printCharacteristic;

  // Bluetooth
  Future<List<BluetoothDevice>> scanBluetooth(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final results = <BluetoothDevice>[];
    final subscription =
        FlutterBluePlus.scanResults.listen((scanResults) {
      for (final r in scanResults) {
        if (!results.any((d) => d.remoteId == r.device.remoteId)) {
          results.add(r.device);
        }
      }
    });
    await FlutterBluePlus.startScan(timeout: timeout);
    await Future.delayed(timeout);
    await subscription.cancel();
    return results;
  }

  Future<bool> connectBluetooth(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false);
      _connectedBtDevice = device;

      final services = await device.discoverServices();
      for (final service in services) {
        for (final char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            _printCharacteristic = char;
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnectBluetooth() async {
    await _connectedBtDevice?.disconnect();
    _connectedBtDevice = null;
    _printCharacteristic = null;
  }

  // WiFi / LAN printing
  Future<bool> printViaWifi({
    required String ipAddress,
    required int port,
    required List<int> data,
  }) async {
    try {
      final socket =
          await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 5));
      socket.add(data);
      await socket.flush();
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ESC/POS receipt builder
  List<int> buildReceipt(OrderModel order, {String? businessName, String? footer}) {
    final bytes = <int>[];

    // Initialize printer
    bytes.addAll([0x1B, 0x40]); // ESC @

    // Center alignment
    bytes.addAll([0x1B, 0x61, 0x01]);

    // Business name (bold, large)
    bytes.addAll([0x1B, 0x45, 0x01]); // Bold on
    bytes.addAll([0x1D, 0x21, 0x11]); // Double height+width
    bytes.addAll(_encodeText('${businessName ?? 'SawYun POS'}\n'));
    bytes.addAll([0x1D, 0x21, 0x00]); // Normal size
    bytes.addAll([0x1B, 0x45, 0x00]); // Bold off

    // Order info
    bytes.addAll(_encodeText('--------------------------------\n'));
    bytes.addAll(_encodeText('Order: ${order.orderNumber}\n'));
    bytes.addAll(_encodeText('--------------------------------\n'));

    // Left alignment for items
    bytes.addAll([0x1B, 0x61, 0x00]);

    for (final item in order.items) {
      final name = item.displayName.length > 20
          ? item.displayName.substring(0, 20)
          : item.displayName;
      final qty = 'x${item.quantityOrdered}';
      final total = CurrencyFormatter.formatCompact(item.lineTotal);
      bytes.addAll(_encodeText(
          '$name\n  $qty @ ${CurrencyFormatter.formatCompact(item.unitPrice)}  $total\n'));
    }

    bytes.addAll(_encodeText('--------------------------------\n'));

    // Totals (right-aligned using padding)
    bytes.addAll(_encodeText(_padLine('Subtotal:', CurrencyFormatter.formatCompact(order.grossTotal))));
    if (order.taxTotal > 0) {
      bytes.addAll(_encodeText(_padLine('Tax:', CurrencyFormatter.formatCompact(order.taxTotal))));
    }
    if (order.discountTotal > 0) {
      bytes.addAll(_encodeText(_padLine('Discount:', '-${CurrencyFormatter.formatCompact(order.discountTotal)}')));
    }
    bytes.addAll([0x1B, 0x45, 0x01]); // Bold
    bytes.addAll(_encodeText(_padLine('TOTAL:', CurrencyFormatter.format(order.netTotal))));
    bytes.addAll([0x1B, 0x45, 0x00]);

    // Payment method
    if (order.payments.isNotEmpty) {
      bytes.addAll(_encodeText('--------------------------------\n'));
      for (final p in order.payments) {
        bytes.addAll(_encodeText(
            _padLine('${PaymentMethod.displayName(p.paymentMethod)}:',
                CurrencyFormatter.formatCompact(p.amount))));
      }
    }

    // Footer
    bytes.addAll([0x1B, 0x61, 0x01]); // Center
    bytes.addAll(_encodeText('\n${footer ?? 'Thank you for your purchase!'}\n'));
    bytes.addAll(_encodeText('\n\n\n'));

    // Cut paper
    bytes.addAll([0x1D, 0x56, 0x00]); // Full cut

    return bytes;
  }

  // Open cash drawer (pin 2 or pin 5)
  List<int> openCashDrawerCommand() {
    return [0x1B, 0x70, 0x00, 0x19, 0x19]; // Pulse pin 2
  }

  Future<bool> printReceipt(OrderModel order,
      {String? businessName, String? footer, bool openDrawer = false}) async {
    final data = buildReceipt(order,
        businessName: businessName, footer: footer);
    if (openDrawer) {
      data.addAll(openCashDrawerCommand());
    }

    if (_printCharacteristic != null) {
      try {
        // BT printers have max MTU, chunk data
        const chunkSize = 512;
        for (var i = 0; i < data.length; i += chunkSize) {
          final end = (i + chunkSize) < data.length
              ? i + chunkSize
              : data.length;
          await _printCharacteristic!.write(
            data.sublist(i, end),
            withoutResponse: true,
          );
          await Future.delayed(const Duration(milliseconds: 20));
        }
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  List<int> _encodeText(String text) {
    return text.codeUnits;
  }

  String _padLine(String left, String right, {int width = 32}) {
    final spaces = width - left.length - right.length;
    return '$left${' ' * (spaces > 0 ? spaces : 1)}$right\n';
  }
}

final printerService = PrinterService();
