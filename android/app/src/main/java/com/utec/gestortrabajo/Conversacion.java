package com.utec.gestortrabajo;

import org.json.JSONException;
import org.json.JSONObject;

// Un trabajo con trabajador asignado en la lista de mensajes (GET api/conversaciones).
// ultimoMensaje y fechaUltimo son null si todavía nadie escribió.
public class Conversacion {

    public final int solicitudId;
    public final String titulo;
    public final String estado;
    public final String otraParteNombre;
    public final String ultimoMensaje;
    public final String fechaUltimo;
    public final int mensajesNuevos;

    public Conversacion(JSONObject json) throws JSONException {
        solicitudId = json.getInt("solicitudId");
        titulo = json.getString("titulo");
        estado = json.getString("estado");
        otraParteNombre = json.getString("otraParteNombre");
        ultimoMensaje = json.isNull("ultimoMensaje") ? null : json.getString("ultimoMensaje");
        fechaUltimo = json.isNull("fechaUltimo") ? null : json.getString("fechaUltimo");
        mensajesNuevos = json.getInt("mensajesNuevos");
    }
}
