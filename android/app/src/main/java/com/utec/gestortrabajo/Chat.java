package com.utec.gestortrabajo;

import android.app.Activity;
import android.content.Intent;

// Un solo lugar para abrir la conversación de un trabajo y saber cuándo admite mensajes.
// El chat es un hilo por cada trabajador que envió propuesta a la solicitud; el servidor es quien decide
// al final (aquí solo se evita mostrar botones que no llevan a nada).
public class Chat {

    // otraParteId es el trabajador con quien habla el cliente; 0 si no se sabe (el trabajador no lo necesita,
    // y el cliente tampoco cuando el trabajo ya tiene trabajador asignado)
    public static void abrir(Activity pantalla, int solicitudId, int otraParteId, String nombre, String titulo,
                             boolean puedeEscribir) {
        Intent intent = new Intent(pantalla, ConversacionActivity.class);
        intent.putExtra("solicitudId", solicitudId);
        intent.putExtra("otraParteId", otraParteId);
        intent.putExtra("nombre", nombre);
        intent.putExtra("titulo", titulo);
        intent.putExtra("puedeEscribir", puedeEscribir);
        pantalla.startActivity(intent);
    }

    // El hilo admite mensajes mientras la propuesta está pendiente y la solicitud publicada, o mientras
    // la propuesta aceptada tiene el trabajo asignado, en proceso o finalizado (igual que en la base)
    public static boolean abierto(String estadoPropuesta, String estadoSolicitud) {
        if (estadoPropuesta.equals("pendiente")) {
            return estadoSolicitud.equals("publicada");
        }
        if (estadoPropuesta.equals("aceptada")) {
            return estadoSolicitud.equals("asignada") || estadoSolicitud.equals("en_proceso")
                    || estadoSolicitud.equals("finalizada");
        }
        return false;
    }
}
