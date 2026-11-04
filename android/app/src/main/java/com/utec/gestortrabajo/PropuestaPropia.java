package com.utec.gestortrabajo;

import org.json.JSONException;
import org.json.JSONObject;

// Una propuesta en la lista del trabajador que la envió (GET api/propuestas/mias).
// presupuesto es el de la solicitud y precio el que ofreció el trabajador.
public class PropuestaPropia {

    public final int id;
    public final int solicitudId;
    public final String titulo;
    public final String oficio;
    public final String zona;
    public final String clienteNombre;
    public final double presupuesto;
    public final double precio;
    public final String estado;
    public final String estadoSolicitud;

    public PropuestaPropia(JSONObject json) throws JSONException {
        id = json.getInt("id");
        solicitudId = json.getInt("solicitudId");
        titulo = json.getString("titulo");
        oficio = json.getString("oficio");
        zona = json.getString("zona");
        clienteNombre = json.getString("clienteNombre");
        presupuesto = json.getDouble("presupuesto");
        precio = json.getDouble("precio");
        estado = json.getString("estado");
        estadoSolicitud = json.getString("estadoSolicitud");
    }
}
