import 'dart:io';

import 'models.dart';

Future<List<NicChoice>> listNics() async {
  final out = <NicChoice>[NicChoice.any];
  try {
    final nics = await NetworkInterface.list(
      includeLinkLocal: false,
      type: InternetAddressType.any,
    );
    for (final nic in nics) {
      for (final addr in nic.addresses) {
        if (addr.isLoopback) continue;
        out.add(
          NicChoice(
            id: '${nic.name}|${addr.address}',
            label: '${nic.name} ${addr.address}',
            address: addr.address,
          ),
        );
      }
    }
  } catch (_) {}
  return out;
}

InternetAddress? parseBind(String? address) {
  if (address == null || address.isEmpty) return null;
  return InternetAddress.tryParse(address);
}
