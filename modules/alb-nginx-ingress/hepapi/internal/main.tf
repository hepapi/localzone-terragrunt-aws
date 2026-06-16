resource "kubectl_manifest" "alb_nginx_internal_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      annotations:
        alb.ingress.kubernetes.io/certificate-arn: ${var.alb_acm_certs}
        alb.ingress.kubernetes.io/healthcheck-path: /healthz
        alb.ingress.kubernetes.io/healthcheck-protocol: HTTPS
        alb.ingress.kubernetes.io/group.name: "${var.alb_name}"
        alb.ingress.kubernetes.io/group.order: '10'
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
        alb.ingress.kubernetes.io/load-balancer-name: "${var.alb_name}"
        alb.ingress.kubernetes.io/scheme: "internal"
        alb.ingress.kubernetes.io/ssl-redirect: "443"
        alb.ingress.kubernetes.io/target-type: "ip"
      name: alb-nginx-internal-ingress
      namespace: nginx-internal
    spec:
      ingressClassName: alb
      rules:
      - host: "*.hepapi.com"
        http: &http
          paths:
          - backend:
              service:
                name: nginx-internal-nginx-ingress-controller
                port:
                  number: 80
            path: /
            pathType: Prefix
  YAML
}