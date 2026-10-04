"""Validate the complete saved-plan ownership and action boundary."""

# ruff: noqa: TRY003, EM101

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOTS = {
    "module.azure_hub_ca",
    "module.ce_topology_ca",
    "module.ce_node_ca",
    "module.ce_vm_ca",
    "module.xc_site_ca",
    "module.azure_frr_ca",
    "module.client_vm_ca",
    "module.showcase_origin_ca",
    "module.azure_ilb_application_ca",
    "xcsh_namespace.canada",
    "xcsh_token.ce",
    "random_password.site_console_admin_ca",
    "azurerm_virtual_machine_extension.site_console_password_ca",
    "xcsh_virtual_site.canada_re",
    "xcsh_virtual_site.canada_ce",
    "xcsh_origin_pool.canada",
    "xcsh_http_loadbalancer.canada",
    "xcsh_http_loadbalancer.internal",
    "xcsh_service_policy.canada_only",
    "xcsh_public_ip_binding.canada",
    "terraform_data.canada_public_ip_gate",
    "terraform_data.deployment_guard",
    "terraform_data.origin_f5_acl_gate",
    "azurerm_lb.ca_ilb",
    "azurerm_lb_backend_address_pool.ca_ce_backend",
    "azurerm_network_interface_backend_address_pool_association.ca_ce",
    "azurerm_lb_probe.ca_site_console",
    "azurerm_lb_rule.ca_application",
    "azurerm_lb_rule.ca_console",
}


def normalize_ce_readback(value: Any) -> Any:
    """Ignore only omitted false interface flags returned by XC."""
    if isinstance(value, dict):
        return {
            key: normalize_ce_readback(item)
            for key, item in value.items()
            if not (key in {"is_management", "is_primary"} and item is False)
        }
    if isinstance(value, list):
        return [normalize_ce_readback(item) for item in value]
    return value


def validate(plan: dict, mode: str) -> None:
    """Reject foreign managed objects and inappropriate actions."""
    for resource in plan.get("resource_changes", []):
        actions = resource["change"]["actions"]
        if resource.get("mode") == "data":
            continue
        address = resource["address"]
        if not any(
            address == root or address.startswith((root + "[", root + "."))
            for root in ROOTS
        ):
            raise ValueError("foreign resource in Canadian plan: " + address)
        if mode == "namespace" and actions != ["no-op"]:
            before = resource["change"].get("before") or {}
            after = resource["change"].get("after") or {}
            migrating_namespace = address == "xcsh_namespace.canada" and (
                before.get("name") == "canada-topology"
                and after.get("name") == "canada"
            )
            migrating_application = (
                address.startswith(
                    (
                        "xcsh_http_loadbalancer.",
                        "xcsh_origin_pool.",
                        "xcsh_service_policy.",
                        "xcsh_virtual_site.canada_ce",
                        "module.azure_ilb_application_ca",
                    )
                )
                and before.get("namespace") == "canada-topology"
                and after.get("namespace") == "canada"
            )
            provenance = actions == ["update"] and all(
                before.get(key) == after.get(key)
                for key in set(before) | set(after)
                if key not in {"labels", "tags", "description"}
            )
            if resource.get("type") == "xcsh_securemesh_site_v2" and actions == [
                "update"
            ]:
                provenance = all(
                    normalize_ce_readback(before.get(key))
                    == normalize_ce_readback(after.get(key))
                    for key in set(before) | set(after)
                    if key not in {"labels", "description"}
                )
            if address == "terraform_data.deployment_guard" and actions == ["update"]:
                provenance = before.get("input", {}).get("tenant") == after.get(
                    "input", {}
                ).get("tenant")
            if not (migrating_namespace or migrating_application or provenance):
                raise ValueError(
                    "namespace migration changes unrelated infrastructure: " + address
                )
        if mode == "application" and actions != ["no-op"]:
            application = address.startswith(
                (
                    "xcsh_http_loadbalancer.",
                    "xcsh_service_policy.",
                    "module.azure_ilb_application_ca",
                )
            )
            provenance = actions == ["update"] and all(
                resource["change"].get("before", {}).get(key)
                == resource["change"].get("after", {}).get(key)
                for key in set(resource["change"].get("before", {}))
                | set(resource["change"].get("after", {}))
                if key not in {"labels", "tags", "description"}
            )
            if address == "terraform_data.deployment_guard" and actions == ["update"]:
                before = resource["change"].get("before", {}).get("input", {})
                after = resource["change"].get("after", {}).get("input", {})
                provenance = (
                    set(after) == {"commit", "tenant"}
                    and before.get("tenant") == after.get("tenant")
                    and re.fullmatch(r"[0-9a-f]{40}", after.get("commit", ""))
                    is not None
                )
            if not application and not provenance:
                raise ValueError(
                    "application cutover changes infrastructure: " + address
                )
            if not application and ("delete" in actions or "create" in actions):
                raise ValueError(
                    "application cutover replaces infrastructure: " + address
                )
        if mode == "destroy" and actions not in (["delete"], ["no-op"]):
            raise ValueError("destroy includes a non-deletion: " + address)
        if mode == "zero" and actions != ["no-op"]:
            raise ValueError("zero-change gate includes a resource action: " + address)
    if mode == "zero" and any(
        change["actions"] != ["no-op"]
        for change in plan.get("output_changes", {}).values()
    ):
        raise ValueError("zero-change gate includes output changes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan")
    parser.add_argument(
        "--mode",
        choices=["build", "destroy", "zero", "application", "namespace"],
        required=True,
    )
    args = parser.parse_args()
    with Path(args.plan).open(encoding="utf-8") as source:
        validate(json.load(source), args.mode)
    print("PASS: Canadian saved-plan scope " + args.mode)
