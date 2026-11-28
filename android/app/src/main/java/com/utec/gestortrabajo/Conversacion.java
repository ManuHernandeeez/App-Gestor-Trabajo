package com.utec.gestortrabajo;

import org.json.JSONException;
import org.json.JSONObject;

// Un hilo de chat en la lista de mensajes (GET api/conversaciones): la otra persona y el trabajo del que hablan.
// ultimoMensaje y fechaUltimo son null si todavía nadie escribió. puedeEscribir es false si el hilo es de solo lectura.
public class Conversacion {

    public final int solicitudId;
    public final String titulo;
    public final String estado;
    public final int otraParteId;
    public final String otraParteNombre;
    public final String ultimoMensaje;
    public final String fechaUltimo;
    public final int mensajesNuevos;
    public final boolean puedeEscribir;

    public Conversacion(JSONObject json) throws JSONException {
        solicitudId = json.getInt("solicitudId");
        titulo = json.getString("titulo");
        estado = json.getString("estado");
        otraParteId = json.getInt("otraParteId");
        otraParteNombre = json.getString("otraParteNombre");
        ultimoMensaje = json.isNull("ultimoMensaje") ? null : json.getString("ultimoMensaje");
        fechaUltimo = json.isNull("fechaUltimo") ? null : json.getString("fechaUltimo");
        mensajesNuevos = json.getInt("mensajesNuevos");
        puedeEscribir = json.getBoolean("puedeEscribir");
    }
}
