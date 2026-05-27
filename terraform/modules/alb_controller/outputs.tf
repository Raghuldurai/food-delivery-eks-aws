output "iam_policy_arn" {
  value = aws_iam_policy.policy.arn
}

output "arn" {
  value = module.role.arn
}

output "service_account_name" {
  value = kubernetes_service_account_v1.alb_controller.metadata[0].name
}
