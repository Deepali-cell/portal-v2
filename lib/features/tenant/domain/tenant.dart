import 'dart:ui';

/// Resolved tenant configuration returned by
/// `tcb_portal_control.api.tenant.resolve` on the middleware.
///
/// Holds the bare minimum the mobile needs to (a) point Dio at the
/// customer's ERPNext and (b) theme the login screen in the tenant's
/// colours. No credentials, no internal IDs.
class Tenant {
  const Tenant({
    required this.companyId,
    required this.companyName,
    required this.serverUrl,
    required this.colorP1,
    required this.colorP2,
    required this.colorP3,
    this.logoUrl,
  });

  final String companyId;
  final String companyName;
  final String serverUrl;
  final Color colorP1;
  final Color colorP2;
  final Color colorP3;
  final String? logoUrl;

  Tenant copyWith({
    String? companyId,
    String? companyName,
    String? serverUrl,
    Color? colorP1,
    Color? colorP2,
    Color? colorP3,
    String? logoUrl,
    bool clearLogoUrl = false,
  }) {
    return Tenant(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      serverUrl: serverUrl ?? this.serverUrl,
      colorP1: colorP1 ?? this.colorP1,
      colorP2: colorP2 ?? this.colorP2,
      colorP3: colorP3 ?? this.colorP3,
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
    );
  }

  factory Tenant.fromResolveResponse(Map<String, dynamic> json) {
    return Tenant(
      companyId: json['company_id'] as String,
      companyName: json['company_name'] as String,
      serverUrl: (json['server_url'] as String).trim(),
      colorP1: _parseHex(json['color_p1'] as String?, fallback: 0xFFFFFFFF),
      colorP2: _parseHex(json['color_p2'] as String?, fallback: 0xFF022B60),
      colorP3: _parseHex(json['color_p3'] as String?, fallback: 0xFF1F4FD8),
      logoUrl: (json['logo_url'] as String?)?.trim().isEmpty == true
          ? null
          : json['logo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'company_name': companyName,
        'server_url': serverUrl,
        'color_p1': _toHex(colorP1),
        'color_p2': _toHex(colorP2),
        'color_p3': _toHex(colorP3),
        'logo_url': logoUrl,
      };

  factory Tenant.fromJson(Map<String, dynamic> json) =>
      Tenant.fromResolveResponse(json);

  /// Built-in default — used as the very first theme on a fresh install,
  /// before any tenant is resolved. Matches TCB Infotech's brand.
  static const Tenant tcbDefault = Tenant(
    companyId: 'TCB',
    companyName: 'TCB Portal',
    serverUrl: '',
    colorP1: Color(0xFFFFFFFF),
    colorP2: Color(0xFF022B60),
    colorP3: Color(0xFF1F4FD8),
  );
}

Color _parseHex(String? hex, {required int fallback}) {
  if (hex == null || hex.isEmpty) return Color(fallback);
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? Color(fallback) : Color(v);
}

String _toHex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
