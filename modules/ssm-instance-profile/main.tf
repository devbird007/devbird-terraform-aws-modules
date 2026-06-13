# 1. This block establishes who is allowed to wear the security badge.
# It purely defines the trust relationship, it does not grant any permissions
data "aws_iam_policy_document" "ssm_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# 2. This creates the actual blank security badge and applies the
# earlier created assume-role policy.
resource "aws_iam_role" "ssm_role" {
  name               = "${var.vpc_name}-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ssm_assume_role.json

  tags = merge(
    { Name = "${var.vpc_name}-ssm-role" },
    var.tags
  )
}

# 3. This creates the permissions. So now the role possesses the permissions.
resource "aws_iam_role_policy_attachment" "ssm_policy_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 4. EC2 instances are not able to directly interact with IAM Roles.
# They require a special container, an "Instance Profile". This creates that.
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.vpc_name}-ssm-profile"
  role = aws_iam_role.ssm_role.name

  tags = merge(
    { Name = "${var.vpc_name}-ssm-profile" },
    var.tags
  )
}