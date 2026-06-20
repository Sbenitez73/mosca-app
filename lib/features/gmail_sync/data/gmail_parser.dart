import 'dart:convert';

class ParsedTransaction {
  final double amount;
  final String currency;
  final String? merchant;
  final String? bankName;
  final String? cardLastFour;
  final DateTime date;
  final String gmailMessageId;

  const ParsedTransaction({
    required this.amount,
    required this.currency,
    this.merchant,
    this.bankName,
    this.cardLastFour,
    required this.date,
    required this.gmailMessageId,
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

    return ParsedTransaction(
      amount: result.amount,
      currency: result.currency,
      merchant: _parseMerchant(content, bank),
      cardLastFour: _parseCard(content),
      bankName: bank,
      date: _parseEmailDate(dateStr),
      gmailMessageId: messageId,
    );
  }

  // ─── Bank detection ──────────────────────────────────────────────────────────

  static const _bankDomains = {
    'Bancolombia': ['bancolombia.com'],
    'Nequi':       ['nequi.com.co', 'nequi'],
    'Davivienda':  ['davivienda.com'],
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

  // Keywords whose presence means the email is NOT a purchase (deposits,
  // transfers received, promotional, statements, etc.)
  static const _globalRejectKeywords = [
    'recibiste',
    'te enviaron',
    'abono',
    'consignación',
    'depósito recibido',
    'transferencia recibida',
    'pago de nómina',
    'reembolso',
    'devolución',
    'extracto',
    'resumen de cuenta',
    'estado de cuenta',
    'saldo disponible',
    'tu saldo es',
    'cupo disponible',
    'crédito aprobado',
    'promoción',
    'oferta especial',
    'newsletter',
    'aviso de privacidad',
  ];

  // Bank-specific keywords that CONFIRM a debit/purchase notification.
  // At least one must appear in subject or body.
  static const _bankDebitKeywords = {
    'Bancolombia': [
      'realizaste un pago',
      'realizaste una compra',
      'compra aprobada',
      'usaste tu tarjeta',
      'débito',
      'cargo en tu cuenta',
      'retiraste',
      'retiro en',
      'pagaste',
    ],
    'Nequi': [
      'pagaste',
      'enviaste',
      'realizaste un pago',
      'compraste',
    ],
    'Davivienda': [
      'compra aprobada',
      'realizó una compra',
      'cargo realizado',
      'débito en cuenta',
      'transacción aprobada',
    ],
    'BBVA': [
      'cargo realizado',
      'compra realizada',
      'realizaste un cargo',
      'débito',
      'transacción realizada',
    ],
    'Nubank': [
      'compra aprovada',
      'você comprou',
      'você pagou',
      'cobran',
      'pagamento realizado',
      'compra realizada',
    ],
    'Falabella': [
      'cargo en tu',
      'compra realizada',
      'realizaste una compra',
      'cmr débito',
      'cargo cmr',
    ],
  };

  static bool _isDebitTransaction(String subject, String body, String bank) {
    final content = '${subject.toLowerCase()} ${body.toLowerCase()}';

    // Immediate reject if any non-purchase signal is found
    if (_globalRejectKeywords.any((k) => content.contains(k))) return false;

    // Must match at least one bank-specific purchase keyword
    final keywords = _bankDebitKeywords[bank] ?? [];
    return keywords.any((k) => content.contains(k));
  }

  // ─── Amount parsing ──────────────────────────────────────────────────────────

  static _AmountResult? _parseAmount(String content, String bank) {
    final patterns = [
      RegExp(r'\$([\d]{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)'),
      RegExp(r'R\$([\d]{1,3}(?:\.\d{3})*(?:,\d{1,2})?)'),
      RegExp(r'USD\s+([\d,.]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final raw = match.group(1)!;
        final amount = _normalizeAmount(raw, bank);
        if (amount != null && amount > 0) {
          final currency = pattern.pattern.startsWith('R\$') ? 'BRL' : 'COP';
          return _AmountResult(amount: amount, currency: currency);
        }
      }
    }
    return null;
  }

  static double? _normalizeAmount(String raw, String bank) {
    // All LatAm banks use European notation: '.' = thousands, ',' = decimal.
    // $2.700.000,00 → 2700000.00  |  $2.700.000 → 2700000  |  R$1.234,56 → 1234.56
    if (raw.contains(',')) {
      return double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.'));
    }
    return double.tryParse(raw.replaceAll('.', ''));
  }

  // ─── Merchant / card ─────────────────────────────────────────────────────────

  static final _merchantPatterns = [
    // "en CC_VICTOPZ2 de tu" / "en Rappi con Tarj"
    RegExp(r'en\s+([A-Z][A-Za-z0-9\s&.,_\-]{2,40}?)(?:\s+de\s+tu|\s+con\s+|\s+Tarj|\.|$)', multiLine: true),
    RegExp(r'comercio[:\s]+([A-Za-z0-9\s&.,_\-]{2,40})', caseSensitive: false),
    RegExp(r'establecimiento[:\s]+([A-Za-z0-9\s&.,_\-]{2,40})', caseSensitive: false),
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
      final parts = List<Map<String, dynamic>>.from(payload['parts'] as List? ?? []);
      for (final part in parts) {
        if (part['mimeType'] == 'text/plain') {
          final encoded = (part['body'] as Map?)?['data'] as String?;
          if (encoded != null) return _decodeBase64(encoded);
        }
      }
      final encoded = (payload['body'] as Map?)?['data'] as String?;
      if (encoded != null) return _decodeBase64(encoded);
    } catch (_) {}
    return '';
  }

  static String _decodeBase64(String encoded) {
    final normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');
    return utf8.decode(base64.decode(base64.normalize(normalized)));
  }

  static DateTime _parseEmailDate(String dateStr) {
    try {
      final cleaned = dateStr.replaceAll(RegExp(r'\s\([A-Z]+\)$'), '');
      return DateTime.parse(cleaned);
    } catch (_) {
      return DateTime.now();
    }
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
