package com.utec.gestortrabajo;

import org.json.JSONException;
import org.json.JSONObject;

// Una propuesta vista por el cliente dueño de la solicitud (GET api/solicitudes/{id}/propuestas).
public class Propuesta {

    public final int id;
    public final int trabajadorId;
    public final String trabajadorNombre;
    public final double promedioCalificacion;
    public final int totalCalificaciones;
    public final double precio;
    public final String mensaje;
    public final String estado;

    public Propuesta(JSONObject json) throws JSONException {
        id = json.getInt("id");
        trabajadorId = json.getInt("trabajadorId");
        trabajadorNombre = json.getString("trabajadorNombre");
        promedioCalificacion = json.getDouble("promedioCalificacion");
        totalCalificaciones = json.getInt("totalCalificaciones");
        precio = json.getDouble("precio");
        // optString devolvería el texto "null" cuando el valor es null
        mensaje = json.isNull("mensaje") ? "" : json.getString("mensaje");
        estado = json.getString("estado");
    }
}
