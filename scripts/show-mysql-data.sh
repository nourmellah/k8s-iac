#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="database"
SECRET_NAME="mysql-secret"

echo "== Finding MySQL pod =="
MYSQL_POD="$(vagrant ssh cp1 -c "sudo kubectl -n ${NAMESPACE} get pods -l app=mysql -o jsonpath='{.items[0].metadata.name}'" 2>/dev/null | tr -d '\r')"

if [ -z "$MYSQL_POD" ]; then
  echo "[ERROR] Could not find MySQL pod in namespace ${NAMESPACE}"
  exit 1
fi

echo "[OK] MySQL pod: ${MYSQL_POD}"
echo

echo "== Reading MySQL credentials from Kubernetes Secret =="
MYSQL_DB="$(vagrant ssh cp1 -c "sudo kubectl -n ${NAMESPACE} get secret ${SECRET_NAME} -o jsonpath='{.data.MYSQL_DATABASE}' | base64 -d" 2>/dev/null | tr -d '\r')"
MYSQL_USER="$(vagrant ssh cp1 -c "sudo kubectl -n ${NAMESPACE} get secret ${SECRET_NAME} -o jsonpath='{.data.MYSQL_USER}' | base64 -d" 2>/dev/null | tr -d '\r')"
MYSQL_PASSWORD="$(vagrant ssh cp1 -c "sudo kubectl -n ${NAMESPACE} get secret ${SECRET_NAME} -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 -d" 2>/dev/null | tr -d '\r')"

echo "[OK] Database: ${MYSQL_DB}"
echo "[OK] User: ${MYSQL_USER}"
echo

echo "== Databases =="
vagrant ssh cp1 -c "sudo kubectl -n ${NAMESPACE} exec ${MYSQL_POD} -- env MYSQL_PWD='${MYSQL_PASSWORD}' mysql -u'${MYSQL_USER}' -t -e 'SHOW DATABASES;'"
echo

echo "== Tables in ${MYSQL_DB} =="
vagrant ssh cp1 -c "sudo kubectl -n ${NAMESPACE} exec ${MYSQL_POD} -- env MYSQL_PWD='${MYSQL_PASSWORD}' mysql -u'${MYSQL_USER}' '${MYSQL_DB}' -t -e 'SHOW TABLES;'"
echo

echo "== Data from all tables in ${MYSQL_DB} =="

TABLES="$(vagrant ssh cp1 -c "sudo kubectl -n ${NAMESPACE} exec ${MYSQL_POD} -- env MYSQL_PWD='${MYSQL_PASSWORD}' mysql -u'${MYSQL_USER}' '${MYSQL_DB}' -N -e 'SHOW TABLES;'" 2>/dev/null | tr -d '\r')"

if [ -z "$TABLES" ]; then
  echo "[INFO] No tables found."
  exit 0
fi

while read -r TABLE; do
  [ -z "$TABLE" ] && continue
  echo
  echo "---- Table: ${TABLE} ----"
  vagrant ssh cp1 -c "sudo kubectl -n ${NAMESPACE} exec ${MYSQL_POD} -- env MYSQL_PWD='${MYSQL_PASSWORD}' mysql -u'${MYSQL_USER}' '${MYSQL_DB}' -t -e 'SELECT * FROM \`${TABLE}\`;'"
done <<< "$TABLES"
