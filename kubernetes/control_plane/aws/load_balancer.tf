resource "aws_security_group" "kubernetes_control_plane_lb" {
  name = "kubernetes_lb"
  description = "Allows inbound access to this Kubernetes cluster"
  tags = "${merge(local.aws_tags, local.kubernetes_tags, var.kubernetes_control_plane_tags)}"
  ingress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port = 0
    to_port = 65535
    protocol = -1
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_lb_target_group" "kubernetes_control_plane" {
  name = "kubernetes_control_plane"
  port = 6443
  protocol = "tcp"
  vpc_id = "${aws_vpc.kubernetes_clusters.id}"
  target_type = "instance"
  tags = "${merge(local.aws_tags, local.kubernetes_tags, var.kubernetes_control_plane_tags)}"
  security_groups = [ "${aws_security_group.kubernetes_control_plane.id}" ]
  health_check {
    interval = 10
    path = "/healthz"
    port = 6443
    protocol = "HTTP"
    timeout = 10
    healthy_threshold = 3
    unhealthy_threshold = 5
    matcher = "200"
  }
}

resource "aws_lb_target_group_attachment" "kubernetes_control_plane" {
  count = "${var.number_of_masters_per_control_plane}"
  target_group_arn = "${aws_lb_target_group.kubernetes_control_plane.arn}"
  target_id = "${element(aws_spot_instance_request.kubernetes_control_plane.*.spot_instance_id, count.index)}"
}

resource "aws_lb" "kubernetes_control_plane_lb" {
  name = "kubernetes_lb"
  internal = false
  load_balancer_type = "application"
  subnets = "${aws_subnet.kubernetes_control_plane.*.id}"
}

resource "aws_lb_listener" "kubernetes_control_plane_lb" {
  load_balancer_arn = "${aws_lb.kubernetes_control_plane_lb.arn}"
  port = 6443
  protocol = "http"
  default_action {
    target_group_arn = "${aws_lb_target_group.kubernetes_control_plane.arn}"
    type = "forward"
  }
}
