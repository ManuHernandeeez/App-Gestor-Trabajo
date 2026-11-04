package com.utec.gestortrabajo;

import org.json.JSONException;
import org.json.JSONObject;

// Un mensaje de una conversación (GET api/solicitudes/{id}/mensajes). esMio indica si lo escribió quien usa la app.
public class Mensaje {

    public final int id;
    public final String texto;
    public final String fecha;
    public final boolean esMio;

    public Mensaje(JSONObject json) throws JSONException {
        id = json.getInt("id");
        texto = json.getString("texto");
        fecha = json.getString("fecha");
        esMio = json.getBoolean("esMio");
    }
}
