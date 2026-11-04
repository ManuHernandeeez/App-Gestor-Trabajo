package com.utec.gestortrabajo;

import android.os.Bundle;
import android.view.View;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;

// Pantalla compartida: mensajes de un trabajo entre el cliente y el trabajador asignado.
// Se cargan al abrir y con el botón Actualizar; no hay sondeo en segundo plano.
// Recibe en el Intent los extras "solicitudId", "nombre" (de la otra parte), "titulo" y "estado".
public class ConversacionActivity extends AppCompatActivity {

    private int solicitudId;
    private TextView txtVacio;
    private ListView listaMensajes;
    private EditText edtMensaje;
    private final ArrayList<Mensaje> mensajes = new ArrayList<Mensaje>();
    private AdaptadorMensajes adaptador;
    private boolean enviando = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_conversacion);
        Ventana.preparar(this, findViewById(R.id.raiz));

        Bundle extras = getIntent().getExtras();
        solicitudId = extras.getInt("solicitudId");
        ((TextView) findViewById(R.id.txtNombre)).setText(extras.getString("nombre"));
        ((TextView) findViewById(R.id.txtTrabajo)).setText(extras.getString("titulo"));
        mostrarCampoDeEscritura(extras.getString("estado"));

        txtVacio = findViewById(R.id.txtVacio);
        edtMensaje = findViewById(R.id.edtMensaje);
        adaptador = new AdaptadorMensajes(this, mensajes);
        listaMensajes = findViewById(R.id.listaMensajes);
        listaMensajes.setAdapter(adaptador);
        cargar();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // Botón Volver
    public void volver(View vista) {
        finish();
    }

    // Botón Actualizar
    public void actualizar(View vista) {
        cargar();
    }

    // Botón Enviar
    public void enviar(View vista) {
        String texto = edtMensaje.getText().toString().trim();
        if (enviando || texto.isEmpty()) {
            return;
        }
        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("texto", texto);
        } catch (JSONException e) {
            return;
        }

        enviando = true;
        ClienteApi.pedir(this, "POST", "api/solicitudes/" + solicitudId + "/mensajes", cuerpo.toString(),
                new ClienteApi.Respuesta() {
                    @Override
                    public void alExito(String respuesta) {
                        enviando = false;
                        edtMensaje.setText("");
                        cargar();
                    }

                    @Override
                    public void alError(int codigo, String mensaje) {
                        enviando = false;
                    }
                });
    }

    // Solo se escribe mientras el trabajo está asignado, en proceso o finalizado
    private void mostrarCampoDeEscritura(String estado) {
        boolean abierta = estado.equals("asignada") || estado.equals("en_proceso") || estado.equals("finalizada");
        findViewById(R.id.vistaEscribir).setVisibility(abierta ? View.VISIBLE : View.GONE);
        findViewById(R.id.txtCerrada).setVisibility(abierta ? View.GONE : View.VISIBLE);
    }

    private void cargar() {
        ClienteApi.pedir(this, "GET", "api/solicitudes/" + solicitudId + "/mensajes", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                mostrar(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                txtVacio.setText(R.string.error_cargar);
                txtVacio.setVisibility(View.VISIBLE);
            }
        });
    }

    private void mostrar(String cuerpo) {
        try {
            JSONArray arreglo = new JSONArray(cuerpo);
            mensajes.clear();
            for (int i = 0; i < arreglo.length(); i++) {
                mensajes.add(new Mensaje(arreglo.getJSONObject(i)));
            }
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        adaptador.notifyDataSetChanged();
        txtVacio.setText(R.string.sin_mensajes);
        txtVacio.setVisibility(mensajes.isEmpty() ? View.VISIBLE : View.GONE);
        if (!mensajes.isEmpty()) {
            listaMensajes.setSelection(mensajes.size() - 1);
        }
        marcarAvisosLeidos();
    }

    // Los avisos de mensaje nuevo de este trabajo dejan de contar como sin leer
    private void marcarAvisosLeidos() {
        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("solicitudId", solicitudId);
        } catch (JSONException e) {
            return;
        }
        ClienteApi.pedir(this, "PUT", "api/avisos/leidos", cuerpo.toString(), new ClienteApi.Respuesta() {
            @Override
            public void alExito(String respuesta) {
                // nada que mostrar
            }

            @Override
            public void alError(int codigo, String mensaje) {
                // nada que mostrar: los avisos se marcarán la próxima vez
            }
        });
    }
}
