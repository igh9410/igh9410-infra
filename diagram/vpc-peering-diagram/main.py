from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import (
    VPC,
    VPCPeering,
    ALB,
    NATGateway,
    PrivateSubnet,
    PublicSubnet,
    Endpoint,
)
from diagrams.aws.compute import EC2
from diagrams.aws.management import Cloudwatch
from diagrams.onprem.monitoring import Prometheus, Grafana

# Create the VPC peering hub-and-spoke architecture
with Diagram(
    "VPC Peering Hub-and-Spoke Architecture",
    show=False,
    graph_attr={"splines": "ortho", "nodesep": "1.5", "ranksep": "2.0"},
    outformat=["png"],
    filename="vpc-peering-architecture",
):

    # Create invisible nodes for layout positioning
    # Top row: Production VPC
    with Cluster("Production VPC\n10.3.0.0/16"):
        prod_vpc = VPC("Production VPC")
        prod_app = EC2("Production Applications")
        prod_cloudwatch = Cloudwatch("CloudWatch")

    # Middle row: Dev/QA (left), Monitoring (center), Staging (right)
    with Cluster("Dev/QA VPC\n10.1.0.0/16"):
        dev_vpc = VPC("Dev/QA VPC")
        dev_app = EC2("Dev Applications")
        dev_cloudwatch = Cloudwatch("CloudWatch")

    # Central Monitoring VPC (Hub)
    with Cluster("Monitoring VPC (Hub)\n10.0.0.0/16"):
        monitoring_vpc = VPC("Monitoring VPC")

        with Cluster("Public Subnet\n10.0.1.0/24"):
            alb = ALB("Application Load Balancer")
            nat_gw = NATGateway("NAT Gateway")

        with Cluster("Private Subnet\n10.0.2.0/24"):
            monitoring_ec2 = EC2("Monitoring Server")
            with Cluster("Services on EC2"):
                prometheus = Prometheus("Prometheus")
                grafana = Grafana("Grafana")

            with Cluster("VPC Endpoints"):
                log_endpoint = Endpoint("CloudWatch Logs VPC Endpoint")
                ec2_ssm_endpoint = Endpoint("EC2 SSM VPC Endpoint")
                ec2_ssm_messages_endpoint = Endpoint("EC2 SSM Messages VPC Endpoint")

    with Cluster("Staging VPC\n10.2.0.0/16"):
        staging_vpc = VPC("Staging VPC")
        staging_app = EC2("Staging Applications")
        staging_cloudwatch = Cloudwatch("CloudWatch")

    # VPC Peering connections (hub-and-spoke pattern)
    # All connections go to the monitoring VPC in the center
    prod_vpc - Edge(label="VPC Peering", style="dashed") - monitoring_vpc
    dev_vpc - Edge(label="VPC Peering", style="dashed") - monitoring_vpc
    staging_vpc - Edge(label="VPC Peering", style="dashed") - monitoring_vpc

    # ALB routes to monitoring EC2
    alb >> Edge(label="HTTPS", color="green") >> monitoring_ec2

    # Services running on monitoring EC2
    monitoring_ec2 >> Edge(style="dotted") >> prometheus
    monitoring_ec2 >> Edge(style="dotted") >> grafana

    # CloudWatch data flows to VPC endpoints (through VPC peering)
    (
        dev_cloudwatch
        >> Edge(label="CloudWatch metrics/logs", color="blue")
        >> log_endpoint
    )
    (
        staging_cloudwatch
        >> Edge(label="CloudWatch metrics/logs", color="orange")
        >> log_endpoint
    )
    (
        prod_cloudwatch
        >> Edge(label="CloudWatch metrics/logs", color="red")
        >> log_endpoint
    )

    # Prometheus monitoring data flows (through VPC peering)
    (
        dev_app
        >> Edge(label="metrics/logs", color="lightblue", style="dotted")
        >> prometheus
    )
    (
        staging_app
        >> Edge(label="metrics/logs", color="lightyellow", style="dotted")
        >> prometheus
    )
    prod_app >> Edge(label="metrics/logs", color="pink", style="dotted") >> prometheus

    # Apps send metrics to their respective CloudWatch
    dev_app >> Edge(style="dotted", color="blue") >> dev_cloudwatch
    staging_app >> Edge(style="dotted", color="orange") >> staging_cloudwatch
    prod_app >> Edge(style="dotted", color="red") >> prod_cloudwatch
