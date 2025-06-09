#!/bin/bash
echo "=== Vérification Kubeflow ==="

# Vérifier les pods
echo "Pods non prêts:"
kubectl get pods -n kubeflow --field-selector=status.phase!=Running,status.phase!=Succeeded

# Vérifier les services essentiels
echo ""
echo "Services essentiels:"
kubectl get svc -n istio-system istio-ingressgateway
kubectl get svc -n kubeflow ml-pipeline-ui
kubectl get svc -n kubeflow centraldashboard

# Test d'accès
echo ""
echo "Test du port-forward..."
timeout 5 kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80 &
sleep 2
curl -s http://localhost:8080 > /dev/null && echo "✓ Accès OK" || echo "✗ Accès KO"
pkill -f "port-forward"

echo ""
echo "Pour accéder à Kubeflow:"
echo "  /opt/kubeflow-deploy/access-kubeflow.sh"