"""Run saved-plan Canadian lifecycle stages from an exact clean merged checkout."""

# pylint: disable=too-many-statements,consider-using-with
# ruff: noqa: TRY003, EM101, S603, S310

import argparse
import fcntl
import hashlib
import json
import os
import re
import subprocess
import time
import urllib.error
import urllib.request
from http import HTTPStatus
from pathlib import Path
from typing import Any

from plan_scope import validate

REPOSITORY = "f5-sales-demo/canada"


def run(argv: list[str], cwd: Path) -> str:
    """Run a fixed executable with exact argument transport."""
    return subprocess.check_output(argv, cwd=cwd, text=True)


def main() -> None:
    """Execute the selected scoped lifecycle with private state and receipts."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mode", choices=["build", "verify", "destroy", "full"], required=True
    )
    parser.add_argument("--tfvars", type=Path, required=True)
    parser.add_argument("--backend-config", type=Path, required=True)
    parser.add_argument("--private-root", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sha = run(["git", "rev-parse", "HEAD"], root).strip()
    if run(["git", "status", "--porcelain"], root).strip():
        raise ValueError("lifecycle requires clean source")
    remote = run(["git", "ls-remote", "origin", "refs/heads/main"], root).split()[0]
    if sha != remote:
        raise ValueError("lifecycle requires exact merged main")
    if args.private_root.resolve().is_relative_to(root):
        raise ValueError("evidence must be outside the repository")
    os.umask(0o077)
    args.private_root.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock_path = Path("/data/robin-GIT/.private-task-evidence/canada-topology.lock")
    lock = lock_path.open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    backend_text = args.backend_config.read_text()

    match = re.fullmatch(r'\s*path\s*=\s*"([^"]+)"\s*', backend_text)
    if not match:
        raise ValueError(
            "local backend config must contain only an absolute state path"
        )
    state_path = Path(match.group(1))
    if not state_path.is_absolute() or state_path.resolve().is_relative_to(root):
        raise ValueError("local state must be absolute and outside the checkout")
    state_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if state_path.parent.stat().st_mode & 0o077:
        raise ValueError("local state directory must have mode 0700")
    for file in [args.tfvars, args.backend_config]:
        if file.stat().st_mode & 0o077:
            raise ValueError("private inputs must have mode 0600 or stricter")
    run(
        [
            "python3",
            "scripts/verify-showcase-provider.py",
            "--private-root",
            str(args.private_root / "provider"),
        ],
        root,
    )
    tf = ["terraform", "-chdir=" + str(root / "terraform")]
    run(
        [
            *tf,
            "init",
            "-input=false",
            "-lockfile=readonly",
            "-reconfigure",
            "-backend-config=" + str(args.backend_config),
        ],
        root,
    )
    common = [
        "-input=false",
        "-refresh=true",
        "-var-file=" + str(args.tfvars),
        "-var=source_repository=" + REPOSITORY,
        "-var=source_ref=refs/heads/main",
        "-var=source_commit_sha=" + sha,
    ]

    def output(name: str) -> Any:
        return json.loads(run([*tf, "output", "-json", name], root))

    def saved(
        stage: str, mode: str, phase: str = "configured", apply: bool = True
    ) -> None:
        plan = args.private_root / (stage + ".tfplan")
        cmd = [
            *tf,
            "plan",
            *common,
            "-var=azure_site_configuration_phase=" + phase,
            "-out=" + str(plan),
        ]
        if mode == "destroy":
            cmd.append("-destroy")
        with (args.private_root / (stage + ".log")).open("w") as log:
            subprocess.run(cmd, cwd=root, stdout=log, stderr=log, check=True)
        data = json.loads(run([*tf, "show", "-json", str(plan)], root))
        validate(data, mode)
        digest = hashlib.sha256(plan.read_bytes()).hexdigest()
        (args.private_root / (stage + "-review.json")).write_text(
            json.dumps(
                {"source_commit": sha, "mode": mode, "saved_plan_sha256": digest}
            )
        )
        if apply:
            if hashlib.sha256(plan.read_bytes()).hexdigest() != digest:
                raise ValueError("saved plan changed after review")
            with (args.private_root / (stage + "-apply.log")).open("w") as log:
                subprocess.run(
                    [*tf, "apply", "-input=false", str(plan)],
                    cwd=root,
                    stdout=log,
                    stderr=log,
                    check=True,
                )

    def get(namespace: str, kind: str, name: str) -> Any:
        base = os.environ["XCSH_API_URL"]
        if not base.startswith("https://"):
            raise ValueError("XC API must use HTTPS")
        request = urllib.request.Request(
            base + "/api/config/namespaces/" + namespace + "/" + kind + "/" + name,
            headers={"Authorization": "APIToken " + os.environ["XCSH_API_TOKEN"]},
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)

    def verify(stage: str) -> None:
        identity = output("deployment_identity")
        if identity["repository"] != REPOSITORY or identity["source_commit"] != sha:
            raise ValueError("deployed provenance does not match exact merged source")
        sub = output("azure_subscription_id")
        run(
            [
                "bash",
                "scripts/verify-deployment.sh",
                "--terraform-dir",
                str(root / "terraform"),
                "--evidence-dir",
                str(args.private_root / (stage + "-routing")),
                "--subscription",
                sub,
                "--samples-per-batch",
                "40",
                "--max-batches",
                "3",
                "--batch-interval",
                "30",
                "--skip-console",
            ],
            root,
        )
        run(
            [
                "python3",
                "scripts/verify-canadian-public-re.py",
                "--terraform-dir",
                str(root / "terraform"),
                "--evidence-dir",
                str(args.private_root / (stage + "-public")),
                "--samples",
                "120",
            ],
            root,
        )
        run(
            [
                "bash",
                "scripts/verify-azure-failover.sh",
                "--terraform-dir",
                str(root / "terraform"),
                "--evidence-dir",
                str(args.private_root / (stage + "-failover")),
                "--subscription",
                sub,
                "--source-commit",
                sha,
            ],
            root,
        )
        saved(stage + "-zero", "zero", apply=False)

    def build(stage: str) -> None:
        saved(stage + "-bootstrap", "build", "bootstrap")
        # Registration and the immutable MAC mapping can lag guest boot.
        deadline = time.monotonic() + 5400
        while True:
            try:
                saved(stage + "-configured", "build")
                states = [
                    get("system", "sites", site)
                    for site in output("ca_xc_site_names").values()
                ]
                if all(
                    (obj.get("spec") or obj.get("get_spec", {})).get("site_state")
                    == "ONLINE"
                    for obj in states
                ):
                    break
            except subprocess.CalledProcessError:
                if time.monotonic() >= deadline:
                    raise
            if time.monotonic() >= deadline:
                raise TimeoutError("three Canadian CEs did not become ONLINE")
            time.sleep(30)
        verify(stage)

    def destroy(stage: str) -> None:
        inventory = {
            "group": output("ca_resource_group_name"),
            "sites": list(output("ca_xc_site_names").values()),
            "public": output("canada_public_re"),
            "subscription": output("azure_subscription_id"),
            "app_namespace": "canada",
            "app_objects": [
                ("http_loadbalancers", output("ca_loadbalancer_name")),
                (
                    "http_loadbalancers",
                    output("canada_public_re")["internal_loadbalancer"],
                ),
                ("service_policys", output("canada_public_re")["service_policy"]),
                ("origin_pools", output("ca_origin_pool_name")),
                ("virtual_sites", output("ca_ce_virtual_site_name")),
            ],
        }
        (args.private_root / (stage + "-inventory.json")).write_text(
            json.dumps(inventory)
        )
        saved(stage, "destroy")
        present = json.loads(
            run(
                [
                    "az",
                    "group",
                    "exists",
                    "--name",
                    inventory["group"],
                    "--subscription",
                    inventory["subscription"],
                ],
                root,
            )
        )
        if present:
            raise ValueError("owned Canadian Azure group remains after destroy")
        for site in inventory["sites"]:
            try:
                get("system", "sites", site)
            except urllib.error.HTTPError as error:
                if error.code != HTTPStatus.NOT_FOUND:
                    raise
            else:
                raise ValueError("Canadian XC site remains after destroy")
        for kind, name in inventory["app_objects"]:
            try:
                get(inventory["app_namespace"], kind, name)
            except urllib.error.HTTPError as error:
                if error.code != HTTPStatus.NOT_FOUND:
                    raise
            else:
                raise ValueError("Canadian application object remains after destroy")
        allocation = inventory["public"]["allocation"]
        get(allocation["namespace"], "public_ips", allocation["name"])
        (args.private_root / (stage + "-absence.json")).write_text(
            json.dumps(
                {
                    "status": "passed",
                    "source_commit": sha,
                    "azure_group_absent": True,
                    "three_ce_sites_absent": True,
                    "reserved_allocation_retained": True,
                }
            )
        )

    if args.mode == "build":
        build("build")
    elif args.mode == "verify":
        verify("verify")
    elif args.mode == "destroy":
        destroy("destroy")
    else:
        build("first")
        destroy("first-destroy")
        build("second")
    print("PASS: Canada Topology lifecycle " + args.mode)


if __name__ == "__main__":
    main()
