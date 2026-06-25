import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usb_serial/usb_serial.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../utils/currency_formatter.dart';

// Supports:
//   - USB thermal printers (usb_serial — Android USB Host)
//   - Serial printers via USB-to-Serial adapters (usb_serial — CH340/PL2303/FTDI/CP21xx)
//   - Bluetooth ESC/POS printers (flutter_blue_plus)
//   - WiFi/LAN ESC/POS printers (raw TCP socket)
// Cash drawer: pulse sent as ESC/POS command after receipt.

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  // USB / Serial (both use usb_serial on Android)
  UsbPort? _usbPort;
  _UsbMode? _usbMode;

  // Bluetooth
  BluetoothDevice? _connectedBtDevice;
  BluetoothCharacteristic? _printCharacteristic;

  // WiFi / LAN — persisted config
  static const _kWifiIp = 'pos_printer_wifi_ip';
  static const _kWifiPort = 'pos_printer_wifi_port';
  String? _savedWifiIp;
  int _savedWifiPort = 9100;

  String? get savedWifiIp => _savedWifiIp;
  int get savedWifiPort => _savedWifiPort;

  // Load persisted WiFi config from shared_preferences.
  // Call once at app startup (main.dart).
  Future<void> loadPersistedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _savedWifiIp = prefs.getString(_kWifiIp);
    _savedWifiPort = prefs.getInt(_kWifiPort) ?? 9100;
  }

  Future<void> saveWifiConfig(String ip, int port) async {
    _savedWifiIp = ip;
    _savedWifiPort = port;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWifiIp, ip);
    await prefs.setInt(_kWifiPort, port);
  }

  Future<void> clearWifiConfig() async {
    _savedWifiIp = null;
    _savedWifiPort = 9100;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kWifiIp);
    await prefs.remove(_kWifiPort);
  }

  // Connection status

  bool get isUsbConnected => _usbPort != null;
  bool get isSerialConnected => _usbPort != null && _usbMode == _UsbMode.serial;
  bool get isBtConnected => _printCharacteristic != null;
  bool get isWifiConfigured => _savedWifiIp != null && _savedWifiIp!.isNotEmpty;
  bool get isAnyConnected => isUsbConnected || isBtConnected || isWifiConfigured;

  // USB (direct USB thermal printer)

  Future<List<UsbDevice>> listUsbDevices() => UsbSerial.listDevices();

  Future<bool> connectUsb(UsbDevice device) async {
    await disconnectUsb();
    try {
      _usbPort = await device.create();
      if (_usbPort == null) return false;
      if (!await _usbPort!.open()) {
        _usbPort = null;
        return false;
      }
      await _usbPort!.setDTR(true);
      await _usbPort!.setRTS(true);
      await _usbPort!.setPortParameters(
        9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE,
      );
      _usbMode = _UsbMode.usb;
      return true;
    } catch (_) {
      _usbPort = null;
      return false;
    }
  }

  // Serial (USB-to-Serial adapter: CH340/PL2303/FTDI/CP21xx)

  Future<bool> connectSerial(UsbDevice device) async {
    await disconnectUsb();
    try {
      _usbPort = await device.create();
      if (_usbPort == null) return false;
      if (!await _usbPort!.open()) {
        _usbPort = null;
        return false;
      }
      await _usbPort!.setDTR(true);
      await _usbPort!.setRTS(true);
      await _usbPort!.setPortParameters(
        9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE,
      );
      _usbMode = _UsbMode.serial;
      return true;
    } catch (_) {
      _usbPort = null;
      return false;
    }
  }

  Future<void> disconnectUsb() async {
    try { await _usbPort?.close(); } catch (_) {}
    _usbPort = null;
    _usbMode = null;
  }

  // Bluetooth

  Future<List<BluetoothDevice>> scanBluetooth(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final results = <BluetoothDevice>[];
    StreamSubscription? sub;
    try {
      sub = FlutterBluePlus.scanResults.listen((scanResults) {
        for (final r in scanResults) {
          if (!results.any((d) => d.remoteId == r.device.remoteId)) {
            results.add(r.device);
          }
        }
      });
      await FlutterBluePlus.startScan(timeout: timeout);
      await Future.delayed(timeout);
      await sub.cancel();
    } catch (_) {
      await sub?.cancel();
      await FlutterBluePlus.stopScan();
      return [];
    }
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

  // WiFi / LAN

  Future<bool> printViaWifi({
    required String ipAddress,
    required int port,
    required List<int> data,
  }) async {
    try {
      final socket = await Socket.connect(
          ipAddress, port, timeout: const Duration(seconds: 5));
      socket.add(data);
      await socket.flush();
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ESC/POS receipt builder

  List<int> buildReceipt(OrderModel order,
      {String? businessName, String? footer}) {
    final bytes = <int>[];

    bytes.addAll([0x1B, 0x40]); // ESC @ — init
    bytes.addAll([0x1B, 0x61, 0x01]); // center

    // Business name
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll([0x1D, 0x21, 0x11]);
    bytes.addAll(_encode('${businessName ?? 'SawYun POS'}\n'));
    bytes.addAll([0x1D, 0x21, 0x00]);
    bytes.addAll([0x1B, 0x45, 0x00]);

    bytes.addAll(_encode('--------------------------------\n'));
    bytes.addAll(_encode('Order: ${order.orderNumber}\n'));
    bytes.addAll(_encode('--------------------------------\n'));

    bytes.addAll([0x1B, 0x61, 0x00]); // left
    for (final item in order.items) {
      final name = item.displayName.length > 20
          ? item.displayName.substring(0, 20)
          : item.displayName;
      bytes.addAll(_encode(
        '$name\n  x${item.quantityOrdered} @ '
        '${CurrencyFormatter.formatCompact(item.unitPrice)}  '
        '${CurrencyFormatter.formatCompact(item.lineTotal)}\n',
      ));
    }

    bytes.addAll(_encode('--------------------------------\n'));
    bytes.addAll(_encode(_pad('Subtotal:', CurrencyFormatter.formatCompact(order.grossTotal))));
    if (order.taxTotal > 0) {
      bytes.addAll(_encode(_pad('Tax:', CurrencyFormatter.formatCompact(order.taxTotal))));
    }
    if (order.discountTotal > 0) {
      bytes.addAll(_encode(_pad('Discount:', '-${CurrencyFormatter.formatCompact(order.discountTotal)}')));
    }
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll(_encode(_pad('TOTAL:', CurrencyFormatter.format(order.netTotal))));
    bytes.addAll([0x1B, 0x45, 0x00]);

    if (order.payments.isNotEmpty) {
      bytes.addAll(_encode('--------------------------------\n'));
      for (final p in order.payments) {
        bytes.addAll(_encode(
          _pad('${PaymentMethod.displayName(p.paymentMethod)}:',
              CurrencyFormatter.formatCompact(p.amount)),
        ));
      }
    }

    bytes.addAll([0x1B, 0x61, 0x01]); // center
    bytes.addAll(_encode('\n${footer ?? 'Thank you for your purchase!'}\n'));
    bytes.addAll(_encode('\n\n\n'));
    bytes.addAll([0x1D, 0x56, 0x00]); // full cut

    return bytes;
  }

  List<int> openCashDrawerCommand() => [0x1B, 0x70, 0x00, 0x19, 0x19];

  // Build 58/80mm barcode label ESC/POS bytes
  List<int> buildLabel(ProductModel product, {String? businessName}) {
    final bytes = <int>[];
    bytes.addAll([0x1B, 0x40]); // ESC @ — init

    // Center alignment
    bytes.addAll([0x1B, 0x61, 0x01]);

    // Business name (small)
    if (businessName != null && businessName.isNotEmpty) {
      bytes.addAll(_encode('${businessName.toUpperCase()}\n'));
    }

    // Product name (bold, double height)
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll([0x1D, 0x21, 0x01]); // double height
    final name = product.name.length > 20
        ? product.name.substring(0, 20)
        : product.name;
    bytes.addAll(_encode('$name\n'));
    bytes.addAll([0x1D, 0x21, 0x00]);
    bytes.addAll([0x1B, 0x45, 0x00]);

    // SKU (if present)
    if (product.sku != null && product.sku!.isNotEmpty) {
      bytes.addAll(_encode('SKU: ${product.sku}\n'));
    }

    // Price
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll(_encode(
        '${CurrencyFormatter.format(product.sellingPrice)}\n'));
    bytes.addAll([0x1B, 0x45, 0x00]);

    // Barcode (CODE128) — if product has a barcode
    final barcodeData = product.barcode ?? product.sku;
    if (barcodeData != null && barcodeData.isNotEmpty) {
      bytes.addAll([0x1D, 0x77, 0x02]); // barcode width
      bytes.addAll([0x1D, 0x68, 0x50]); // barcode height = 80 dots
      bytes.addAll([0x1D, 0x48, 0x02]); // HRI below barcode
      bytes.addAll([0x1D, 0x66, 0x00]); // HRI font A
      // CODE128: GS k 73 n d1...dn (new format, m = 0x49 = 73)
      final dataBytes = barcodeData.codeUnits;
      bytes.addAll([0x1D, 0x6B, 0x49, dataBytes.length]);
      bytes.addAll(dataBytes);
    }

    bytes.addAll(_encode('\n\n'));
    bytes.addAll([0x1D, 0x56, 0x00]); // full cut

    return bytes;
  }

  // Print label (routes to connected transport)
  Future<bool> printLabel(ProductModel product, {String? businessName}) async {
    final data =
        buildLabel(product, businessName: businessName);

    if (_usbPort != null) {
      try {
        await _usbPort!.write(Uint8List.fromList(data));
        return true;
      } catch (_) {
        return false;
      }
    }

    if (_printCharacteristic != null) {
      try {
        const chunk = 512;
        for (var i = 0; i < data.length; i += chunk) {
          final end =
              (i + chunk) < data.length ? i + chunk : data.length;
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

    if (_savedWifiIp != null && _savedWifiIp!.isNotEmpty) {
      return printViaWifi(
          ipAddress: _savedWifiIp!, port: _savedWifiPort, data: data);
    }

    return false;
  }

  // Print receipt (routes to connected transport)
  // Priority: USB/Serial > Bluetooth > WiFi (explicit params required)

  Future<bool> printReceipt(
    OrderModel order, {
    String? businessName,
    String? footer,
    bool openDrawer = false,
    String? wifiIp,
    int wifiPort = 9100,
  }) async {
    final data = buildReceipt(order, businessName: businessName, footer: footer);
    if (openDrawer) data.addAll(openCashDrawerCommand());

    // USB / Serial
    if (_usbPort != null) {
      try {
        await _usbPort!.write(Uint8List.fromList(data));
        return true;
      } catch (_) {
        return false;
      }
    }

    // Bluetooth
    if (_printCharacteristic != null) {
      try {
        const chunk = 512;
        for (var i = 0; i < data.length; i += chunk) {
          final end = (i + chunk) < data.length ? i + chunk : data.length;
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

    // WiFi — use explicit IP, else fall back to saved config
    final ip = wifiIp ?? _savedWifiIp;
    if (ip != null && ip.isNotEmpty) {
      return printViaWifi(ipAddress: ip, port: wifiPort, data: data);
    }

    return false;
  }

  // Helpers

  List<int> _encode(String text) => text.codeUnits;

  String _pad(String left, String right, {int width = 32}) {
    final spaces = width - left.length - right.length;
    return '$left${' ' * (spaces > 0 ? spaces : 1)}$right\n';
  }
}

enum _UsbMode { usb, serial }

final printerService = PrinterService();
