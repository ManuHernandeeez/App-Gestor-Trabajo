package com.utec.gestortrabajo;

import org.json.JSONException;
import org.json.JSONObject;

// Un oficio, departamento, municipio o colonia en las listas del administrador (GET api/admin/...). Incluye los inactivos.
public class ElementoAdmin {

    public final int id;
    public final String nombre;
    public final boolean activo;

    public ElementoAdmin(JSONObject json) throws JSONException {
        id = json.getInt("id");
        nombre = json.getString("nombre");
        activo = json.getBoolean("activo");
    }
}
