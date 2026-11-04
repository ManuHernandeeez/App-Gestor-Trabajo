package com.utec.gestortrabajo;

import org.json.JSONException;
import org.json.JSONObject;

// Una solicitud de la lista del cliente (GET api/solicitudes/mias).
public class SolicitudResumen {

    public final int id;
    public final String titulo;
    public final String oficio;
    public final String zona;
    public final double presupuesto;
    public final String estado;
    public final int propuestas;

    public SolicitudResumen(JSONObject json) throws JSONException {
        id = json.getInt("id");
        titulo = json.getString("titulo");
        oficio = json.getString("oficio");
        zona = json.getString("zona");
        presupuesto = json.getDouble("presupuesto");
        estado = json.getString("estado");
        propuestas = json.getInt("propuestas");
    }
}
