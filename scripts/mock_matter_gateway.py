#!/usr/bin/env python3
"""
Minimalny emulator commissionable mDNS dla testow bramki/discovery.

Publikuje usluge `_matterc._udp.local.` z podstawowymi rekordami TXT,
aby kontroler (chip-tool discover) mogl znalezc wpis commissionable.
"""

from __future__ import annotations

import argparse
import socket
import sys
import time
from typing import Dict, List

from zeroconf import IPVersion, ServiceInfo, Zeroconf


def _default_ipv4() -> str:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    finally:
        sock.close()


def _txt_properties(args: argparse.Namespace) -> Dict[str, str]:
    return {
        "D": str(args.discriminator),  # Long discriminator
        "VP": f"{args.vendor_id}+{args.product_id}",
        "CM": str(args.commissioning_mode),
        "DT": str(args.device_type),
        "DN": args.device_name,
        "PH": str(args.pairing_hint),
        "PI": args.pairing_instruction,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="uMatter mock Matter gateway/discovery advertiser")
    parser.add_argument("--instance", default="uMatter-Mock-Gateway", help="Service instance name")
    parser.add_argument("--service-type", default="_matterc._udp.local.", help="mDNS service type")
    parser.add_argument("--port", type=int, default=5540, help="Published UDP port")
    parser.add_argument("--address", default="", help="IPv4 address to advertise")
    parser.add_argument("--discriminator", type=int, default=1234)
    parser.add_argument("--vendor-id", type=int, default=0xFFF1)
    parser.add_argument("--product-id", type=int, default=0x8000)
    parser.add_argument("--device-type", type=int, default=0x0100)
    parser.add_argument("--device-name", default="uMatter Mock Device")
    parser.add_argument("--commissioning-mode", type=int, default=1)
    parser.add_argument("--pairing-hint", type=int, default=33)
    parser.add_argument("--pairing-instruction", default="Use chip-tool")
    parser.add_argument("--enable-subtypes", action="store_true", default=True)
    parser.add_argument("--disable-subtypes", dest="enable_subtypes", action="store_false")
    parser.add_argument("--lifetime-seconds", type=int, default=0, help="0 means run until Ctrl+C")
    args = parser.parse_args()

    if args.discriminator < 0 or args.discriminator > 4095:
        print("discriminator must be 0..4095", file=sys.stderr)
        return 2
    if args.port < 1 or args.port > 65535:
        print("port must be 1..65535", file=sys.stderr)
        return 2

    ipv4 = args.address.strip() or _default_ipv4()
    properties = _txt_properties(args)
    service_name = f"{args.instance}.{args.service_type}"
    server = f"{args.instance}.local."

    def build_info(service_type: str) -> ServiceInfo:
        return ServiceInfo(
            type_=service_type,
            name=f"{args.instance}.{service_type}",
            addresses=[socket.inet_aton(ipv4)],
            port=args.port,
            properties=properties,
            server=server,
        )

    infos: List[ServiceInfo] = [build_info(args.service_type)]
    if args.enable_subtypes:
        infos.append(build_info(f"_L{args.discriminator}._sub._matterc._udp.local."))
        infos.append(build_info(f"_S{args.discriminator & 0x0F}._sub._matterc._udp.local."))

    zc = Zeroconf(ip_version=IPVersion.V4Only)
    try:
        for info in infos:
            zc.register_service(info)
        print("MOCK_GATEWAY_STARTED")
        print(f"service_name={service_name}")
        print("service_types=" + ",".join(info.type for info in infos))
        print(f"address={ipv4}:{args.port}")
        print(f"discriminator={args.discriminator}")
        sys.stdout.flush()

        if args.lifetime_seconds > 0:
            time.sleep(args.lifetime_seconds)
        else:
            while True:
                time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        try:
            for info in reversed(infos):
                zc.unregister_service(info)
        finally:
            zc.close()
        print("MOCK_GATEWAY_STOPPED")
        sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
