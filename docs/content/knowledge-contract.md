# Contrato de Knowledge (ONBO)

## Proposito

Knowledge es la materia prima operativa que usa el bot para ensenar y responder. No es un LMS ni un manual largo.

Este contrato define que escribir para que el bot pueda:

- iniciar una unidad con una introduccion clara
- ensenar antes de evaluar
- practicar con criterios consistentes

## Formato recomendado (por unidad)

Cada unidad debe tener knowledge mapeado con estos tipos:

1. **Introduccion (obligatorio, 1 por unidad)**

- Texto breve que explica que se va a entrenar en la unidad.
- Debe orientar al aprendiz sobre el objetivo inmediato.

2. **Estandar / reglas (1-3 items)**

- Reglas operativas claras y accionables.
- Evitar ambiguedad o conceptos abstractos.

3. **Ejemplo (opcional, 1 item)**

- Ejemplo concreto de frase o comportamiento esperado.
- Debe ser corto y directo.

## Convencion de titulos (recomendado)

Usar prefijos en el titulo para que el bot identifique el tipo:

- `INTRO: ...`
- `ESTANDAR: ...`
- `EJEMPLO: ...`

> Si no se respeta la convencion, el bot usa el primer item disponible como intro y recordatorio.

## Limites de extension

- 5 a 15 lineas por item.
- Evitar textos largos tipo manual.
- Preferir bullets o frases cortas.

## Reglas duras

- Todo criterio evaluado debe estar ensenado en knowledge o en el recordatorio previo.
- No se evalua algo que no fue introducido antes.
- Knowledge desactivado (is_enabled=false) no se usa en el bot.

## Ejemplo minimo por unidad

**INTRO: Bienvenida**
"En esta unidad vas a aprender como iniciar el contacto con una mesa. El objetivo es generar confianza y guiar el primer paso del cliente."

**ESTANDAR: Regla de saludo**
"Saluda con una sonrisa, presentate con tu nombre y ofrece ayuda inmediata."

**EJEMPLO: Primer contacto**
"Hola, soy Sofia y voy a estar atendiendolos. Quieren agua o alguna bebida para comenzar?"
