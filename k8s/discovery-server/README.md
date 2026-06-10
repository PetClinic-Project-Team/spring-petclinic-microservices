# Discovery Server (Eureka)

See the main README in `k8s/config-server/README.md` for full documentation,
smoke test results, and team instructions.

## Quick Summary

| Item | Detail |
|---|---|
| Port | 8761 |
| Type | Eureka Service Registry |
| Status | 1/1 Running on EKS ✅ |
| Service | ClusterIP 8761/TCP ✅ |
| Depends on | config-server (via initContainer) |
| Spring Profile | docker |
| Config URL | http://config-server:8888 |

## Access Eureka Dashboard
```bash
kubectl port-forward -n spring-petclinic svc/discovery-server 8761:8761
# Open: http://localhost:8761
```
