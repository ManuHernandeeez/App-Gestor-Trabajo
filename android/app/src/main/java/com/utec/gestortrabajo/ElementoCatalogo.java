package com.utec.gestortrabajo;

import org.json.JSONArray;
import org.json.JSONException;

import java.util.ArrayList;

// Un elemento de los catálogos: departamento, municipio, colonia u oficio.
public class ElementoCatalogo {

    public final int id;
    public final String nombre;

    public ElementoCatalogo(int id, String nombre) {
        this.id = id;
        this.nombre = nombre;
    }

    // Los ArrayAdapter de las listas muestran este texto
    @Override
    public String toString() {
        return nombre;
    }

    // Convierte la respuesta de un GET api/catalogos/... en una lista
    public static ArrayList<ElementoCatalogo> desdeJson(String cuerpo) throws JSONException {
        JSONArray arreglo = new JSONArray(cuerpo);
        ArrayList<ElementoCatalogo> elementos = new ArrayList<ElementoCatalogo>();
        for (int i = 0; i < arreglo.length(); i++) {
            elementos.add(new ElementoCatalogo(
                    arreglo.getJSONObject(i).getInt("id"), arreglo.getJSONObject(i).getString("nombre")));
        }
        return elementos;
    }

    // Posición del elemento con ese id, o -1 si no está
    public static int posicionDe(ArrayList<ElementoCatalogo> elementos, int id) {
        for (int i = 0; i < elementos.size(); i++) {
            if (elementos.get(i).id == id) {
                return i;
            }
        }
        return -1;
    }
}
