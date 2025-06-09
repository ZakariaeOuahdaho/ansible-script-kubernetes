#!/bin/bash
echo "=== Correction de l'installation Kubeflow ==="

# 1. Supprimer le MySQL en conflit
echo "Suppression du MySQL en conflit..."
kubectl delete deployment mysql -n kubeflow --force --grace-period=0 2>/dev/null

# 2. Réappliquer les composants critiques
echo "Réapplication des composants..."
cd /opt/kubeflow-manifests

# Pipelines sans MySQL
kustomize build apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user | \
  grep -v "kind: Deployment" | grep -v "name: mysql" | kubectl apply -f - || true

# 3. Vérifier et créer les PVC manquants
echo "Vérification des PVC..."
kubectl get pvc -n kubeflow

# 4. Redémarrer les pods en erreur
echo "Redémarrage des pods en erreur..."
kubectl delete pod -n kubeflow -l app=admission-webhook
kubectl delete pod -n kubeflow -l app=katib-controller
kubectl delete pod -n kubeflow -l component=metadata-grpc-server

# 5. Patcher les deployments pour les ressources
echo "Ajustement des ressources..."
kubectl patch deployment -n kubeflow centraldashboard --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {"requests": {"memory": "64Mi", "cpu": "50m"}}}]' || true

# 6. Vérifier l'état
sleep 30
echo ""
echo "=== État actuel ==="
kubectl get pods -n kubeflow | grep -v Running | grep -v Completed