#!/usr/bin/env python3
"""
Host-side mDNS probe for Matter commissionable advertisements.

This helper scans `_matterc._udp.local.` and reports whether at least one
service entry matches the expected long discriminator from TXT record `D`.
"""

from __future__ import annotations

import argparse
import json
import socket
import threading
import time
from typing import Dict, List

try:
    from zeroconf import IPVersion, ServiceBrowser, ServiceListener, Zeroconf
except Exception as exc:  # pragma: no cover - runtime dependency path
    print(
        json.dumps(
            {
                "status": "unavailable_dependency",
                "status_reason": f"missing or invalid zeroconf dependency: {exc}",
                "found": False,
                "service_count": 0,
                "match_count": 0,
                "entries": [],
            }
        )
    )
    raise SystemExit(3)


def _decode_txt_value(value: bytes | str) -> str:
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value)


def _format_addresses(info) -> List[str]:
    addresses: List[str] = []
    for raw in getattr(info, "addresses", []) or []:
        try:
            if len(raw) == 4:
                addresses.append(socket.inet_ntoa(raw))
            elif len(raw) == 16:
                addresses.append(socket.inet_ntop(socket.AF_INET6, raw))
        except OSError:
            continue
    if not addresses:
        try:
            addresses.extend(info.parsed_addresses())
        except Exception:
            pass
    return addresses


class _ProbeListener(ServiceListener):
    def __init__(self, zc: Zeroconf, service_type: str) -> None:
        self._zc = zc
        self._service_type = service_type
        self._lock = threading.Lock()
        self._entries: Dict[str, Dict[str, object]] = {}

    def remove_service(self, zc: Zeroconf, service_type: str, name: str) -> None:
        with self._lock:
            self._entries.pop(name, None)

    def add_service(self, zc: Zeroconf, service_type: str, name: str) -> None:
        self._refresh(name)

    def update_service(self, zc: Zeroconf, service_type: str, name: str) -> None:
        self._refresh(name)

    def snapshot(self) -> List[Dict[str, object]]:
        with self._lock:
            return list(self._entries.values())

    def _refresh(self, name: str) -> None:
        info = self._zc.get_service_info(self._service_type, name, timeout=2000)
        if info is None:
            return

        txt: Dict[str, str] = {}
        for key, value in (info.properties or {}).items():
            txt[_decode_txt_value(key)] = _decode_txt_value(value)

        entry = {
            "name": name,
            "type": self._service_type,
            "server": info.server or "",
            "port": int(info.port),
            "addresses": _format_addresses(info),
            "txt": txt,
        }
        with self._lock:
            self._entries[name] = entry


def main() -> int:
    parser = argparse.ArgumentParser(description="Probe commissionable Matter mDNS entries")
    parser.add_argument("--service-type", default="_matterc._udp.local.")
    parser.add_argument("--discriminator", type=int, default=1234)
    parser.add_argument("--timeout-seconds", type=int, default=6)
    args = parser.parse_args()

    if args.discriminator < 0 or args.discriminator > 4095:
        raise SystemExit("discriminator must be in range 0..4095")
    if args.timeout_seconds < 1 or args.timeout_seconds > 120:
        raise SystemExit("timeout-seconds must be in range 1..120")

    zc = Zeroconf(ip_version=IPVersion.All)
    listener = _ProbeListener(zc=zc, service_type=args.service_type)
    browser = ServiceBrowser(zc, args.service_type, listener=listener)
    del browser  # held internally by zeroconf

    time.sleep(args.timeout_seconds)
    entries = listener.snapshot()
    zc.close()

    discriminator_str = str(args.discriminator)
    matching = [
        entry
        for entry in entries
        if isinstance(entry.get("txt"), dict)
        and str(entry["txt"].get("D", "")) == discriminator_str
    ]

    status = "found" if matching else "not_found"
    status_reason = (
        "at least one commissionable entry matches requested discriminator"
        if matching
        else "no commissionable entry matched requested discriminator"
    )
    if not entries and not matching:
        status_reason = "no commissionable entries discovered on host probe"

    output = {
        "status": status,
        "status_reason": status_reason,
        "found": bool(matching),
        "service_count": len(entries),
        "match_count": len(matching),
        "entries": entries,
    }
    print(json.dumps(output))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
