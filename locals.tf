locals {
  user_data = <<EOF
#!/bin/bash

# Create users and add to group
useradd devops --group adm,wheel,systemd-journal
useradd go --group adm,wheel,systemd-journal

# Get SSH public key and update sshd config
# echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuPML/XnAPqGMWpYL986vE1K+GZFF069VRQlIZQW7CciIxVZfAROnOyzcCfIqSBks0hMRU97NBlqcldAm7ywh1PdxF7wrxCzGn9SslfT5Dj0/JmIxQacJmTxddBhJRhyFbCqtYd2v50Iw53ZvQIIWHGTLcMYHnnM1hKEmXsehqLyRTTnyBvTDteU1AwkndEIdDjNlaVsWHWzHVIhjSFAEH8KJhC2Rq/dVu5dl2oOt6naekYHB8PYBV5s+uSVpzI8anHLo9cMW1Zi7IWsX43LS8MR9+1ZtF61ihJIQ02fwB8Bm6g9C5AIu91v1WcidIPxszC+rfiSL59L0I+onvT1RvNkPKgWrAWsHszwEluEzpB2F91bKgNq0L8wVOKhqjZnSxi88EPt4WCBs4ZTMNRFUpvxXUMJQu98dHGJtiQjlJGsY06hSm3jsG4knKmGQ6SFj3UvrHqh5xeQrt8E3spRXcxs8x6rkzMrDhi55xRAXbYVD5FeTORtXslKODbZW4396lt1TSHx3OV0F+fvNOVI0LIVeQOF3HiAGkc+9dM10aXxDg9qP9dkzDZE3AG1+f813QxrNfzerxbXu8nAcE7vhW+DQ0hpa3TCsLbMSsT0DgpeiQPlU+Llpg2CyWkRhtoa0XD0G6jvIimq0v8oBrwgdonOCO9G62Fa7rxUDFVsO0DQ==" > /etc/ssh/devops-trusted-user-ca-keys.pem
echo "TrustedUserCAKeys /etc/ssh/devops-trusted-user-ca-keys.pem" >> /etc/ssh/sshd_config

# Configure sudoer
echo "devops ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "go ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

go_user_home=$(getent passwd go | cut -d: -f6)
mkdir $go_user_home/.ssh
# echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNPUBsBVSg2iKAAnA1y4wrUVbz/xxS3KyIYlQZ8fGMNwxr3V2iTulZVTk6oR/r19+VaiIoQpe9BkqYwWng770/BjGfsWWzETvXRESGBcr5/TswnBEjCPmhnMQBtN0Y2MdDZCgdFk5iO14zysINvy7l2NakJGeTzFJPcv1yGGrxW0nK+Ub5ikA5TjnjrvW2R9ddOkfE8Vi4Yxza6C4RAXvcHPiY5M+pp5WfZmFwvyy3HqBvddK1GbKGRvwRgVwc5S3BzRx1yJ563tYUB8Na/qlOHTnn3en9u2UAMUR1zaFXp1Chu4Ws4TmwGVodtEGCVTeFAoqGfEFAjhS4kznRBkWA40XuYx2d4BnPQ5V8tNt7Fn2lS9MyGmeBIYSkyCg25txBiWhww9CKEVb0Gj+RQ3rNk79mancKtOCiDXkNy7jW16+sQKggwHUpgkl65iSy8tmbLGMq08G1FqFs5q6SDzbpL2+TdXCvESVbhyDBM/ItDHMwCOkKhoIxjTKzbVmK9QcfNZGBok2QK9jYA9UvUoI+wpPtzFoTDsXj1sbbvoABng3XhH0oWUQhwwUoj0QxBv6GUl5s68c6a4+eEuWxrnToirVuYAa/+D2JyNC7fZDItDe4P76zfXHTQ7LiyoBDSzi8NjCxxc1G0KYvbqviWGS2rv0JwWmK3gPj03W96+Nsvw==" >> $go_user_home/.ssh/authorized_keys
chown -R go.go $go_user_home/.ssh/
chmod 600 $go_user_home/.ssh/authorized_keys
systemctl restart sshd
EOF

  worker_additional_security_group_ids = flatten([
    module.eks_secgr_ssh.this_security_group_id,
    //    module.secgr_thanos.this_security_group_id,
    var.worker_additional_security_group_ids
  ])

  workers_additional_policies = concat(
    [
      "arn:aws:iam::${var.account_id}:policy/ClusterAutoScaler"
    ],
    var.workers_additional_policies,
  )

  eks_tags = merge(
    {
      Terraform   = "true"
      Owner       = "DEVOPS"
      Environment = var.env_name
      KubernetesCluster = var.cluster_name
    },
    var.tags,
  )

  map_users = concat(
    [
      {
        userarn  = "arn:aws:iam::${var.account_id}:role/AtlantisAssumedRole"
        username = "atlantis"
        groups   = ["system:masters"]
      },
      {
        userarn  = "arn:aws:iam::${var.account_id}:role/AtlantisLocal"
        username = "atlantis"
        groups   = ["system:masters"]
      },
    ],
    var.map_users,
  )

  worker_group_templates = {
    for k, v in var.worker_groups_launch_template : k => merge(
      {
        key_name             = lookup(v, "key_name", "infra-${var.env_name}")
        asg_min_size         = lookup(v, "asg_min_size", "0")
        asg_desired_capacity = lookup(v, "asg_desired_capacity", "0")
        asg_max_size         = lookup(v, "asg_max_size", "0")
        autoscaling_enabled  = lookup(v, "autoscaling_enabled", true)
        asg_force_delete     = lookup(v, "asg_force_delete", true)
        enable_monitoring    = lookup(v, "enable_monitoring", true)
        suspended_processes  = [lookup(v, "suspended_processes", "AZRebalance")]
        additional_userdata  = lookup(v, "additional_userdata", local.user_data)
        enabled_metrics      = lookup(v, "enabled_metrics", split(",", "GroupMinSize,GroupMaxSize,GroupDesiredCapacity"))
        tags = [
          {
            key                 = "k8s.io/cluster-autoscaler/enabled"
            propagate_at_launch = "false"
            value               = "true"
          },
          {
            key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
            propagate_at_launch = "false"
            value               = "true"
          }
        ]
      },
      v,
    )
  }

  worker_groups_launch_template = [for k, v in local.worker_group_templates : v]
}
