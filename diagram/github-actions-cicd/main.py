from diagrams import Diagram, Cluster, Edge
from diagrams.programming.language import Python
from diagrams.onprem.vcs import Github
from diagrams.onprem.ci import GithubActions
from diagrams.aws.compute import ECS, ECR
from diagrams.onprem.iac import Terraform
from diagrams.saas.chat import Slack
from diagrams.generic.blank import Blank
from diagrams.onprem.container import Docker

# Create the CI/CD pipeline diagram
with Diagram(
    "GitHub Actions CI/CD Pipeline",
    show=False,
    graph_attr={"splines": "ortho", "nodesep": "1.0", "ranksep": "1.5"},
    outformat=["png"],
    filename="github-actions-cicd-pipeline",
):

    # Triggers section
    with Cluster("Triggers"):
        dev_qa_push = Github("Push to dev/qa\nbranch")
        release_trigger = Github("GitHub Release\n(main branch)")
        slack_trigger = Slack("Slack Command\n(staging)")

    # Application Repository Workflow
    with Cluster("Application Repository Workflow"):
        app_workflow = GithubActions("Build & Deploy\nWorkflow")

        with Cluster("Build Steps"):
            docker_build = Docker("Build Docker\nImage")
            ecr_push = ECR("Push to ECR")

    # Infrastructure Repository Workflow
    with Cluster("Infrastructure Repository Workflow"):
        infra_workflow = GithubActions("Infrastructure\nWorkflow")

        with Cluster("Terraform Operations"):
            terraform = Terraform("Terraform\nPlan & Apply")

        with Cluster("ECS Updates"):
            ecs_tasks = ECS("Update 15+\nECS Tasks")

    # Notification section
    with Cluster("Notifications"):
        slack_success = Slack("Deployment\nSuccess")
        slack_failure = Slack("Deployment\nFailure")

    # Main workflow connections
    # Triggers to application workflow
    dev_qa_push >> Edge(label="dev/qa", color="blue") >> app_workflow
    release_trigger >> Edge(label="production", color="red") >> app_workflow
    slack_trigger >> Edge(label="staging", color="orange") >> app_workflow

    # Application workflow steps
    app_workflow >> docker_build >> ecr_push

    # Call infrastructure workflow
    ecr_push >> Edge(label="trigger", style="dashed") >> infra_workflow

    # Infrastructure workflow steps
    infra_workflow >> terraform >> ecs_tasks

    # Success path
    ecs_tasks >> Edge(label="success", color="green") >> slack_success

    # Failure paths (can fail at multiple points)
    docker_build >> Edge(label="failure", color="red", style="dotted") >> slack_failure
    ecr_push >> Edge(label="failure", color="red", style="dotted") >> slack_failure
    terraform >> Edge(label="failure", color="red", style="dotted") >> slack_failure
    ecs_tasks >> Edge(label="failure", color="red", style="dotted") >> slack_failure


def main():
    print("GitHub Actions CI/CD pipeline diagram generated!")


if __name__ == "__main__":
    main()
