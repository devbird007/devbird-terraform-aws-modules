output "ssm_profile_name" {
  description = "The ssm_profile name to be attached to your ec2 instance"
  value       = aws_iam_instance_profile.ssm_profile.name
}