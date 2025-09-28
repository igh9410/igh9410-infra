from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.vcs import Github
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.registry import (
    Harbor,
)  # Using Harbor as GitHub Container Registry substitute
from diagrams.onprem.gitops import Argocd
from diagrams.saas.chat import Discord
from diagrams.onprem.container import Docker
from diagrams.generic.storage import Storage

# Create the GitOps pipeline diagram
with Diagram(
    "GitHub Actions GitOps Pipeline",
    show=False,
    graph_attr={"splines": "ortho", "nodesep": "1.0", "ranksep": "1.5"},
    outformat=["png"],
    filename="github-actions-gitops-pipeline",
):

    # Triggers section
    with Cluster("Triggers"):
        main_push = Github("Push to main\nbranch")

    # Application Repository Workflow
    with Cluster("Application Repository Workflow"):
        app_workflow = GithubActions("Build & Deploy\nWorkflow")

        with Cluster("Build Steps"):
            docker_build = Docker("Build Docker\nImage")
            ghcr_push = Harbor("Push to GHCR")

    # Infrastructure Repository Update
    with Cluster("Infrastructure Repository"):
        infra_repo = Github("Infrastructure\nRepository")

        with Cluster("Reusable Workflow"):
            kustomize_workflow = GithubActions("Update Kustomization\nWorkflow")
            update_files = Storage("Update newTag in\nkustomization.yaml")

    # GitOps Deployment
    with Cluster("GitOps Deployment"):
        argocd = Argocd("ArgoCD")

        with Cluster("Kubernetes Cluster"):
            k8s_deployment = Docker("Application\nDeployment")

    # Notification section
    with Cluster("Notifications"):
        discord_success = Discord("Deployment\nSuccess")
        discord_failure = Discord("Deployment\nFailure")

    # Main workflow connections
    # Triggers to application workflow
    main_push >> Edge(label="deploy", color="blue") >> app_workflow

    # Application workflow steps
    app_workflow >> docker_build >> ghcr_push

    # Trigger reusable workflow for infra updates
    (
        ghcr_push
        >> Edge(label="trigger reusable\nworkflow", style="dashed", color="purple")
        >> kustomize_workflow
    )

    # Infrastructure repository workflow steps
    kustomize_workflow >> update_files >> infra_repo

    # ArgoCD watches infrastructure repository
    (
        infra_repo
        >> Edge(label="watches for\nchanges", color="orange", style="bold")
        >> argocd
    )

    # ArgoCD deploys to Kubernetes
    argocd >> Edge(label="deploy", color="green") >> k8s_deployment

    # Success path
    k8s_deployment >> Edge(label="deployment success", color="green") >> discord_success

    # Failure paths (can fail at multiple points)
    (
        docker_build
        >> Edge(label="build failure", color="red", style="dotted")
        >> discord_failure
    )
    (
        ghcr_push
        >> Edge(label="push failure", color="red", style="dotted")
        >> discord_failure
    )
    (
        kustomize_workflow
        >> Edge(label="update failure", color="red", style="dotted")
        >> discord_failure
    )
    argocd >> Edge(label="sync failure", color="red", style="dotted") >> discord_failure


def main():
    print("GitHub Actions GitOps pipeline diagram generated!")


if __name__ == "__main__":
    main()
