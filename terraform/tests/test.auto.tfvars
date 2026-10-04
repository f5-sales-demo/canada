source_repository      = "f5-sales-demo/canada"
source_ref             = "refs/heads/main"
source_commit_sha      = "1111111111111111111111111111111111111111"
deployment_owner_id    = "showcase-team"
deployment_actor_id    = "terraform-cli"
deployer               = "tester"
ca_lb_domain           = "canada.f5-sales-demo.ca"
ca_origin_ip           = "192.0.2.10"
enable_showcase_origin = false
ssh_public_key         = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKzwDqvgRGHaZqbo57o/AxuuqRNPT9MqeYNYsK1Owh8l plan-test-only"

origin_developer_cidrs = ["198.51.100.10/32", "203.0.113.20/32"]
