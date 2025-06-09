#!/bin/bash
echo "=== Réduction des ressources Kubeflow ==="

# Réduire les ressources pour tous les deployments
kubectl get deployment -n kubeflow -o name | while read deploy; do
  echo "Patching $deploy..."
  kubectl patch $deploy -n kubeflow --type='json' -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources",
      "value": {
        "requests": {
          "memory": "100Mi",
          "cpu": "50m"
        },
        "limits": {
          "memory": "500Mi",
          "cpu": "500m"
        }
      }
    }
  ]' 2>/dev/null || true
done

# Redémarrer les pods en pending
kubectl delete pods -n kubeflow --field-selector=status.phase=Pending

echo "Attente du redémarrage..."
sleep 30

# Vérifier l'état
kubectl get pods -n kubeflow | grep -v Running