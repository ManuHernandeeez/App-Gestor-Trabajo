package com.utec.gestortrabajo;

import org.json.JSONException;
import org.json.JSONObject;

// Un usuario en la búsqueda del administrador (GET api/admin/usuarios). Sin correo, teléfono ni DUI.
public class UsuarioAdmin {

    public final int id;
    public final String rol;
    public final String nombre;
    public final String estado;

    public UsuarioAdmin(JSONObject json) throws JSONException {
        id = json.getInt("id");
        rol = json.getString("rol");
        nombre = json.getString("nombre");
        estado = json.getString("estado");
    }

    public boolean estaSuspendido() {
        return estado.equals("suspendido");
    }

    public boolean esAdministrador() {
        return rol.equals("administrador");
    }
}
