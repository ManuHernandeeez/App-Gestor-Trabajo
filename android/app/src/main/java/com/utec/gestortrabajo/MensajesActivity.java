package com.utec.gestortrabajo;

import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONException;

import java.util.ArrayList;

// Pantalla compartida: los chats del usuario, uno por cada persona y trabajo, con su último mensaje.
// Tocar uno abre la conversación.
public class MensajesActivity extends AppCompatActivity {

    private TextView txtVacio;
    private final ArrayList<Conversacion> conversaciones = new ArrayList<Conversacion>();
    private AdaptadorConversaciones adaptador;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_mensajes);
        Ventana.preparar(this, findViewById(R.id.raiz));
        Barra.preparar(this, R.id.btnBarraMensajes);
        Atras.protegerSiempre(this, Atras.salirDeLaApp());

        TextView txtNombre = findViewById(R.id.txtNombre);
        txtNombre.setText(getString(R.string.hola_nombre, new Sesion(this).obtenerNombre()));

        txtVacio = findViewById(R.id.txtVacio);
        adaptador = new AdaptadorConversaciones(this, conversaciones);
        ListView listaConversaciones = findViewById(R.id.listaConversaciones);
        listaConversaciones.setAdapter(adaptador);
        listaConversaciones.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> padre, View vista, int posicion, long id) {
                abrirConversacion(conversaciones.get(posicion));
            }
        });
        cargar();
    }

    // Al volver de una conversación se recarga: cambian el último mensaje y los que estaban sin leer
    @Override
    protected void onRestart() {
        super.onRestart();
        cargar();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // Botón Actualizar
    public void actualizar(View vista) {
        cargar();
    }

    private void abrirConversacion(Conversacion conversacion) {
        Chat.abrir(this, conversacion.solicitudId, conversacion.otraParteId, conversacion.otraParteNombre,
                conversacion.titulo, conversacion.puedeEscribir);
    }

    private void cargar() {
        txtVacio.setText(R.string.cargando);
        txtVacio.setVisibility(View.VISIBLE);
        ClienteApi.pedir(this, "GET", "api/conversaciones", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                mostrar(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                txtVacio.setText(R.string.error_cargar);
            }
        });
    }

    private void mostrar(String cuerpo) {
        try {
            JSONArray arreglo = new JSONArray(cuerpo);
            conversaciones.clear();
            for (int i = 0; i < arreglo.length(); i++) {
                conversaciones.add(new Conversacion(arreglo.getJSONObject(i)));
            }
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        adaptador.notifyDataSetChanged();
        txtVacio.setText(R.string.vacio_conversaciones);
        txtVacio.setVisibility(conversaciones.isEmpty() ? View.VISIBLE : View.GONE);
    }
}
