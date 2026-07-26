# Playbook de Respuesta a Incidentes y Artefactos Forenses
**Incidente:** Exfiltración masiva de datos (45.7 GB) e instanciación de imagen maliciosa en ECS.
**Fecha/Hora de Detección:** T+02:00

## 1. Playbook de Contención (AWS CLI)

A continuación se detallan los comandos de respuesta rápida para contener la amenaza y aislar los recursos comprometidos, junto con sus respectivos comandos de rollback para restaurar la operatividad tras el peritaje técnico.

**Paso 1: Revocar credenciales de API**
*   **Contención:** `aws iam delete-access-key --user-name svc-monitoring --access-key-id <ACCESS_KEY_ID>`
*   **Rollback:** `aws iam create-access-key --user-name svc-monitoring`

**Paso 2: Desactivar acceso a la consola del usuario IAM comprometido**
*   **Contención:** `aws iam delete-login-profile --user-name svc-monitoring`
*   **Rollback:** `aws iam create-login-profile --user-name svc-monitoring --password <NEW_PASSWORD> --password-reset-required`

**Paso 3: Revocar sesiones activas (Invalidación de tokens temporales STS)**
*   **Contención:** `aws iam put-user-policy --user-name svc-monitoring --policy-name RevokeAllSessions --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*","Condition":{"DateLessThan":{"aws:TokenIssueTime":"2026-07-26T02:00:00Z"}}}]}'`
*   **Rollback:** `aws iam delete-user-policy --user-name svc-monitoring --policy-name RevokeAllSessions`

**Paso 4: Aislar instancia EC2 comprometida (Cuarentena sin apagar para análisis en RAM)**
*   **Contención:** `aws ec2 modify-instance-attribute --instance-id i-0abc1234def56789 --groups <ID_SG_CUARENTENA_VACIO>`
*   **Rollback:** `aws ec2 modify-instance-attribute --instance-id i-0abc1234def56789 --groups <ID_SG_ORIGINAL>`

**Paso 5: Preservar evidencia (Snapshot EBS a bucket Write-Once)**
*   **Contención:** `aws ec2 create-snapshot --volume-id <VOLUME_ID> --description "Evidencia Forense IR T+0200 AISLADA"`
*   **Rollback:** `aws ec2 delete-snapshot --snapshot-id <NEW_SNAPSHOT_ID>`

---

## 2. Mapeo MITRE ATT&CK v14

El ataque exhibió tácticas y técnicas claras que han sido mapeadas contra el framework MITRE ATT&CK:

1. **T1078.004 (Valid Accounts: Cloud Accounts):** Acceso inicial a la consola (T+00:00) usando credenciales legítimas pero comprometidas, originado desde la red Tor. *Mitigación: Imposición estricta de MFA para todos los logins de consola.*
2. **T1098.003 (Account Manipulation: Additional Cloud Roles):** Escalación de privilegios (T+00:22) asignando la política `AdministratorAccess` al usuario `svc-monitoring`. *Mitigación: Implementación de Permission Boundaries para limitar la capacidad de asignar políticas administrativas.*
3. **T1530 (Data from Cloud Storage Object):** Exfiltración de 45.7 GB de datos mediante 387 llamadas a `s3:GetObject` (T+00:35). *Mitigación: Restricción de acceso a S3 utilizando VPC Endpoints y validación de IP de origen.*
4. **T1204.003 (User Execution: Malicious Image):** Despliegue de la imagen maliciosa `docker.io/attacker/exfil:latest` (T+01:40) en el entorno de ECS. *Mitigación: Políticas de control de admisión que restrinjan el origen de las imágenes exclusivamente al registro privado (ECR).*
5. **T1562.008 (Impair Defenses: Disable Cloud Logs):** Intento fallido de borrar los registros de auditoría mediante `cloudtrail:DeleteTrail` (T+01:45). *Mitigación: Service Control Policies (SCP) activas; este control funcionó correctamente e impidió la evasión.*
6. **T1567.002 (Exfiltration Over Web Service):** Envío de 49 GB de datos hacia el atacante a través de conexión HTTPS saliente en el puerto 443 (T+01:10). *Mitigación: Egress Filtering estricto en los Security Groups, denegando tráfico de salida a IPs de baja reputación.*

---

## 3. Análisis de Causa Raíz (RCA)

*   **Vector Inicial (Hipótesis Justificada):** Filtración o robo de credenciales de larga duración (Access Keys/Password) de un perfil administrativo. El atacante utilizó estas credenciales para acceder a la consola desde un nodo de salida Tor (`185.220.101.22`).
*   **Attack Path Completo:** 
    1. Login exitoso desde red anónima.
    2. Modificación de un usuario de servicio (`svc-monitoring`) para otorgarle acceso de administrador (`AttachUserPolicy`).
    3. Abuso de los privilegios adquiridos para desencriptar 12 veces la clave KMS `prod-data-key`.
    4. Descarga masiva y rápida (8 minutos) de 45.7 GB de datos desde el bucket `fleetpay-prod-drivers`.
    5. Uso de una instancia EC2 como pivote para enviar 49 GB al exterior.
    6. Despliegue de un contenedor malicioso en ECS.
    7. Intento de borrado de huellas (DeleteTrail) bloqueado por defensas perimetrales (SCP).
*   **Por qué los controles existentes fallaron:**
    1. **Falta de MFA:** Permitió el uso de credenciales robadas sin un segundo factor de validación.
    2. **Privilegios Excesivos (Ausencia de Least Privilege):** El usuario inicial tenía permisos para adjuntar políticas de administrador (`iam:AttachUserPolicy`).
    3. **Falta de Egress Filtering:** La VPC permitió tráfico de salida irrestricto (0.0.0.0/0) en lugar de una lista blanca de destinos permitidos, facilitando la exfiltración.

---

## 4. Resumen Ejecutivo (CEO y Directorio)

**Asunto:** Incidente Crítico de Ciberseguridad - Exposición de Datos de Flota y Conductores.

**Qué ocurrió:**
A las 02:00 AM (UTC), detectamos y contuvimos una intrusión severa en nuestra infraestructura tecnológica. Un atacante externo vulneró un usuario con altos privilegios desde una red anónima, logrando desplegar software malicioso y evadir temporalmente algunos controles de seguridad, aunque los mecanismos de protección de auditoría lograron bloquear sus intentos de ocultar el ataque.

**Datos Expuestos e Impacto (Ley 1581 de 2012):**
Se confirma la extracción no autorizada de 45.7 GB de información perteneciente al almacenamiento de producción (`fleetpay-prod-drivers`). Esta información incluye datos sensibles de nuestros conductores (geolocalización de flotas e información personal de identificación). Al tratarse de una violación directa a la confidencialidad de datos personales, nos encontramos ante un incidente grave bajo la Ley 1581. Tenemos la obligación ineludible de notificar a la Superintendencia de Industria y Comercio (SIC) en un plazo máximo de **15 días hábiles**.

**Tres Acciones Inmediatas Tomadas:**
1. Revocación total de las credenciales vulneradas, expulsión del atacante y aislamiento hermético de los servidores afectados.
2. Captura de evidencia forense (copias exactas de los servidores) para respaldar la investigación técnica y legal en curso.
3. Activación del equipo legal para preparar el reporte obligatorio ante la SIC y elaborar el plan de comunicación transparente para nuestros conductores afectados.

---

## 5. Plan de Remediación Post-Incidente

| Prioridad | Acción de Remediación | Esfuerzo Estimado | Área Responsable |
| :--- | :--- | :--- | :--- |
| **P1** | Habilitar MFA obligatorio (Hard-Enforcement) para el 100% de usuarios IAM y limpiar/rotar todas las Access Keys antiguas. | Bajo (1 semana) | Ciberseguridad / Cloud Ops |
| **P2** | Implementar filtrado de salida (Egress Control) en VPCs y restringir orígenes de imágenes Docker al ECR interno. | Medio (1 mes) | Arquitectura Cloud |
| **P3** | Refactorizar políticas IAM eliminando comodines (`*`), implementando Permission Boundaries y automatizando escaneo de credenciales. | Alto (3 meses) | DevSecOps |