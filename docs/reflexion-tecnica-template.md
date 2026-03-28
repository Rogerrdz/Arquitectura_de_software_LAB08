# Reflexion tecnica (maximo 1 pagina)

## 1) Decisiones de arquitectura
- Se utilizo Azure Load Balancer (L4) con N VMs Linux para alta disponibilidad.
- Se modularizo Terraform en red, balanceador y computo para mantenibilidad.
- Se uso backend remoto en Azure Storage para colaboracion y bloqueo de estado.

## 2) Seguridad aplicada
- Acceso por SSH solo con llave publica.
- Regla SSH limitada a una IP publica en CIDR /32.
- NSG con reglas minimas para puerto 80 y probe del balanceador.
- Tags obligatorias: owner, course, env, expires.

## 3) Trade-offs
- LB L4 es mas simple y economico que Application Gateway para un caso de HTTP basico.
- No se agrega WAF ni routing L7 para mantener alcance del laboratorio.
- Disponibilidad se mejora con 2+ VMs y Availability Set, pero sin autoscaling.

## 4) Costos aproximados
- 2 x VM Standard_B1s
- 1 x Public IP Standard
- 1 x Standard Load Balancer
- 1 x Storage Account (state)
- Revisar estimado real en Azure Pricing Calculator segun region.

## 5) Destruccion segura
- Ejecutar terraform destroy con el var-file correcto.
- Confirmar eliminacion de RG y recursos asociados.
- Verificar que no queden costos residuales (IP publica, discos, storage).
