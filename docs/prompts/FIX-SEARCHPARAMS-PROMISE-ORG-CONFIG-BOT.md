# FIX SEARCHPARAMS PROMISE ORG CONFIG BOT

## Contexto

Fix quirurgico para await searchParams en App Router (/org/config/bot) por cambio en Next.js.

## Prompt ejecutado

````txt
Ese error es **100% Next.js App Router nuevo**: en esta versión, `searchParams` en RSC te llega como **Promise**, y tu `page.tsx` está accediendo a `searchParams.programId` **sin await**. Por eso al hacer click en “Ver” (que navega a `?programId=...`) la ruta renderiza y explota en servidor, y te deja “rebotando” en la misma.

## Fix (quirúrgico) — `app/org/config/bot/page.tsx`

Cambiá la firma del page para **await** searchParams.

### Opción recomendada (simple, async)

```ts
// app/org/config/bot/page.tsx

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function OrgBotConfigPage({ searchParams }: PageProps) {
  const sp = await searchParams;
  const programId = typeof sp.programId === "string" ? sp.programId : undefined;

  // ... el resto igual, usando programId
}
````

✅ Con eso se va el warning: _“searchParams is a Promise and must be unwrapped with await…”_
✅ Y deja de “rebotar” al hacer click.

---

## Por qué pasa “al darle Ver”

Porque tu UI seguramente hace `redirect(/org/config/bot?programId=...)`. En cuanto llega esa request, el render del Page intenta leer `searchParams.programId` sync y crashea.

---

## Quick check

Después del cambio:

```bash
npm run dev
```

- Entrá a `/org/config/bot?programId=6381856a-3e5c-43b4-afce-f83983418f29`
- Debería renderizar vigente/historial sin error.

---

## Nota

Si en tu `page.tsx` el prop estaba tipeado como `{ searchParams: { programId?: string } }`, eso ahora te engaña: compila, pero en runtime Next lo manda como Promise y te pega este error.

Si querés, pegame el bloque superior de tu `page.tsx` (las primeras ~60 líneas) y te digo exactamente dónde poner el `await` sin tocar nada más.

```

Resultado esperado

Evitar crash de RSC al leer searchParams sin await.

Notas (opcional)

Sin notas.
```
