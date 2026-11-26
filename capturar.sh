#!/bin/zsh
# Saca capturas de cada pantalla en el simulador ya instalado (no crea ni borra simuladores).
# Uso: ./capturar.sh [pantalla ...]   (sin argumentos, todas las de pantallas.txt, la cuenta nueva y el alta)
# «nombre.claro» la saca en modo claro. Antes de usarlo, tomá el candado del simulador (ver README).
set -e
SIM=${SIM:-762618FE-D6AB-4A56-BC66-248224D158DC}
APP=${APP:-build/dd/Build/Products/Debug-iphonesimulator/Cuarzo.app}
ID=ar.com.cuarzo.app
cd "$(dirname "$0")"
mkdir -p capturas
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null
xcrun simctl install "$SIM" "$APP"
xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState discharging --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi >/dev/null
sacar() { # archivo pantalla [argumentos…]
  local f=$1; shift
  xcrun simctl terminate "$SIM" $ID 2>/dev/null || true
  xcrun simctl launch "$SIM" $ID -pantalla "$@" >/dev/null
  sleep ${ESPERA:-3}
  xcrun simctl io "$SIM" screenshot "capturas/$f.png" >/dev/null 2>&1
  echo "capturas/$f.png"
}
if (( $# )); then lista=($@); else lista=(${(f)"$(grep -v '^#' pantallas.txt)"}); fi
for p in $lista; do
  n=${p%.claro}; osc=YES; [[ $p == *.claro ]] && osc=NO
  sacar $p $n -oscuro $osc
done
if (( ! $# )); then
  sacar inicio-nueva inicio -cuentaNueva YES -oscuro YES
  sacar inicio-sin-conexion inicio -sinConexion YES -oscuro YES
  for i in 1 2; do sacar onboarding-$i onboarding -paso $i -oscuro YES; done
  for i in 0 1 2 3 4 5; do sacar alta-$i alta -paso $i -oscuro YES; done
fi
