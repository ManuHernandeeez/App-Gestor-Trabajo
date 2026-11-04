package com.utec.gestortrabajo;

public class Config {

    // Dirección de la API. Se cambia según dónde corra la app:
    //   teléfono por cable con adb reverse:     http://localhost:5000/   (el que se usa ahora)
    //   emulador de Android:                    http://10.0.2.2:5000/    (10.0.2.2 es la PC)
    //   teléfono por Wi-Fi:                     http://IP-DE-LA-PC:5000/ (y esa IP en network_security_config.xml)
    public static final String URL_BASE = "http://localhost:5000/";

    // Solo para pruebas: muestra en el login los botones que entran con las cuentas de ejemplo.
    // Se pone en false (o se borra esa parte del login) cuando el login definitivo esté listo.
    public static final boolean ACCESO_DE_PRUEBA = true;
    public static final String CLAVE_DE_PRUEBA = "Clave12345";
}
