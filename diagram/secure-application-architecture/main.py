from diagrams import Diagram, Cluster, Edge
from diagrams.aws.security import WAF, IAM
from diagrams.aws.network import CloudFront, ALB, VPC
from diagrams.aws.compute import ECS
from diagrams.aws.database import RDS
from diagrams.onprem.database import MySQL
from diagrams.onprem.inmemory import Redis
from diagrams.aws.network import PrivateSubnet, PublicSubnet
from diagrams.onprem.client import Users

# Create the secure application architecture diagram
with Diagram(
    "Secure Production Application Architecture",
    show=False,
    direction="LR",
    graph_attr={"splines": "ortho", "nodesep": "1.0", "ranksep": "1.5"},
    outformat=["png"],
    filename="secure-application-architecture",
):

    # External users
    users = Users("Users")

    # Security and CDN Layer
    with Cluster("Security & CDN Layer"):
        waf = WAF("AWS WAF")
        cloudfront = CloudFront("CloudFront CDN")

    # VPC and networking
    with Cluster("AWS VPC"):
        # Public subnet
        with Cluster("Public Subnet"):
            alb = ALB("Application\nLoad Balancer")
            ecs_services = ECS("ECS Services\n(API Servers)")

        # Private subnet
        with Cluster("Private Subnet"):
            mysql_db = MySQL("MySQL Database\n(AWS Aurora)")
            redis_cache = Redis("Redis Cache\n(EC2 Instance)")

    # Request flow with security
    users >> Edge(label="HTTPS", color="blue") >> waf
    waf >> Edge(label="filtered requests", color="green") >> cloudfront
    (
        cloudfront
        >> Edge(
            label="X-Security-Example: Secret\nCustom Header",
            color="orange",
            style="bold",
        )
        >> alb
    )

    # Internal application flow
    alb >> Edge(label="load balanced", color="purple") >> ecs_services

    # Database connections
    ecs_services >> Edge(label="database queries", color="red") >> mysql_db
    ecs_services >> Edge(label="cache operations", color="cyan") >> redis_cache

    # Security annotation
    # Add a note about the security header
    with Cluster("Security Features", graph_attr={"style": "dashed", "color": "red"}):
        security_note = IAM("Custom Header Validation\nPrevents Direct ALB Access")


def main():
    print("Secure application architecture diagram generated!")


if __name__ == "__main__":
    main()
