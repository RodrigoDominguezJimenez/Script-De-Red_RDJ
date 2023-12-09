#!/bin/bash

function ayuda {
cat << EOF
=====================================================================================================================
MODO DE EJECUCIÓN PARA OBTENER EL MANUAL DE AYUDA: ./ScriptDeRed.sh -h
DESCRIPCIÓN DEL SCRIPT:
Este es un script interactivo, el cual te dará la facilidad de conectarte por medio de una interfaz de red que tu
elijas de tu equipo a una red, de forma dinámica o de forma estática, de forma dinámica quiere decir que el servidor
DHCP de la red te asignará tu propia dirección IP y de forma estática quiere decir que  tu puedes cambiar o agregar
una nueva dirección a una interfaz de red de tu elección, podrás elegir si quieres conectarte de forma inalámbrica a
una red que tiene y que no tiene contraseña.
El script te irá guiando en el camino pidiendote que ingreses la información desde el teclado, por lo cual debes tener
mucho cuidado al escribir correctamente los valores que se te piden, el script valida varios parametros que ingreses,
pero parametros como la contraseña de una red inalámbrica ya no se da el script para validarla, simplemente no se hará
la conexión.
=====================================================================================================================
EOF
}

opcionH=""
while getopts ":h" opt; do
    case $opt in
	h)
	    opcionH="1";
	    ;;
	"?")
	    echo "Opción inválida -$OPTARG";
	    ayuda;
	    exit 1;
	    ;;
	:)
	    echo "Se esperaba un parámetro en -$OPTARG";
	    ayuda;
	    exit 1;
	    ;;
    esac
done

shift $((OPTIND-1)) #borrar todos los params que ya procesó getopts

# FUNCIÓN DE AYUDA EN CASO DE LLAMARLA
if test "$opcionH"; then
        ayuda;
        exit 0;
fi
# FUNCION PARA ESCANEAR REDES Y SU TIPO DE CIFRADO
function escanearRed {
interface="$1"
iwlist $interface scan | grep -E 'Cell|ESSID|IE: IEEE 802.11i|IE: WPA|IE: WPA2' | awk '
BEGIN {
    FS=":"
    OFS="\t"
}

/Cell/ {
    if (ssid) {
        print "SSID:", ssid, "Encryption:", encryption
    }
    ssid = ""
    encryption = "Open"
}

/ESSID:/ {
    ssid = $2
}

/IE: IEEE 802.11i/ {
    encryption = "WPA2"
}

/IE: WPA/ {
    encryption = "WPA"
}

END {
    if (ssid) {
        print "SSID:", ssid, "Encryption:", encryption
    }
}'
}

# FUNCIÓN DE CONFIGURACIÓN ESTÁTICA DE RED PERMANENTE
function estaticaPermanente {
	local direccionIP="$1"
	local prefijoRed="$2"
	local interfaz="$3"
	echo "" >> /etc/network/interfaces
	echo "auto $interfaz" >> /etc/network/interfaces
	echo "iface $interfaz inet static" >> /etc/network/interfaces
	echo "address $direccionIP" >> /etc/network/interfaces
	echo "netmask $prefijoRed" >> /etc/network/interfaces
}

# FUNCIÓN DE LA CONFIGURACIÓN CABLEADA
function cableada {
local FormaConexion="$2"
local Interfaz="$1"
ip link set "$Interfaz" up
if [[ "$FormaConexion" == "Estática" || "$FormaConexion" == "estática" || "$FormaConexion" == "ESTÁTICA" ]]; then
	echo "Si deseas agregar otra dirección en la interfaz escribe SI, en el caso de liberar direcciones IP de la interfaz y asignar una nueva escribe NO"; read siono
	if test "$siono" == "SI"; then
		echo "Dame la dirección IP asignar estáticamente a $Interfaz con su respectiva máscara, por ejemplo: 192.168.100.5/24";read dirEstatica;
		ip addr add "$dirEstatica" dev "$Interfaz"
		echo "Intentando asignar nueva dirección IP..."
		sleep 3
		ip address
		echo "¿Te gustaria que la configuración fuera permanente? S para si, N para no";read sPn;
		if test "$sPn" == "S"; then
			dirIP=$(echo "$dirEstatica" | grep -Po "^[^/]+")
			prefijo=${dirEstatica##*/}
			estaticaPermanente "$dirIP" "$prefijo" "$Interfaz"
			echo "LISTO"
		fi
	elif test "$siono" == "NO"; then
		ip addr flush dev "$Interfaz"
		echo "Dame la dirección IP asignar estáticamente a $Interfaz con su respectiva máscara, por ejemplo: 192.168.100.5/24";read dirEstatica;
                ip addr add "$dirEstatica" dev "$Interfaz"
                echo "Intentando asignar nueva dirección IP..."
                sleep 3
                ip address
                echo "¿Te gustaria que la configuración fuera permanente? S para si, N para no";read sPn;
                if test "$sPn" == "S"; then
                        dirIP=$(echo "$dirEstatica" | grep -Po "^[^/]+")
                        prefijo=${dirEstatica##*/}
                        estaticaPermanente "$dirIP" "$prefijo" "$Interfaz"
                        echo "LISTO"
                fi
	else
		echo "Parametro no valido"; exit 1;
	fi
elif [[ "$FormaConexion" == "Dinámica" || "$FormaConexion" == "dinámica" || "$FormaConexion" == "DINÁMICA" ]]; then
	echo "Estableciendo conexión dinamicamente en $Interfaz ..."
	dhclient "$Interfaz"
	sleep 3
	ip address
fi
}

# FUNCIÓN DE LA CONFIGURACIÓN INALÁMBRICA
function inalambrica {
local FormaConexion="$2"
local Interfaz="$1"
ip link set "$Interfaz" up
#iw dev "$Interfaz" scan | grep SSID
escanearRed "$Interfaz"
echo "¿Cuál es el nombre de la red que deseas conectarte?";read red;
if [[ "$FormaConexion" == "Dinámica" || "$FormaConexion" == "dinámica" || "$FormaConexion" == "DINÁMICA" ]]; then
	echo "¿La red requiere contraseña? Indique SI o NO"; read noosi;
	if test "$noosi" == "NO"; then
        	echo "Estableciendo conexión dinamicamente en $Interfaz ..."
	 	iw dev "$Interfaz" connect "$red"
		dhclient "$Interfaz"
		sleep 3
        	ip address
	elif test "$noosi" == "SI"; then
		echo "Escriba la contraseña de la red"; read passwd;
		echo "Estableciendo conexión dinamicamente en $Interfaz ..."
		wpa_passphrase "$red" "$passwd" > wpa_config.conf
		wpa_supplicant -i "$Interfaz" -c wpa_config.conf -B
		dhclient "$Interfaz"
		sleep 3
		ip address
	fi
elif [[ "$FormaConexion" == "Estática" || "$FormaConexion" == "estática" || "$FormaConexion" == "ESTÁTICA" ]]; then
	echo "Dame la dirección IP asignar estáticamente a $Interfaz con su respectiva máscara, por ejemplo: 192.168.100.5/24";read direcIP;
        echo "Estableciendo conexión estaticamente en $Interfaz y con dirección IP $direcIP ..."
        echo "¿La red requiere contraseña? Indique SI o NO"; read yesorno;
       if test "$yesorno" == "NO"; then
                echo "Estableciendo conexión dinamicamente en $Interfaz ..."
	        iw dev "$Interfaz" connect "$red"
        	dhclient "$Interfaz"
		ip addr add "$direcIP" dev "$Interfaz"
	        sleep 3
        	ip address
                echo "¿Te gustaria que la configuración fuera permanente? S para si, N para no";read sPn;
                if test "$sPn" == "S"; then
                        dirIP=$(echo "$direcIP" | grep -Po "^[^/]+")
                        prefijo=${direcIP##*/}
                        estaticaPermanente "$dirIP" "$prefijo" "$Interfaz"
                        echo "LISTO"
                fi
        elif test "$yesorno" == "SI"; then
                echo "Escriba la contraseña de la red"; read passwd;
                echo "Estableciendo conexión dinamicamente en $Interfaz ..."
                wpa_passphrase "$red" "$passwd" > wpa_config.conf
                wpa_supplicant -i "$Interfaz" -c wpa_config.conf -B
		ip addr add "$direcIP" dev "$Interfaz"
                sleep 3
                ip address
                if test "$sPn" == "S"; then
                        dirIP=$(echo "$direcIP" | grep -Po "^[^/]+")
                        prefijo=${direcIP##*/}
                        estaticaPermanente "$dirIP" "$prefijo" "$Interfaz"
                        echo "LISTO"
                fi
        fi
fi
}

# MENU DEL USUARIO
echo "============================================================================================================"
echo "Actualizando el sistema e instalando los paquetes necesarios (iw, iproute2, isc-dhcp-client, wpasupplicant)"
echo "============================================================================================================"
apt update
apt install iw iproute2 isc-dhcp-client wpasupplicant -y
sleep 2
clear
wait
systemctl stop NetworkManager
ip link show
echo "============================================================================================="
echo "¿La configuración de la red será Cableada o Inalámbrica?"; read cOi;
echo "Ingrese el nombre de la interfaz que desea configurar y también si será de forma Estática o Dinámica"
echo "Interfaz: ";read Interfaz;
echo "Forma de conectarse a la red: ";read FormaConexion;
echo "============================================================================================="

# VERIFICACIÓN DE EXISTENCIA DE LA INTERFAZ INGRESADA POR EL USUARIO
interfaces=$(ip link show | grep -Po "^[0-9]: \K([a-z0-9A-Z]+)")
ToF="F"
for lainterfaz in ${interfaces[@]}; do
        if test "$lainterfaz" == "$Interfaz"; then
                ToF="T";
	fi
done

# VALIDACIÓN DE LOS DEMÁS PARAMÉTROS INGRESADOS POR EL USUARIO
test "$ToF" == "T" || { echo "Interfaz $Interfaz no valida";exit 1; }
if [[ "$cOi" == "Cableada" || "$cOi" == "cableada" || "$cOi" == "CABLEADA" ]]; then
	if [[ "$FormaConexion" == "Estática" || "$FormaConexion" == "estática" || "$FormaConexion" == "ESTÁTICA" ]]; then
		cableada "$Interfaz" "$FormaConexion";
	elif [[ "$FormaConexion" == "Dinámica" || "$FormaConexion" == "dinámica" || "$FormaConexion" == "DINÁMICA" ]]; then
		cableada "$Interfaz" "$FormaConexion"
	else
		echo 'Parametro "'$FormaConexion'" escrito incorrectamente o no valido'; exit 1;
	fi
elif [[ "$cOi" == "Inalámbrica" || "$cOi" == "inalámbrica" || "$cOi" == "INALÁMBRICA" ]]; then
	if [[ "$FormaConexion" == "Estática" || "$FormaConexion" == "estática" || "$FormaConexion" == "ESTÁTICA" ]]; then
		inalambrica "$Interfaz" "$FormaConexion"
        elif [[ "$FormaConexion" == "Dinámica" || "$FormaConexion" == "dinámica" || "$FormaConexion" == "DINÁMICA" ]]; then
                inalambrica "$Interfaz" "$FormaConexion"
        else
                echo 'Parametro "'$FormaConexion'" escrito incorrectamente o no valido'; exit 1;
	fi
else
        echo 'Parametro "'$cOi'" escrito incorrectamente o no valido'; exit 1;
fi
