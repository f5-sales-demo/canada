#!/usr/bin/env python3
"""Validate private traffic receipts against XC classification of observed sources."""

# pylint: disable=invalid-name
# ruff: noqa: EM101, TRY003
import argparse
import json
from pathlib import Path
from http import HTTPStatus

MINIMUM_SAMPLES = 120


def validate(receipt: dict) -> None:
    """Require Canadian success and independently classified negative evidence."""
    if receipt.get("domain") != "canada.f5-sales-demo.ca":
        raise ValueError("exact public hostname required")
    if not receipt.get("source_commit") or not receipt.get("dns_matches_allocation"):
        raise ValueError("source and DNS evidence required")
    canadian = receipt.get("canadian", {})
    if canadian.get("samples", 0) < MINIMUM_SAMPLES or canadian.get("failures") != 0:
        raise ValueError("120 successful Canadian requests required")
    if canadian.get("country") != "CA" or not canadian.get("observed_egress"):
        raise ValueError("XC Canadian source classification required")
    if canadian.get("xc_source_ip") != canadian["observed_egress"]:
        raise ValueError("XC Canadian source must equal observed egress")
    if not canadian.get("exact_origin"):
        raise ValueError("exact Canadian origin required")
    negative = receipt.get("negative", [])
    if not negative:
        raise ValueError("classified non-Canadian source evidence required")
    variants = {"plain", "x-forwarded-for", "forwarded", "x-real-ip"}
    for source in negative:
        if source.get("country") in (None, "", "CA"):
            raise ValueError("non-Canadian XC classification required")
        if (
            not source.get("observed_egress")
            or source.get("xc_source_ip") != source["observed_egress"]
        ):
            raise ValueError("negative XC source must equal observed egress")
        results = source.get("requests", [])
        if {item.get("variant") for item in results} != variants:
            raise ValueError("plain and all spoofed forwarding-header tests required")
        if any(
            item.get("status") != HTTPStatus.FORBIDDEN
            or not item.get("xc_policy_denial")
            for item in results
        ):
            raise ValueError("all negative requests must be denied by XC policy")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()
    validate(json.loads(args.receipt.read_text()))
    print(
        "PASS: country traffic receipts bound to observed egress and XC classification"
    )
