#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/docs/db"
OUT_FILE="$OUT_DIR/dictionary.md"

mkdir -p "$OUT_DIR"

STATUS_JSON="$(npx supabase status --output json 2>/dev/null || true)"
if [[ -z "$STATUS_JSON" ]]; then
  echo "ERROR: Supabase local no está corriendo o 'supabase status' falló. Ejecutá 'npx supabase start'." >&2
  exit 1
fi

DB_URL="$(node -e '
const fs = require("fs");
const input = fs.readFileSync(0, "utf8");
if (!input) process.exit(1);
const match = input.match(/\{[\s\S]*\}/);
if (!match) process.exit(1);
let data;
try {
  data = JSON.parse(match[0]);
} catch (err) {
  process.exit(1);
}
let url = data.db_url || data.DB_URL || data.dbUrl || data.DBUrl;
if (!url) {
  for (const [key, value] of Object.entries(data)) {
    if (typeof value === "string" && /db.?url/i.test(key)) {
      url = value;
      break;
    }
  }
}
if (!url) process.exit(1);
process.stdout.write(url);
' <<<"$STATUS_JSON" 2>/dev/null || true)"

if [[ -z "$DB_URL" ]]; then
  echo "ERROR: No se pudo resolver DB_URL desde 'supabase status --output json'." >&2
  exit 1
fi

PSQL_OPTS=(-At -P pager=off -v ON_ERROR_STOP=1)

if ! echo "SELECT 1;" | psql "${PSQL_OPTS[@]}" "$DB_URL" >/dev/null 2>&1; then
  echo "ERROR: No hay conexión a Supabase local. Verificá que esté corriendo (npx supabase start)." >&2
  exit 1
fi

{
  echo "# Diccionario de datos (public)"
  echo
  echo "> Generado automáticamente. No editar a mano."
  echo
  echo "## Tablas y columnas"
  echo
  echo "| table_name | column_name | tipo | not_null | default |"
  echo "| --- | --- | --- | --- | --- |"
  psql "${PSQL_OPTS[@]}" -F $'\t' "$DB_URL" \
    -c "select table_name, column_name, data_type, is_nullable, coalesce(column_default, '') as column_default from information_schema.columns where table_schema = 'public' order by table_name, ordinal_position;" \
    | awk -F $'\t' '{ nn = ($4 == "NO" ? "true" : "false"); printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, nn, $5 }'

  echo
  echo "## RLS + Policies"
  echo

  TABLES="$(psql "${PSQL_OPTS[@]}" -F $'\t' "$DB_URL" -c "select c.relname, c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind in ('r','p') order by c.relname;")"

  if [[ -z "$TABLES" ]]; then
    echo "_No hay tablas en schema public._"
  else
    while IFS=$'\t' read -r table rls; do
      [[ -z "${table:-}" ]] && continue
      echo "### $table"
      echo
      if [[ "$rls" == "t" ]]; then
        echo "- RLS: enabled"
      else
        echo "- RLS: disabled"
      fi
      echo
      echo "| policy_name | command | using | with_check |"
      echo "| --- | --- | --- | --- |"

      POLICIES="$(psql "${PSQL_OPTS[@]}" -F $'\t' "$DB_URL" -c "select policyname, cmd, coalesce(qual, ''), coalesce(with_check, '') from pg_policies where schemaname = 'public' and tablename = '$table' order by policyname;")"

      if [[ -z "$POLICIES" ]]; then
        echo "| _none_ |  |  |  |"
      else
        while IFS=$'\t' read -r policy_name command using_expr with_check_expr; do
          using_expr="${using_expr//$'\n'/ }"
          using_expr="${using_expr//|/\\|}"
          with_check_expr="${with_check_expr//$'\n'/ }"
          with_check_expr="${with_check_expr//|/\\|}"
          echo "| $policy_name | $command | $using_expr | $with_check_expr |"
        done <<< "$POLICIES"
      fi

      echo
    done <<< "$TABLES"
  fi
} > "$OUT_FILE"

printf "OK: %s\n" "$OUT_FILE"
