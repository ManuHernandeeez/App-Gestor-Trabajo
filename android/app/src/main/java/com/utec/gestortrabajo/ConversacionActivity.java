package com.utec.gestortrabajo;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
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

// Pantalla compartida: chat entre el cliente y un trabajador que envió propuesta a su solicitud.
// Los mensajes viven en la base de datos: se piden al abrir, cada pocos segundos mientras la pantalla
// está a la vista y con el botón Actualizar. En segundo plano no se pide nada.
// Recibe en el Intent los extras "solicitudId", "otraParteId" (el trabajador, si habla el cliente; 0 si no se
// sabe), "nombre" (de la otra parte), "titulo" y "puedeEscribir". Se abre con Chat.abrir.
public class ConversacionActivity extends AppCompatActivity {

    // Cada cuántos milisegundos se piden los mensajes nuevos con la pantalla a la vista
    private static final int ESPERA_MS = 4000;

    private int solicitudId;
    private int otraParteId;
    private TextView txtVacio;
    private ListView listaMensajes;
    private EditText edtMensaje;
    private final ArrayList<Mensaje> mensajes = new ArrayList<Mensaje>();
    private AdaptadorMensajes adaptador;
    private boolean enviando = false;
    private boolean visible = false;
    private boolean primeraCarga = true;
    private boolean irAlFinal = false;
    private final Handler reloj = new Handler(Looper.getMainLooper());
    private final Runnable pedirOtraVez = new Runnable() {
        @Override
        public void run() {
            cargar();
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_conversacion);
        Ventana.preparar(this, findViewById(R.id.raiz));

        Bundle extras = getIntent().getExtras();
        solicitudId = extras.getInt("solicitudId");
        otraParteId = extras.getInt("otraParteId");
        ((TextView) findViewById(R.id.txtNombre)).setText(extras.getString("nombre"));
        ((TextView) findViewById(R.id.txtTrabajo)).setText(extras.getString("titulo"));
        mostrarCampoDeEscritura(extras.getBoolean("puedeEscribir"));

        txtVacio = findViewById(R.id.txtVacio);
        edtMensaje = findViewById(R.id.edtMensaje);
        adaptador = new AdaptadorMensajes(this, mensajes);
        listaMensajes = findViewById(R.id.listaMensajes);
        listaMensajes.setAdapter(adaptador);
        cargar();
    }

    // Al volver de otra app o de la pantalla apagada se piden los mensajes de una vez
    @Override
    protected void onRestart() {
        super.onRestart();
        cargar();
    }

    @Override
    protected void onResume() {
        super.onResume();
        visible = true;
        programar();
    }

    @Override
    protected void onPause() {
        super.onPause();
        visible = false;
        reloj.removeCallbacks(pedirOtraVez);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        reloj.removeCallbacks(pedirOtraVez);
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
            if (otraParteId > 0) {
                cuerpo.put("otraParteId", otraParteId);
            }
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
                        irAlFinal = true;
                        cargar();
                    }

                    @Override
                    public void alError(int codigo, String mensaje) {
                        enviando = false;
                        // 409: el chat se cerró mientras estaba abierto (el cliente eligió a otro trabajador,
                        // retiraron la propuesta o cancelaron la solicitud)
                        if (codigo == 409) {
                            mostrarCampoDeEscritura(false);
                        }
                    }
                });
    }

    // El campo para escribir solo sale mientras el chat admite mensajes nuevos; si no, solo se lee
    private void mostrarCampoDeEscritura(boolean puedeEscribir) {
        findViewById(R.id.vistaEscribir).setVisibility(puedeEscribir ? View.VISIBLE : View.GONE);
        findViewById(R.id.txtCerrada).setVisibility(puedeEscribir ? View.GONE : View.VISIBLE);
    }

    // La siguiente petición se programa cuando llega la respuesta de la anterior, así nunca se amontonan.
    // Si una petición falla se deja de repetir (el Toast ya avisó) hasta que el usuario actualice o escriba.
    private void programar() {
        reloj.removeCallbacks(pedirOtraVez);
        if (visible && !isFinishing()) {
            reloj.postDelayed(pedirOtraVez, ESPERA_MS);
        }
    }

    private void cargar() {
        String ruta = "api/solicitudes/" + solicitudId + "/mensajes";
        if (otraParteId > 0) {
            ruta = ruta + "?otraParteId=" + otraParteId;
        }
        ClienteApi.pedir(this, "GET", ruta, null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                mostrar(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                if (mensajes.isEmpty()) {
                    txtVacio.setText(R.string.error_cargar);
                    txtVacio.setVisibility(View.VISIBLE);
                }
            }
        });
    }

    private void mostrar(String cuerpo) {
        ArrayList<Mensaje> nuevos = new ArrayList<Mensaje>();
        try {
            JSONArray arreglo = new JSONArray(cuerpo);
            for (int i = 0; i < arreglo.length(); i++) {
                nuevos.add(new Mensaje(arreglo.getJSONObject(i)));
            }
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }

        if (primeraCarga || hayMensajesNuevos(nuevos)) {
            primeraCarga = false;
            pintar(nuevos);
        }
        programar();
    }

    // Los mensajes no se editan ni se borran: basta comparar cuántos hay y cuál es el último
    private boolean hayMensajesNuevos(ArrayList<Mensaje> nuevos) {
        if (nuevos.size() != mensajes.size()) {
            return true;
        }
        return !nuevos.isEmpty() && nuevos.get(nuevos.size() - 1).id != mensajes.get(mensajes.size() - 1).id;
    }

    // Baja al último mensaje al abrir, al enviar y cuando el usuario ya estaba abajo; si estaba leyendo más arriba, lo deja ahí
    private void pintar(ArrayList<Mensaje> nuevos) {
        boolean estabaAbajo = listaMensajes.getLastVisiblePosition() >= mensajes.size() - 1;
        mensajes.clear();
        mensajes.addAll(nuevos);
        adaptador.notifyDataSetChanged();
        txtVacio.setText(R.string.sin_mensajes);
        txtVacio.setVisibility(mensajes.isEmpty() ? View.VISIBLE : View.GONE);
        if ((irAlFinal || estabaAbajo) && !mensajes.isEmpty()) {
            listaMensajes.setSelection(mensajes.size() - 1);
        }
        irAlFinal = false;
        marcarAvisosLeidos();
    }

    // Los avisos de mensaje nuevo de este chat dejan de contar como sin leer (solo los de este hilo si se sabe cuál es)
    private void marcarAvisosLeidos() {
        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("solicitudId", solicitudId);
            if (otraParteId > 0) {
                cuerpo.put("otraParteId", otraParteId);
            }
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
