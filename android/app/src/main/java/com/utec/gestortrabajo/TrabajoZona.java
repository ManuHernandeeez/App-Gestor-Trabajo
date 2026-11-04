package com.utec.gestortrabajo;

import org.json.JSONException;
import org.json.JSONObject;

// Un trabajo de la zona del trabajador (GET api/trabajos/zona). Sin teléfono ni dirección.
public class TrabajoZona {

    public final int id;
    public final String titulo;
    public final String oficio;
    public final double presupuesto;
    public final String zona;
    public final String clienteNombre;
    public final int publicadaHaceHoras;
    public final boolean yaPropuse;

    public TrabajoZona(JSONObject json) throws JSONException {
        id = json.getInt("id");
        titulo = json.getString("titulo");
        oficio = json.getString("oficio");
        presupuesto = json.getDouble("presupuesto");
        zona = json.getString("zona");
        clienteNombre = json.getString("clienteNombre");
        publicadaHaceHoras = json.getInt("publicadaHaceHoras");
        yaPropuse = json.getBoolean("yaPropuse");
    }
}
