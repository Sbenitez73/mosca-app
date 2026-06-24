import 'dart:convert';
import '../../../features/expenses/data/models/transaction_type.dart';

class ParsedTransaction {
  final double amount;
  final String currency;
  final String? merchant;
  final String? bankName;
  final String? cardLastFour;
  final DateTime date;
  final String gmailMessageId;
  final TransactionType transactionType;

  const ParsedTransaction({
    required this.amount,
    required this.currency,
    this.merchant,
    this.bankName,
    this.cardLastFour,
    required this.date,
    required this.gmailMessageId,
    this.transactionType = TransactionType.expense,
  });
}

class GmailParser {
  static ParsedTransaction? parse(Map<String, dynamic> emailData, String messageId) {
    final subject = _header(emailData, 'Subject') ?? '';
    final from    = _header(emailData, 'From') ?? '';
    final dateStr = _header(emailData, 'Date') ?? '';
    final body    = _decodeBody(emailData);

    final bank = _detectBank(from);
    if (bank == null) return null;

    // Reject emails that are clearly not purchase notifications
    if (!_isDebitTransaction(subject, body, bank)) return null;

    final content = '$subject\n$body';
    final result  = _parseAmount(content, bank);
    if (result == null) return null;

    final isWithdrawal = _isWithdrawal(subject, body);

    return ParsedTransaction(
      amount: result.amount,
      currency: result.currency,
      merchant: _parseMerchant(content, bank),
      cardLastFour: _parseCard(content),
      bankName: bank,
      date: _parseEmailDate(dateStr),
      gmailMessageId: messageId,
      transactionType: isWithdrawal ? TransactionType.transfer : TransactionType.expense,
    );
  }

  // ─── Bank detection ──────────────────────────────────────────────────────────

  static const _bankDomains = {
    'Bancolombia': ['bancolombia.com'],
    'Nequi':       ['nequi.com.co', 'nequi'],
    'Davivienda':  ['davivienda.com', 'davibank.com'],
    'Nubank':      ['nubank.com.br', 'nu.com.co'],
    'BBVA':        ['bbva.com.co', 'bbva.com'],
    'Falabella':   ['falabella.com', 'cmr'],
  };

  static String? _detectBank(String from) {
    final lower = from.toLowerCase();
    for (final entry in _bankDomains.entries) {
      if (entry.value.any((d) => lower.contains(d))) return entry.key;
    }
    return null;
  }

  // ─── Transaction type validation ─────────────────────────────────────────────

  // Opt-in: the email must contain at least one phrase that confirms a real debit.
  // This rejects marketing, welcome, loyalty, statement, and promotional emails
  // without having to enumerate every possible reject keyword.
  static const _transactionKeywords = [
    // Purchase confirmations
    'compraste',
    'realizaste una compra',
    'realizaste un pago',
    'compra realizada',
    'compra aprobada',
    'compra exitosa',
    // Charges / debits
    'cargo a tu',
    'se realizó un cargo',
    'debitamos',
    'se debitó',
    'fue debitado',
    'débito en tu',
    // Withdrawals
    'retiro de',
    'retiraste',
    // Transfers sent (Bre-B, Nequi, PSE)
    'enviaste',
    'transferiste',
    // Payments made
    'pagaste',
    'pago exitoso',
    'pago realizado',
    'pago procesado',
    // Transaction approved
    'transacción aprobada',
    'transacción realizada',
    // Generic charge notice
    'cobro de',
    'se realizó el cobro',
    // DAVIbank credit card
    'realizaste con tu tarjeta',
  ];

  // Cash withdrawals — valid transactions but classified as transfer, not expense
  static const _withdrawalKeywords = [
    'retiraste',
    'retiro de',
    'retiro en cajero',
    'avance en cajero',
  ];

  static bool _isDebitTransaction(String subject, String body, String bank) {
    final content = '${subject.toLowerCase()} ${body.toLowerCase()}';
    return _transactionKeywords.any((k) => content.contains(k)) ||
        _withdrawalKeywords.any((k) => content.contains(k));
  }

  static bool _isWithdrawal(String subject, String body) {
    final content = '${subject.toLowerCase()} ${body.toLowerCase()}';
    return _withdrawalKeywords.any((k) => content.contains(k));
  }

  // ─── Amount parsing ──────────────────────────────────────────────────────────

  static _AmountResult? _parseAmount(String content, String bank) {
    final copPatterns = [
      RegExp(r'\$([\d]{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)'),
      // Nequi Bre-B and similar: "Enviaste de manera exitosa 20.000 a"
      RegExp(r'(?:enviaste|transferiste)\s+(?:de\s+manera\s+exitosa\s+)?([\d]{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)', caseSensitive: false),
      // DAVIbank: "Monto    71,978" (no currency symbol, tabs/spaces as separator)
      RegExp(r'monto\s+([\d]{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)', caseSensitive: false),
    ];

    for (final pattern in copPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final raw = match.group(1)!;
        final amount = _normalizeAmount(raw, bank);
        if (amount != null && amount > 0) {
          return _AmountResult(amount: amount, currency: 'COP');
        }
      }
    }

    // BRL (Nubank Brasil)
    final brlMatch = RegExp(r'R\$([\d]{1,3}(?:\.\d{3})*(?:,\d{1,2})?)').firstMatch(content);
    if (brlMatch != null) {
      final amount = _normalizeAmount(brlMatch.group(1)!, bank);
      if (amount != null && amount > 0) return _AmountResult(amount: amount, currency: 'BRL');
    }

    // USD
    final usdMatch = RegExp(r'USD\s+([\d,.]+)').firstMatch(content);
    if (usdMatch != null) {
      final amount = double.tryParse(usdMatch.group(1)!.replaceAll(',', ''));
      if (amount != null && amount > 0) return _AmountResult(amount: amount, currency: 'USD');
    }

    return null;
  }

  static double? _normalizeAmount(String raw, String bank) {
    final hasDot   = raw.contains('.');
    final hasComma = raw.contains(',');

    if (hasDot && hasComma) {
      // Whichever separator comes last is the decimal separator.
      // "184,000.00" → last is '.' → American → remove commas
      // "568.158,00" → last is ',' → European → remove dots, swap comma
      if (raw.lastIndexOf('.') > raw.lastIndexOf(',')) {
        return double.tryParse(raw.replaceAll(',', ''));
      } else {
        return double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.'));
      }
    }

    if (hasComma) {
      // Only comma: thousands if exactly 3 digits follow ("25,000"), else decimal ("1,50")
      final afterComma = raw.substring(raw.lastIndexOf(',') + 1);
      if (afterComma.length == 3) {
        return double.tryParse(raw.replaceAll(',', ''));
      }
      return double.tryParse(raw.replaceAll(',', '.'));
    }

    // Only dot (or neither): always thousands separator in LatAm ("25.000" → 25000)
    return double.tryParse(raw.replaceAll('.', ''));
  }

  // ─── Merchant / card ─────────────────────────────────────────────────────────

  static final _merchantPatterns = [
    // "en CC_VICTOPZ2 de tu" / "en Rappi con Tarj"
    RegExp(r'en\s+([A-Z][A-Za-z0-9\s&.,_\-]{2,40}?)(?:\s+de\s+tu|\s+con\s+|\s+Tarj|\.|$)', multiLine: true),
    // DAVIbank / generic: "Comercio    ANTHROPIC* CLAUDE SUB" (tabs, no colon, asterisks)
    RegExp(r'comercio\s+([A-Za-z0-9*\s&.,_\-]{2,50}?)(?:\n|$)', caseSensitive: false, multiLine: true),
    RegExp(r'establecimiento[:\s]+([A-Za-z0-9*\s&.,_\-]{2,50})', caseSensitive: false),
  ];

  static String? _parseMerchant(String content, String bank) {
    for (final p in _merchantPatterns) {
      final match = p.firstMatch(content);
      final merchant = match?.group(1)?.trim();
      if (merchant != null && merchant.length > 2) return _toTitleCase(merchant);
    }
    return null;
  }

  // Matches: "Tarjeta", "Tarj.", "T.Deb", "T.Cred", "card", ending near 4 digits
  static final _cardPattern = RegExp(r'(?:tarjeta|tarj\.?|t\.deb|t\.cred|card).*?(\d{4})', caseSensitive: false);
  static String? _parseCard(String content) => _cardPattern.firstMatch(content)?.group(1);

  // ─── Utilities ────────────────────────────────────────────────────────────────

  static String? _header(Map<String, dynamic> data, String name) {
    final headers = List<Map<String, dynamic>>.from(
      (data['payload'] as Map?)?['headers'] as List? ?? [],
    );
    for (final h in headers) {
      if (h['name'] == name) return h['value'] as String?;
    }
    return null;
  }

  static String _decodeBody(Map<String, dynamic> data) {
    try {
      final payload = data['payload'] as Map?;
      if (payload == null) return '';
      return _extractPlainText(payload) ?? '';
    } catch (_) {}
    return '';
  }

  // Recursively searches nested multipart structure for a text/plain part.
  // Handles: multipart/mixed > multipart/alternative > text/plain, etc.
  static String? _extractPlainText(Map<dynamic, dynamic> part) {
    final mimeType = part['mimeType'] as String? ?? '';

    if (mimeType == 'text/plain') {
      final encoded = (part['body'] as Map?)?['data'] as String?;
      if (encoded != null && encoded.isNotEmpty) return _decodeBase64(encoded);
    }

    final parts = part['parts'] as List?;
    if (parts != null) {
      for (final p in parts) {
        final result = _extractPlainText(Map<dynamic, dynamic>.from(p as Map));
        if (result != null && result.isNotEmpty) return result;
      }
    }

    // Fallback: single-part email with body directly in payload
    if (!mimeType.startsWith('multipart/')) {
      final encoded = (part['body'] as Map?)?['data'] as String?;
      if (encoded != null && encoded.isNotEmpty) return _decodeBase64(encoded);
    }

    return null;
  }

  static String _decodeBase64(String encoded) {
    final normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');
    return utf8.decode(base64.decode(base64.normalize(normalized)));
  }

  static const _monthMap = {
    'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
    'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
    'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
  };

  static DateTime _parseEmailDate(String dateStr) {
    try {
      return DateTime.parse(dateStr.trim());
    } catch (_) {}

    try {
      // RFC 2822: "Mon, 19 Jun 2026 12:38:00 +0500 (COT)"
      var s = dateStr
          .replaceAll(RegExp(r'\s*\([A-Za-z]+\)\s*$'), '') // strip "(COT)"
          .replaceAll(RegExp(r'^[A-Za-z]{3},\s*'), '')     // strip "Mon, "
          .trim();
      _monthMap.forEach((name, n) => s = s.replaceFirst(name, n));
      // s is now "19 06 2026 12:38:00 +0500"
      final parts = s.split(RegExp(r'\s+'));
      if (parts.length >= 4) {
        final day   = parts[0].padLeft(2, '0');
        final month = parts[1];
        final year  = parts[2];
        final time  = parts[3];
        final tzRaw = parts.length >= 5 ? parts[4] : '+00:00';
        final tz    = tzRaw.length == 5
            ? '${tzRaw.substring(0, 3)}:${tzRaw.substring(3)}'
            : tzRaw;
        return DateTime.parse('$year-$month-${day}T$time$tz').toLocal();
      }
    } catch (_) {}

    return DateTime.now();
  }

  static String _toTitleCase(String input) {
    return input
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _AmountResult {
  final double amount;
  final String currency;
  const _AmountResult({required this.amount, required this.currency});
}
