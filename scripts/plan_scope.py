"""Validate the complete saved-plan ownership and action boundary."""

# ruff: noqa: TRY003, EM101

import argparse
import json
from pathlib import Path

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
    parser.add_argument("--mode", choices=["build", "destroy", "zero"], required=True)
    args = parser.parse_args()
    with Path(args.plan).open(encoding="utf-8") as source:
        validate(json.load(source), args.mode)
    print("PASS: Canadian saved-plan scope " + args.mode)
