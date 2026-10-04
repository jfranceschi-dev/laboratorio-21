#!/usr/bin/env bash
# Construye ambos servicios y los carga en minikube.
set -e
for S in servicio-a servicio-b; do
  echo "== $S:local =="
  docker build -t "$S:local" "./$S"
  minikube image load "$S:local"
done
echo "Listo. Ahora: kubectl apply -f k8s/"
