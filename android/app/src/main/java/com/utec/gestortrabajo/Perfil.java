package com.utec.gestortrabajo;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;

// Perfil propio (GET api/perfil). El DUI viene enmascarado y fotoUrl es relativa a Config.URL_BASE.
// Los textos que no vienen quedan en null y los ids de zona en 0.
public class Perfil {

    public final String rol;
    public final String nombre;
    public final String telefono;
    public final String duiEnmascarado;
    public final String fotoUrl;
    public final double promedioCalificacion;
    public final int totalCalificaciones;
    public final int departamentoId;
    public final int municipioId;
    // Del cliente, la colonia donde vive; del trabajador, las colonias donde trabaja
    public final ArrayList<Integer> colonias;
    public final ArrayList<Integer> oficios;

    public Perfil(JSONObject json) throws JSONException {
        rol = json.getString("rol");
        nombre = json.getString("nombre");
        telefono = textoONulo(json, "telefono");
        duiEnmascarado = textoONulo(json, "duiEnmascarado");
        fotoUrl = textoONulo(json, "fotoUrl");
        promedioCalificacion = json.getDouble("promedioCalificacion");
        totalCalificaciones = json.getInt("totalCalificaciones");
        departamentoId = idDe(json, "departamento");
        municipioId = idDe(json, "municipio");
        oficios = idsDe(json.getJSONArray("oficios"));
        // el cliente trae "colonia" y la lista vacía; el trabajador trae la lista y "colonia" en null
        colonias = idsDe(json.getJSONArray("coloniasTrabajo"));
        if (!json.isNull("colonia")) {
            colonias.add(idDe(json, "colonia"));
        }
    }

    private static String textoONulo(JSONObject json, String campo) throws JSONException {
        return json.isNull(campo) ? null : json.getString(campo);
    }

    // Id de un elemento de catálogo { id, nombre }, o 0 si viene null
    private static int idDe(JSONObject json, String campo) throws JSONException {
        return json.isNull(campo) ? 0 : json.getJSONObject(campo).getInt("id");
    }

    private static ArrayList<Integer> idsDe(JSONArray arreglo) throws JSONException {
        ArrayList<Integer> ids = new ArrayList<Integer>();
        for (int i = 0; i < arreglo.length(); i++) {
            ids.add(arreglo.getJSONObject(i).getInt("id"));
        }
        return ids;
    }
}
