generate-secrets:
	kubectl get secret gramnuri-secrets -n gramnuri -o yaml > gramnuri/k8s/overlays/dev/secrets.yaml
	kubeseal < gramnuri/k8s/overlays/dev/secrets.yaml > gramnuri/k8s/overlays/dev/sealed-secrets.yaml \
	--controller-namespace kube-system \
	--controller-name sealed-secrets \
	--format yaml
