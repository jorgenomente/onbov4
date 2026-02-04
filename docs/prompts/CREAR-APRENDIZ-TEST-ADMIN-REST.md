# CREAR APRENDIZ TEST ADMIN REST

## Contexto

Crear un usuario aprendiz real en Supabase local vía Admin REST y generar su profile en ONBO para Local Centro.

## Prompt ejecutado

```txt
# Crear un nuevo usuario aprendiz (Auth REAL) en Supabase LOCAL vía Admin REST
# + crear su profile en ONBO (public.profiles) para Local Centro
#
# Requisitos:
# - Supabase local corriendo (npx supabase start)
# - Tener el SERVICE_ROLE_KEY local
#   -> lo ves con: npx supabase status  (buscá "service_role key")
# - Tener jq (para parsear JSON). Si no tenés jq, te dejo alternativa abajo.

set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:-http://localhost:54321}"
SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:-PASTE_SERVICE_ROLE_KEY_HERE}"

EMAIL="aprendiz-test@demo.com"
PASSWORD="prueba123"

# Local Centro (según tu mensaje)
LOCAL_ID="1af5842d-68c0-4c56-8025-73d416730016"

echo "==> (0) Limpieza por si ya existe un usuario roto con ese email (opcional pero recomendado)"
# OJO: esto borra SOLO el usuario con ese email en auth (si existe) + su profile.
# Puede fallar si no existe; lo ignoramos.
curl -sS -X GET \
  "$SUPABASE_URL/auth/v1/admin/users?email=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$EMAIL'''))")" \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
| jq -r '.users[0].id // empty' > /tmp/onbo_user_id_to_delete.txt || true

OLD_ID="$(cat /tmp/onbo_user_id_to_delete.txt || true)"
if [ -n "${OLD_ID:-}" ]; then
  echo "   - Encontrado usuario existente: $OLD_ID -> borrando (auth)"
  curl -sS -X DELETE \
    "$SUPABASE_URL/auth/v1/admin/users/$OLD_ID" \
    -H "apikey: $SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" >/dev/null
  echo "   - (Nota) El profile en public.profiles tiene FK ON DELETE CASCADE, debería limpiarse solo."
else
  echo "   - No existía usuario previo con $EMAIL (ok)"
fi

echo "==> (1) Crear usuario en Auth (admin endpoint)"
CREATE_RES="$(
  curl -sS -X POST "$SUPABASE_URL/auth/v1/admin/users" \
    -H "apikey: $SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"email\": \"$EMAIL\",
      \"password\": \"$PASSWORD\",
      \"email_confirm\": true
    }"
)"

USER_ID="$(echo "$CREATE_RES" | jq -r '.id')"
if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
  echo "ERROR: No pude crear el usuario en Auth."
  echo "$CREATE_RES" | jq .
  exit 1
fi
echo "   - Auth user_id: $USER_ID"

echo "==> (2) Crear profile ONBO (public.profiles) para Local Centro"
# Usamos el REST de PostgREST con service_role (local) para ejecutar INSERT via RPC no existe, entonces insert directo:
# Insertamos: user_id, org_id (derivado del local), local_id, role='aprendiz'
PROFILE_RES="$(
  curl -sS -X POST "$SUPABASE_URL/rest/v1/profiles" \
    -H "apikey: $SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "[
      {
        \"user_id\": \"$USER_ID\",
        \"org_id\": \"$(curl -sS \"$SUPABASE_URL/rest/v1/locals?id=eq.$LOCAL_ID&select=org_id\" \
          -H \"apikey: $SERVICE_ROLE_KEY\" -H \"Authorization: Bearer $SERVICE_ROLE_KEY\" | jq -r '.[0].org_id')\",
        \"local_id\": \"$LOCAL_ID\",
        \"role\": \"aprendiz\"
      }
    ]"
)"

# Validación mínima
echo "$PROFILE_RES" | jq -e '.[0].user_id' >/dev/null || {
  echo "ERROR: No pude crear el profile. Respuesta:"
  echo "$PROFILE_RES" | jq .
  exit 1
}

echo "✅ Listo. Podés iniciar sesión con:"
echo "   email:    $EMAIL"
echo "   password: $PASSWORD"
echo ""
echo "Ahora entrá a /training para arrancar training limpio."
```

Resultado esperado

Usuario Auth creado vía Admin REST y profile insertado para Local Centro.
