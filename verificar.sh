#!/usr/bin/env bash
# Verificador del Lab S42 (del contenedor al cluster, integrativo). Córrelo desde 'app/'.
# Requiere: minikube arriba. Escribe tus Dockerfiles (servicio-a/, servicio-b/) y manifiestos (k8s/).
#  ->  bash verificar.sh
set -u
PASS=0; TOTAL=8
echo "== S42: del contenedor al cluster (8 compuertas) =="
command -v docker  >/dev/null 2>&1 || { echo "[X] docker no instalado"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "[X] kubectl no instalado"; exit 1; }

echo "-- (1) ambos Dockerfiles son multi-stage..."
ok1=1
for S in servicio-a servicio-b; do
  D="$S/Dockerfile"
  [ -f "$D" ] && [ "$(grep -ciE '^\s*FROM ' "$D")" -ge 2 ] && grep -qiE 'COPY\s+--from' "$D" || ok1=0
done
[ "$ok1" = 1 ] && { echo "[OK] (1) los dos son multi-stage"; PASS=$((PASS+1)); } || echo "[X] (1) cada Dockerfile debe ser multi-stage (>=2 FROM + COPY --from)"

echo "-- (2) ambos corren no-root..."
ok2=1; for S in servicio-a servicio-b; do grep -qiE '^\s*USER ' "$S/Dockerfile" 2>/dev/null || ok2=0; done
[ "$ok2" = 1 ] && { echo "[OK] (2) los dos usan USER no-root"; PASS=$((PASS+1)); } || echo "[X] (2) agrega un USER no-root a cada Dockerfile"

echo "-- (3) construir e importar las imagenes a minikube..."
if bash construir_y_cargar.sh >/tmp/c21.log 2>&1; then echo "[OK] (3) imagenes construidas y cargadas"; PASS=$((PASS+1)); else echo "[X] (3) fallo build/carga:"; tail -4 /tmp/c21.log; fi

echo "-- (4) manifiestos validos + aplicados + listos..."
if kubectl apply --dry-run=client -f k8s/ >/dev/null 2>&1; then
  kubectl apply -f k8s/ >/dev/null 2>&1
  kubectl rollout status deployment/servicio-b --timeout=120s >/dev/null 2>&1
  kubectl rollout status deployment/servicio-a --timeout=120s >/dev/null 2>&1; sleep 3
  RA=$(kubectl get deploy servicio-a -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  RB=$(kubectl get deploy servicio-b -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "${RA:-0}" -ge 1 ] && [ "${RB:-0}" -ge 1 ] 2>/dev/null && { echo "[OK] (4) ambos Deployments listos"; PASS=$((PASS+1)); } || echo "[X] (4) no todos listos (a=${RA:-0}, b=${RB:-0})"
else echo "[X] (4) manifiestos invalidos"; fi

echo "-- (5) ambos Services tienen endpoints (selectores calzan)..."
EA=$(kubectl get endpoints servicio-a -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
EB=$(kubectl get endpoints servicio-b -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
[ -n "$EA" ] && [ -n "$EB" ] && { echo "[OK] (5) ambos Services enrutan a pods"; PASS=$((PASS+1)); } || echo "[X] (5) algun Service sin endpoints: selector != labels"

echo "-- (6) A alcanza a B por DNS del cluster..."
kubectl port-forward service/servicio-a 18080:8080 >/dev/null 2>&1 & PF=$!; sleep 4
if curl -sf http://localhost:18080/consulta 2>/dev/null | grep -qi "dato-desde-B"; then echo "[OK] (6) A llamo a B por su nombre de Service"; PASS=$((PASS+1)); else echo "[X] (6) /consulta no trajo el dato de B (revisa SERVICIO_B_URL)"; fi
kill $PF >/dev/null 2>&1

echo "-- (7) A llama a B por NOMBRE, no localhost/IP..."
URLV=$(grep -riE 'SERVICIO_B_URL' k8s/ | sed 's/#.*//')
{ echo "$URLV" | grep -qiE 'servicio-b' && ! echo "$URLV" | grep -qiE 'localhost|127\.0\.0\.1|([0-9]+\.){3}[0-9]+'; } && { echo "[OK] (7) por nombre 'servicio-b'"; PASS=$((PASS+1)); } || echo "[X] (7) usa el nombre del Service 'servicio-b'"

echo "-- (8) auto-sanacion..."
POD=$(kubectl get pods -l app=servicio-a --no-headers 2>/dev/null | head -1 | awk '{print $1}')
if [ -n "$POD" ]; then
  kubectl delete pod "$POD" >/dev/null 2>&1; kubectl rollout status deployment/servicio-a --timeout=120s >/dev/null 2>&1; sleep 2
  R=$(kubectl get deploy servicio-a -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "${R:-0}" -ge 1 ] 2>/dev/null && { echo "[OK] (8) K8s repuso el pod"; PASS=$((PASS+1)); } || echo "[X] (8) no se recupero"
else echo "[X] (8) no encontre pod de servicio-a"; fi

echo ""; echo "PUNTAJE: ${PASS}/${TOTAL}"
[ "$PASS" -eq "$TOTAL" ] && echo "Del codigo al cluster, completo: imagenes buenas, desplegadas, hablando por DNS, auto-sanadas." || echo "Aun no. Revisa arriba."
