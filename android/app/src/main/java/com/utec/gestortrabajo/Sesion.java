package com.utec.gestortrabajo;

import android.content.Context;
import android.content.SharedPreferences;

// Datos de la sesión en SharedPreferences. No se guarda contraseña ni datos de contacto.
public class Sesion {

    private static final String ARCHIVO = "sesion";

    private final SharedPreferences preferencias;

    public Sesion(Context contexto) {
        preferencias = contexto.getSharedPreferences(ARCHIVO, Context.MODE_PRIVATE);
    }

    public void guardar(String token, String rol, int usuarioId, String nombre) {
        SharedPreferences.Editor editor = preferencias.edit();
        editor.putString("token", token);
        editor.putString("rol", rol);
        editor.putInt("usuarioId", usuarioId);
        editor.putString("nombre", nombre);
        editor.apply();
    }

    public boolean estaAbierta() {
        return obtenerToken() != null;
    }

    public String obtenerToken() {
        return preferencias.getString("token", null);
    }

    public String obtenerRol() {
        return preferencias.getString("rol", "");
    }

    public String obtenerNombre() {
        return preferencias.getString("nombre", "");
    }

    public int obtenerUsuarioId() {
        return preferencias.getInt("usuarioId", 0);
    }

    // Al editar el perfil, para que las pantallas muestren el nombre nuevo
    public void guardarNombre(String nombre) {
        preferencias.edit().putString("nombre", nombre).apply();
    }

    // Fecha del servidor (ISO 8601) de la última vez que se pidieron mensajes y avisos; null si nunca
    public String obtenerUltimaCarga() {
        return preferencias.getString("ultimaCarga", null);
    }

    public void guardarUltimaCarga(String fecha) {
        preferencias.edit().putString("ultimaCarga", fecha).apply();
    }

    public void cerrar() {
        preferencias.edit().clear().apply();
    }
}
