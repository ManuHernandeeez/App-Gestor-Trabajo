package com.utec.gestortrabajo;

import android.content.Intent;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.util.ArrayList;

// Al abrir la app con sesión pide a la API los mensajes y avisos nuevos desde la última carga,
// avisa cuántos hay y guarda la hora del servidor para la próxima vez. No hay sondeo ni notificaciones.
public class Sincronizacion {

    // Cuántos avisos se listan en el cuadro; el resto se cuenta
    private static final int AVISOS_VISIBLES = 5;
    private static final String TIPO_MENSAJE = "mensaje_nuevo";

    // LoginActivity pasa el extra "sincronizar" a la pantalla principal. Se usa una sola vez por apertura.
    public static void alAbrirApp(final AppCompatActivity pantalla) {
        Intent intent = pantalla.getIntent();
        if (!intent.getBooleanExtra("sincronizar", false)) {
            return;
        }
        intent.removeExtra("sincronizar");

        String ruta = "api/sincronizacion";
        String desde = new Sesion(pantalla).obtenerUltimaCarga();
        if (desde != null) {
            ruta = ruta + "?desde=" + codificar(desde);
        }
        ClienteApi.pedir(pantalla, "GET", ruta, null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                recibir(pantalla, cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                // sin respuesta no se avisa nada y la próxima apertura pide desde la misma fecha
            }
        });
    }

    private static void recibir(AppCompatActivity pantalla, String cuerpo) {
        try {
            JSONObject json = new JSONObject(cuerpo);
            new Sesion(pantalla).guardarUltimaCarga(json.getString("ahora"));

            int mensajes = json.getJSONArray("mensajes").length();
            // cada mensaje nuevo trae también su aviso: aquí solo se listan los demás
            ArrayList<String> textos = new ArrayList<String>();
            ArrayList<Integer> ids = new ArrayList<Integer>();
            JSONArray avisos = json.getJSONArray("avisos");
            for (int i = 0; i < avisos.length(); i++) {
                JSONObject aviso = avisos.getJSONObject(i);
                if (!aviso.getString("tipo").equals(TIPO_MENSAJE)) {
                    textos.add(aviso.getString("texto"));
                    ids.add(aviso.getInt("id"));
                }
            }
            if (mensajes == 0 && textos.isEmpty()) {
                return;
            }
            mostrar(pantalla, mensajes, textos);
            marcarLeidos(pantalla, ids);
        } catch (JSONException e) {
            Toast.makeText(pantalla, R.string.error_inesperado, Toast.LENGTH_LONG).show();
        }
    }

    private static void mostrar(AppCompatActivity pantalla, int mensajes, ArrayList<String> avisos) {
        StringBuilder texto = new StringBuilder();
        if (mensajes == 1) {
            texto.append(pantalla.getString(R.string.sync_mensaje_uno));
        } else if (mensajes > 1) {
            texto.append(pantalla.getString(R.string.sync_mensajes_varios, mensajes));
        }
        if (!avisos.isEmpty()) {
            if (texto.length() > 0) {
                texto.append("\n\n");
            }
            texto.append(pantalla.getString(avisos.size() == 1 ? R.string.sync_aviso_uno : R.string.sync_avisos_varios, avisos.size()));
            for (int i = 0; i < avisos.size() && i < AVISOS_VISIBLES; i++) {
                texto.append("\n• ").append(avisos.get(i));
            }
            if (avisos.size() > AVISOS_VISIBLES) {
                texto.append("\n").append(pantalla.getString(R.string.sync_y_mas, avisos.size() - AVISOS_VISIBLES));
            }
        }
        new MaterialAlertDialogBuilder(pantalla)
                .setTitle(R.string.sync_titulo)
                .setMessage(texto.toString())
                .setPositiveButton(R.string.sync_entendido, null)
                .show();
    }

    // Los avisos mostrados ya no hace falta volver a mostrarlos. Los de mensaje se marcan al abrir la conversación.
    private static void marcarLeidos(AppCompatActivity pantalla, ArrayList<Integer> ids) {
        if (ids.isEmpty()) {
            return;
        }
        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("ids", new JSONArray(ids));
        } catch (JSONException e) {
            return;
        }
        ClienteApi.pedir(pantalla, "PUT", "api/avisos/leidos", cuerpo.toString(), new ClienteApi.Respuesta() {
            @Override
            public void alExito(String respuesta) {
                // nada que mostrar
            }

            @Override
            public void alError(int codigo, String mensaje) {
                // nada que mostrar
            }
        });
    }

    // La fecha lleva un "+" de la zona horaria, que en una dirección web debe escribirse %2B
    private static String codificar(String texto) {
        try {
            return URLEncoder.encode(texto, "UTF-8");
        } catch (UnsupportedEncodingException e) {
            return texto;
        }
    }
}
