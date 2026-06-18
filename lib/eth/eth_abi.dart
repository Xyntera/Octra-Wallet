/// Hand-rolled ABI calldata encoders for the OCT <-> wOCT bridge.
///
/// These match the official webcli bridge reference (static/bridge.js)
/// byte-for-byte. The reference does not use an ABI library; it builds calldata
/// as selector + 32-byte words, so we replicate that exactly to stay
/// bug-for-bug compatible with the deployed contracts.
class EthAbi {
  EthAbi._();

  /// `balanceOf(address)`
  static const String balanceOfSelector = '0x70a08231';

  /// `approve(address,uint256)`
  static const String approveSelector = '0x095ea7b3';

  /// `burn(string,uint256)` on the EthereumBridge — the Octra recipient is
  /// passed as a Solidity dynamic string (the raw `oct...` address).
  static const String burnSelector = '0xe3e3aed0';

  static String _strip0x(String h) =>
      (h.startsWith('0x') || h.startsWith('0X')) ? h.substring(2) : h;

  static String _word(String hexNo0x) {
    if (hexNo0x.length > 64) {
      throw ArgumentError('value exceeds 32 bytes: $hexNo0x');
    }
    return hexNo0x.padLeft(64, '0');
  }

  /// Left-pads a 20-byte address into a 32-byte word (lowercased, no checksum).
  static String _addressWord(String address) =>
      _word(_strip0x(address).toLowerCase());

  static String _uintWord(BigInt value) {
    if (value.isNegative) throw ArgumentError('negative amount');
    return _word(value.toRadixString(16));
  }

  /// ERC-20 `balanceOf(holder)` calldata.
  static String balanceOf(String holder) =>
      '$balanceOfSelector${_addressWord(holder)}';

  /// ERC-20 `approve(spender, amount)` calldata. The bridge approves the exact
  /// amount (not max-uint), matching the reference.
  static String approve(String spender, BigInt amount) =>
      '$approveSelector${_addressWord(spender)}${_uintWord(amount)}';

  /// EthereumBridge `burn(octraAddress, amount)` calldata.
  ///
  /// Layout (matches static/bridge.js `abiEncodeStringUint`):
  ///   selector | offset(0x40) | amount | strLen | asciiBytes(rightPadded)
  /// The Octra address is encoded as its raw ASCII characters — NOT hashed and
  /// NOT base58-decoded.
  static String burn(String octraAddress, BigInt amount) {
    final offset = _word('40'); // two head words; string tail starts at 0x40
    final amountWord = _uintWord(amount);
    final lenWord = _word(octraAddress.length.toRadixString(16));
    final sb = StringBuffer();
    for (final unit in octraAddress.codeUnits) {
      if (unit > 0x7f) {
        throw ArgumentError('non-ASCII byte in Octra address');
      }
      sb.write(unit.toRadixString(16).padLeft(2, '0'));
    }
    var strHex = sb.toString();
    while (strHex.length % 64 != 0) {
      strHex += '0';
    }
    return '$burnSelector$offset$amountWord$lenWord$strHex';
  }
}
