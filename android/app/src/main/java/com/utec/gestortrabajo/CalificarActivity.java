package com.utec.gestortrabajo;

import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.RatingBar;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONException;
import org.json.JSONObject;

// Pantalla compartida: califica a la otra parte de un trabajo finalizado, de 1 a 5 estrellas y con comentario obligatorio.
// Recibe en el Intent los extras "solicitudId", "titulo" y "nombre" (de quien se califica).
public class CalificarActivity extends AppCompatActivity {

    private int solicitudId;
    private RatingBar vistaEstrellas;
    private EditText edtComentario;
    private Button btnEnviar;
    private boolean enviando = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_calificar);
        Ventana.preparar(this, findViewById(R.id.raiz));

        Bundle extras = getIntent().getExtras();
        solicitudId = extras.getInt("solicitudId");
        ((TextView) findViewById(R.id.txtCalificar)).setText(getString(R.string.calificar_a, extras.getString("nombre")));
        ((TextView) findViewById(R.id.txtTrabajo)).setText(extras.getString("titulo"));

        vistaEstrellas = findViewById(R.id.vistaEstrellas);
        edtComentario = findViewById(R.id.edtComentario);
        btnEnviar = findViewById(R.id.btnEnviar);

        // si ya eligió estrellas o escribió algo, Atrás pregunta antes de perderlo
        Atras.proteger(this, new Atras.Regla() {
            @Override
            public Atras.Pregunta preguntar() {
                if (!hayDatos()) {
                    return null;
                }
                return Atras.descartar(R.string.descartar_calificacion_titulo, R.string.descartar_calificacion_mensaje);
            }
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // Flecha de volver: hace lo mismo que el botón Atrás del teléfono, incluido el aviso
    public void volver(View vista) {
        getOnBackPressedDispatcher().onBackPressed();
    }

    private boolean hayDatos() {
        return vistaEstrellas.getRating() > 0 || !edtComentario.getText().toString().trim().isEmpty();
    }

    // Botón Enviar calificación
    public void enviar(View vista) {
        if (enviando) {
            return;
        }
        int estrellas = Math.round(vistaEstrellas.getRating());
        String comentario = edtComentario.getText().toString().trim();
        if (estrellas < 1) {
            Toast.makeText(this, R.string.falta_estrellas, Toast.LENGTH_SHORT).show();
            return;
        }
        if (comentario.isEmpty()) {
            Toast.makeText(this, R.string.falta_comentario, Toast.LENGTH_SHORT).show();
            return;
        }
        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("estrellas", estrellas);
            cuerpo.put("comentario", comentario);
        } catch (JSONException e) {
            return;
        }

        enviando = true;
        Ventana.ocupar(btnEnviar, R.string.enviando);
        ClienteApi.pedir(this, "POST", "api/solicitudes/" + solicitudId + "/calificaciones", cuerpo.toString(),
                new ClienteApi.Respuesta() {
                    @Override
                    public void alExito(String respuesta) {
                        Toast.makeText(CalificarActivity.this, R.string.calificacion_enviada, Toast.LENGTH_SHORT).show();
                        finish();
                    }

                    @Override
                    public void alError(int codigo, String mensaje) {
                        enviando = false;
                        Ventana.liberar(btnEnviar, R.string.boton_enviar_calificacion);
                    }
                });
    }
}
