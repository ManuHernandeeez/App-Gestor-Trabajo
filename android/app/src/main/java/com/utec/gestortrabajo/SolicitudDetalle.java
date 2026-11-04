package com.utec.gestortrabajo;

import org.json.JSONException;
import org.json.JSONObject;

import java.time.Duration;
import java.time.OffsetDateTime;

// Detalle de una solicitud (GET api/solicitudes/{id}). Sin dirección ni datos de contacto.
// miPropuestaEstado es null si quien mira no envió propuesta.
public class SolicitudDetalle {

    public final int id;
    public final String titulo;
    public final String descripcion;
    public final String oficio;
    public final String zona;
    public final double presupuesto;
    public final String estado;
    public final String fechaPublicacion;
    public final String clienteNombre;
    // Solo lo reciben el dueño y el trabajador asignado; null si todavía no hay trabajador
    public final String trabajadorNombre;
    // Cantidad de propuestas, solo para el dueño; 0 para el trabajador
    public final int propuestas;
    public final String miPropuestaEstado;
    public final double miPropuestaPrecio;

    public SolicitudDetalle(JSONObject json) throws JSONException {
        id = json.getInt("id");
        titulo = json.getString("titulo");
        descripcion = json.getString("descripcion");
        oficio = json.getString("oficio");
        zona = json.getString("zona");
        presupuesto = json.getDouble("presupuesto");
        estado = json.getString("estado");
        fechaPublicacion = json.getString("fechaPublicacion");
        clienteNombre = json.getString("clienteNombre");
        trabajadorNombre = json.isNull("trabajadorNombre") ? null : json.getString("trabajadorNombre");
        propuestas = json.isNull("propuestas") ? 0 : json.getInt("propuestas");
        if (json.isNull("miPropuesta")) {
            miPropuestaEstado = null;
            miPropuestaPrecio = 0;
        } else {
            JSONObject propuesta = json.getJSONObject("miPropuesta");
            miPropuestaEstado = propuesta.getString("estado");
            miPropuestaPrecio = propuesta.getDouble("precio");
        }
    }

    // La API manda la fecha en ISO 8601 con zona horaria, por ejemplo 2026-10-23T22:04:10+00:00
    public int horasPublicada() {
        OffsetDateTime publicada = OffsetDateTime.parse(fechaPublicacion);
        return (int) Duration.between(publicada, OffsetDateTime.now()).toHours();
    }
}
