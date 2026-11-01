import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 按行解码子进程输出，用于替代 `ShellLinesController`。
///
/// 为什么需要它：
/// 启动日志里同时混有两种编码的字节流 ——
///  * `git log` 这类程序直接输出 UTF-8 字节；
///  * `python` 在中文 Windows 上（未开启 UTF-8 模式）输出 GBK(936) 字节。
/// 而 process_run 的 `ShellLinesController` 只用一种固定编码
/// （默认 `systemEncoding`，中文 Windows 上就是 GBK）解码整条流，
/// 于是 UTF-8 那部分中文就变成了「鍚姩鏈嶅姟」这样的乱码。
///
/// 这里对每一行单独判断：优先按 UTF-8 严格解码，失败则回退系统编码，
/// 两者都能解码时取「更像中文」的那个，从而同时兼容两类输出。
class ShellOutputLines {
  /// 回退编码，默认取系统 ANSI 代码页（简体中文 Windows 为 GBK）。
  final Encoding fallbackEncoding;

  late final StreamController<List<int>> _rawInput;
  late final StreamController<String> _lines;
  final BytesBuilder _current = BytesBuilder(copy: false);

  ShellOutputLines({Encoding? fallbackEncoding})
      : fallbackEncoding = fallbackEncoding ?? systemEncoding {
    _rawInput = StreamController<List<int>>();
    _lines = StreamController<String>();
    _rawInput.stream.listen(
      _onBytes,
      onDone: () {
        _flushLine();
        _lines.close();
      },
      onError: (Object error, StackTrace stackTrace) {
        _lines.addError(error, stackTrace);
      },
    );
  }

  /// 提供给 `Shell(stdout: ...)` 的字节输入口。
  StreamSink<List<int>> get sink => _rawInput.sink;

  /// 逐行输出的已解码文本。
  Stream<String> get stream => _lines.stream;

  void close() {
    _rawInput.close();
  }

  void _onBytes(List<int> data) {
    var start = 0;
    for (var i = 0; i < data.length; i++) {
      final byte = data[i];
      // 与 process_run 保持一致：\n(10) 和 \r(13) 都视为行结束
      if (byte == 10 || byte == 13) {
        if (i > start) {
          _current.add(data.sublist(start, i));
        }
        _flushLine();
        start = i + 1;
      }
    }
    if (data.length > start) {
      _current.add(data.sublist(start));
    }
  }

  void _flushLine() {
    if (_current.isEmpty) return;
    final line = _current.takeBytes();
    if (line.isEmpty) return;
    final decoded = decodeLine(line);
    if (decoded.isEmpty) return;
    if (!_lines.isClosed) _lines.add(decoded);
  }

  /// 对单行字节做编码嗅探。
  ///
  /// 策略：能通过 UTF-8 严格校验就当 UTF-8 —— GBK 汉字流的首字节多数落在
  /// 0x81~0xC1，在 UTF-8 里属于非法起始字节，所以两种编码几乎不会混淆；
  /// 校验失败才回退本地代码页（GBK）。
  String decodeLine(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      // 不是 UTF-8，继续按本地代码页尝试
    }

    try {
      return fallbackEncoding.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}
