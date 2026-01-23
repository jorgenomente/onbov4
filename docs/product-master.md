Perfecto. A continuación te entrego el **DOCUMENTO MAESTRO DEL PRODUCTO — ONBO**, **completo, corregido y mejorado**, incorporando:

- el rol del bot como **recomendador de aprobación**
- el estado **`en_revisión` visible para el aprendiz**
- reglas explícitas de transición, autoridad y auditoría
- eliminación de ambigüedades operativas
- numeración coherente

El documento está listo para ser usado como **fuente única de verdad**, contrato de producto y base técnica.

---

# ONBO — Documento Maestro del Producto

## Entrenamiento Conversacional para Camareros

**Dominio:** [https://onbo.space](https://onbo.space)
**Emails transaccionales:** Resend
**Idioma:** Español (LatAm)
**Estado:** Documento fundacional — Fuente única de verdad

---

## 0. Propósito de este documento

Este documento describe **ONBO de principio a fin**, sin ambigüedades ni supuestos implícitos.

Su objetivo es:

- Alinear producto, negocio y arquitectura
- Evitar interpretaciones subjetivas
- Servir como contrato entre producto, desarrollo y futuros colaboradores

Nada fuera de este documento debe asumirse como válido si no está explícitamente definido aquí.

---

## 1. Visión general del producto

ONBO es una **plataforma B2B de entrenamiento conversacional** para restaurantes, enfocada en capacitar camareros para:

- elevar el ticket promedio
- mejorar la experiencia del cliente
- alinear el servicio con el estándar de marca

ONBO **no es un LMS tradicional**:

- no hay cursos lineales clásicos
- no hay quizzes de opción múltiple
- no hay consumo pasivo de contenido

El **chatbot es el motor central del aprendizaje**.

---

## 2. Problema que resuelve

Las empresas gastronómicas enfrentan:

- alta rotación de personal
- dificultad para entrenar de forma consistente
- dependencia de referentes humanos
- falta de métricas reales de aprendizaje

ONBO reemplaza la capacitación informal por un **sistema entrenable, medible y auditable**.

---

## 3. Modelo organizacional (multi-tenancy)

Jerarquía estricta del sistema:

```
Organización
└── Local
    └── Usuario
```

Reglas:

- una organización puede tener múltiples locales
- un usuario pertenece a un solo local
- el conocimiento puede definirse:
  - a nivel Organización (compartido)
  - a nivel Local (específico)

- nunca se cruza información entre organizaciones

---

## 4. Roles del sistema

### 4.1 Superadmin (Plataforma)

Rol interno de ONBO.

Puede:

- acceder a todas las organizaciones
- gestionar configuraciones globales
- auditar datos
- brindar soporte

No representa un rol de cliente.

---

### 4.2 Admin Org (RRHH / Operaciones)

Rol estratégico.

Alcance:

- toda la organización
- todos los locales
- todos los usuarios

Puede:

- crear y gestionar usuarios
- asignar entrenamientos
- ver métricas agregadas
- comparar locales
- aprobar o desaprobar evaluaciones finales

---

### 4.3 Referente (Local)

Rol operativo.

Alcance:

- un único local

Puede:

- ver aprendices de su local
- ver progreso individual
- ver errores y brechas
- aprobar o pedir refuerzo tras evaluación final

No puede:

- ver otros locales
- crear entrenamientos
- acceder a métricas globales

---

### 4.4 Aprendiz (Camarero)

Usuario final.

Puede:

- entrenar
- practicar
- consultar información
- rendir evaluación final

No puede:

- ver otros usuarios
- ver métricas internas
- aprobar estados

---

## 5. Concepto de entrenamiento

El entrenamiento se compone de:

- un programa activo por local
- una secuencia estricta de unidades
- dos modos integrados:
  - Aprender
  - Practicar

No existe aprendizaje fuera de una secuencia.

---

## 6. Navegación del Aprendiz

Pestañas visibles:

- **Entrenamiento**
- **Progreso**
- **Perfil**

El aprendiz **no decide qué hacer**: el sistema siempre indica el siguiente paso.

---

## 7. Unidades de entrenamiento

El entrenamiento se organiza en **unidades secuenciales**.

Reglas:

- una sola unidad activa por aprendiz
- unidades futuras bloqueadas
- unidades pasadas accesibles solo en modo repaso

La unidad activa define:

- contexto del chatbot
- conceptos habilitados
- prácticas permitidas

---

## 8. Flujo conversacional (Aprender + Practicar)

Dentro de cada unidad, el chatbot alterna dinámicamente entre:

- explicación
- preguntas guiadas
- role-play

Para el usuario es un **flujo único y continuo**.

El sistema decide cuándo:

- explicar
- reforzar
- practicar
- avanzar

---

## 9. Consultas fuera del flujo

El aprendiz puede hacer preguntas puntuales.

Reglas:

- el bot responde solo con conocimiento cargado
- no se pierde el estado del entrenamiento
- luego invita a continuar

---

## 10. Repaso de unidades anteriores

### 10.1 Repaso contextual

Si la consulta corresponde a una unidad pasada:

- el bot responde
- aclara que es repaso
- no modifica progreso

---

### 10.2 Repaso desde Progreso

Desde Progreso, el aprendiz puede:

- revisar contenido completado

Modo repaso:

- solo lectura + mini prácticas
- sin impacto en métricas críticas

---

## 11. Práctica (Role-play)

Simulación de situaciones reales:

- venta sugestiva
- objeciones
- quejas
- upselling

Evaluación:

- respuestas abiertas
- criterios semánticos
- feedback inmediato

---

## 12. Preguntas sobre unidades futuras

Si la consulta corresponde a una unidad futura:

- respuesta general
- aclaración explícita
- no adelanta entrenamiento
- se registra para análisis

---

## 13. Estados del aprendiz

Estados posibles:

- `en_entrenamiento`
- `en_práctica`
- `en_riesgo`
- `en_revisión`
- `aprobado`

### 13.1 Reglas de transición

- `en_entrenamiento`: estado inicial
- `en_práctica`: prácticas activas
- `en_riesgo`: fallas reiteradas o señales de duda
- `en_revisión`: evaluación final presentada, pendiente de decisión humana
- `aprobado`: asignado solo por humano autorizado

Los estados:

- son únicos
- explícitos
- auditables
- nunca se infieren

---

## 14. Progreso

El progreso se mide como:

- porcentaje total
- avance por unidad
- dominio por temática

El progreso:

- se actualiza automáticamente
- no se recalcula retroactivamente

---

## 15. Evaluación doble capa

### 15.1 Evaluación automática (IA)

El bot evalúa:

- coherencia
- conceptos utilizados
- omisiones
- consistencia
- evolución

El bot produce:

- **recomendación**: aprobado / no aprobado
- **razones claras**:
  - fortalezas
  - brechas
  - competencias críticas no dominadas

El bot **no decide**.

---

### 15.2 Validación humana

Referente o Admin Org:

- aprueba
- desaprueba
- solicita refuerzo

Toda decisión queda registrada.

---

## 16. Registro y auditoría

Se guarda:

- toda conversación
- todas las respuestas
- evaluaciones automáticas
- recomendaciones del bot
- decisiones humanas
- cambios de estado

Nada se borra.

---

## 17. Métricas (MVP)

Se recopila:

- uso del bot
- calidad de respuestas
- escenarios fallados
- tiempos de respuesta
- evolución individual

### 17.1 Acceso a métricas

- Admin Org: métricas agregadas y comparativas
- Referente: métricas individuales de su local
- Aprendiz: solo su progreso

Formato MVP: datos estructurados simples.

---

## 18. Evaluación Final — Mesa Complicada

Instancia formal de validación.

Acceso:

- botón **“Iniciar evaluación final”**
- solo al completar todo el recorrido

---

### 18.1 Condición de habilitación

Requisitos:

- todas las unidades completadas
- todas las prácticas realizadas

---

### 18.2 Estructura configurable

Configurable por programa:

- cantidad total de preguntas
- proporción:
  - preguntas directas
  - role-play

- dificultad
- cobertura mínima por unidad

---

### 18.3 Lógica de diagnóstico

La evaluación produce:

- recomendación global del bot
- diagnóstico por unidad:
  - fuerte
  - medio
  - débil

Criterios:

- cobertura estratificada
- score global
- reglas “must-pass”
- preguntas adaptativas

---

### 18.4 Respuestas dudosas

Se destacan:

- “no sé”
- ambigüedad
- inconsistencias

Se priorizan para revisión humana.

---

### 18.5 Intentos y bloqueo

Reglas:

- 3 intentos
- 1 intento cada 12 h
- bloqueo tras 3 fallos

Humano puede otorgar intentos extra.

Nada se borra.

---

### 18.6 Abandono

Si se abandona:

- se evalúa hasta donde llegó
- lo no respondido es incorrecto
- el intento queda registrado

---

### 18.7 Resultado y revisión

Al finalizar:

- el bot muestra feedback pedagógico
- el aprendiz queda en estado **`en_revisión`**

El aprendiz ve en su pantalla:

> “Tu evaluación fue enviada. Está siendo revisada por tu referente.”

La aprobación final siempre es humana.

---

## 19. Chat de consulta (Admins / Referentes)

Chat asistido para:

- consultar estado
- ver brechas
- revisar evidencias

No ejecuta acciones críticas.

---

## 20. Emails y dominio

- Dominio: onbo.space
- Emails:
  - invitaciones
  - notificaciones
  - decisiones de evaluación

Proveedor: Resend.

---

## 21. Seguridad y principios técnicos

- PostgreSQL como fuente única de verdad
- RLS estricta
- Zero Trust
- Multi-tenancy desde `auth.uid()`
- historial inmutable
- nada sensible en frontend

---

## 22. Alcance del MVP

Incluye:

- entrenamiento conversacional
- evaluación final
- métricas base

No incluye:

- dashboards complejos
- múltiples verticales
- automatizaciones avanzadas

---

## 23. Evolución futura (no MVP)

- nuevos verticales
- asistentes administrativos
- benchmarking
- exportes

---

## 24. Regla final

Ante cualquier ambigüedad, ONBO prioriza:

**historial, control humano y aprendizaje real por sobre conveniencia de UX.**

---

**Estado del documento:** ACTIVO

---
