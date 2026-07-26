# Artefactos de Inteligencia de Amenazas (Threat Intelligence) e IOCs

## 1. Indicadores de Compromiso (IOCs) Documentados
* **IP Maliciosa (Origen):** `185.220.101.22` (Utilizada para el login inicial de consola y la posterior extracción de datos).
* **Usuarios IAM Involucrados:** `svc-monitoring` (Usuario escalado a AdministratorAccess) y el usuario inicial no identificado que realizó el login por consola.
* **Imágenes Docker Maliciosas:** `docker.io/attacker/exfil:latest` (Desplegada vía ECS).
* **Recursos AWS Comprometidos:** 
  * Bucket S3: `fleetpay-prod-drivers` (45.7 GB exfiltrados).
  * Clave KMS: `prod-data-key` (12 desencriptaciones).
  * Instancia EC2: `i-0abc1234def56789` (Usada para puente de exfiltración de 49 GB).
* **Patrones de Comportamiento:** Volumen anómalo de lectura (387 `GetObject` en 8 minutos), escalamiento de privilegios fuera de horario de oficina, e intentos de evasión defensiva (DeleteTrail).

## 2. Enriquecimiento de IP Maliciosa (185.220.101.22)
* **Geolocalización:** Alemania (Común en nodos de salida Tor europeos).
* **ASN:** AS 213151 (Bodis LLC / Calyx Institute - Operadores conocidos de infraestructura de anonimización).
* **Reputación (AbuseIPDB/Shodan):** Riesgo Alto (100/100). Etiquetada activamente como "Tor Exit Node" y "Data Center/Web Hosting Transit".
* **Presencia en Feeds (MISP/OTX):** Reportada en múltiples feeds de inteligencia abiertos como nodo de red de anonimización utilizado para escaneos y fuerza bruta.

## 3. Integración de Threat Intel Set con GuardDuty
El archivo `threat_intel.txt` adjunto en este directorio contiene las IPs maliciosas detectadas.

**Proceso de carga vía Terraform (Documentación):**
1. Subir el archivo `threat_intel.txt` a un bucket S3 de seguridad con acceso restringido.
2. Desplegar el recurso `aws_guardduty_threatintelset` apuntando a la URI del bucket S3 (`s3://bucket-seguridad/threat_intel.txt`).
3. Asegurar que el parámetro `activate` esté en `true` para que GuardDuty comience a alertar sobre tráfico relacionado con esta IP inmediatamente.