# Using Cert-Manager to manage certificates

```yaml
# cert-manager-letsencrypt.yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: {EMAIL_ADDRESS} # Replace this with your email address
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          name: {APP_NAME}-gateway-ingress
```

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/issuer: letsencrypt
  name: {APP_NAME}-gateway-ingress
spec:
  tls:
  - secretName: {APP_NAME}-gateway-tls
    hosts:
    - example.com
  rules:
  - http:
      paths:
      - backend:
          service:
            name: {APP_NAME}-index
            port:
              name: headless
        path: /
        pathType: Prefix
      - backend:
          service:
            name: {APP_NAME}-ui
            port:
              name: headless
        path: /ui
        pathType: Prefix
      - backend:
          service:
            name: {APP_NAME}-uat
            port:
              name: headless
        path: /uat
        pathType: Prefix
      - backend:
          service:
            name: {APP_NAME}-api
            port:
              name: headless
        path: /api
        pathType: Prefix
```
