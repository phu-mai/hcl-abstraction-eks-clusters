output "worker_groups" {
  value = [for k, v in local.worker_groups_launch_template : v]
}

output "worker_iam_role_arn" {
  value = module.eks.worker_iam_role_arn
}
