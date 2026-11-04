package com.utec.gestortrabajo;

import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import org.json.JSONException;
import org.json.JSONObject;

// Pantalla del trabajador: detalle de un trabajo de su zona y envío de propuesta.
// Recibe en el Intent el extra "solicitudId".
public class DetalleTrabajoActivity extends AppCompatActivity {

    private int solicitudId;
    private TextView txtCargando;
    private TextView txtTitulo;
    private TextView txtOficio;
    private TextView txtZona;
    private TextView txtCliente;
    private TextView txtPresupuesto;
    private TextView txtDescripcion;
    private TextView txtMiPropuesta;
    private TextView txtAviso;
    private View vistaDetalle;
    private View vistaFormulario;
    private EditText edtPrecio;
    private EditText edtMensaje;
    private Button btnEnviar;
    private boolean enviando = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_detalle_trabajo);
        Ventana.preparar(this, findViewById(R.id.raiz));

        txtCargando = findViewById(R.id.txtCargando);
        txtTitulo = findViewById(R.id.txtTitulo);
        txtOficio = findViewById(R.id.txtOficio);
        txtZona = findViewById(R.id.txtZona);
        txtCliente = findViewById(R.id.txtCliente);
        txtPresupuesto = findViewById(R.id.txtPresupuesto);
        txtDescripcion = findViewById(R.id.txtDescripcion);
        txtMiPropuesta = findViewById(R.id.txtMiPropuesta);
        txtAviso = findViewById(R.id.txtAviso);
        vistaDetalle = findViewById(R.id.vistaDetalle);
        vistaFormulario = findViewById(R.id.vistaFormulario);
        edtPrecio = findViewById(R.id.edtPrecio);
        edtMensaje = findViewById(R.id.edtMensaje);
        btnEnviar = findViewById(R.id.btnEnviar);
        Mascara.dinero(edtPrecio);

        // si ya escribió precio o mensaje, Atrás pregunta antes de perderlos
        Atras.proteger(this, new Atras.Regla() {
            @Override
            public Atras.Pregunta preguntar() {
                if (!hayDatos()) {
                    return null;
                }
                return Atras.descartar(R.string.descartar_propuesta_titulo, R.string.descartar_propuesta_mensaje);
            }
        });

        Bundle extras = getIntent().getExtras();
        solicitudId = extras.getInt("solicitudId");
        cargar();
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
        return !edtPrecio.getText().toString().trim().isEmpty() || !edtMensaje.getText().toString().trim().isEmpty();
    }

    private void cargar() {
        ClienteApi.pedir(this, "GET", "api/solicitudes/" + solicitudId, null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                mostrar(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                txtCargando.setText(R.string.error_cargar);
            }
        });
    }

    private void mostrar(String cuerpo) {
        SolicitudDetalle detalle;
        try {
            detalle = new SolicitudDetalle(new JSONObject(cuerpo));
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        txtTitulo.setText(detalle.titulo);
        txtOficio.setText(detalle.oficio);
        txtZona.setText(detalle.zona);
        txtCliente.setText(getString(R.string.cliente_y_tiempo,
                detalle.clienteNombre, Formato.hace(this, detalle.horasPublicada())));
        txtPresupuesto.setText(getString(R.string.presupuesto_cliente, Formato.dinero(detalle.presupuesto)));
        txtDescripcion.setText(detalle.descripcion);
        mostrarPropuesta(detalle);

        txtCargando.setVisibility(View.GONE);
        vistaDetalle.setVisibility(View.VISIBLE);
    }

    // Según su propuesta y el estado de la solicitud, el trabajador ve un mensaje, el formulario o ambos
    private void mostrarPropuesta(SolicitudDetalle detalle) {
        String estadoPropuesta = detalle.miPropuestaEstado == null ? "" : detalle.miPropuestaEstado;
        boolean puedeProponer = detalle.estado.equals("publicada");
        String mensaje = null;

        if (estadoPropuesta.equals("pendiente")) {
            mensaje = getString(R.string.mi_propuesta_pendiente, Formato.dinero(detalle.miPropuestaPrecio));
            puedeProponer = false;
        } else if (estadoPropuesta.equals("aceptada")) {
            mensaje = getString(R.string.mi_propuesta_aceptada, Formato.dinero(detalle.miPropuestaPrecio));
            puedeProponer = false;
        } else if (estadoPropuesta.equals("rechazada")) {
            mensaje = getString(R.string.mi_propuesta_rechazada);
            puedeProponer = false;
        } else if (!puedeProponer) {
            mensaje = getString(R.string.solicitud_cerrada);
        } else if (estadoPropuesta.equals("retirada")) {
            mensaje = getString(R.string.mi_propuesta_retirada);
        }

        txtMiPropuesta.setVisibility(mensaje == null ? View.GONE : View.VISIBLE);
        if (mensaje != null) {
            txtMiPropuesta.setText(mensaje);
        }
        vistaFormulario.setVisibility(puedeProponer ? View.VISIBLE : View.GONE);
        // el aviso de que el contacto se libera al aceptar ya no aplica si la aceptaron
        txtAviso.setVisibility(estadoPropuesta.equals("aceptada") ? View.GONE : View.VISIBLE);
    }

    // Botón Enviar propuesta
    public void enviar(View vista) {
        if (enviando) {
            return;
        }
        double precio = Formato.numero(edtPrecio.getText().toString());
        if (precio <= 0) {
            Toast.makeText(this, R.string.precio_invalido, Toast.LENGTH_SHORT).show();
            return;
        }
        JSONObject cuerpo = new JSONObject();
        try {
            cuerpo.put("precio", precio);
            String mensaje = edtMensaje.getText().toString().trim();
            if (!mensaje.isEmpty()) {
                cuerpo.put("mensaje", mensaje);
            }
        } catch (JSONException e) {
            return;
        }

        enviando = true;
        Ventana.ocupar(btnEnviar, R.string.enviando);
        ClienteApi.pedir(this, "POST", "api/trabajos/" + solicitudId + "/propuestas", cuerpo.toString(),
                new ClienteApi.Respuesta() {
                    @Override
                    public void alExito(String respuesta) {
                        Toast.makeText(DetalleTrabajoActivity.this, R.string.propuesta_enviada, Toast.LENGTH_SHORT).show();
                        finish();
                    }

                    @Override
                    public void alError(int codigo, String mensaje) {
                        enviando = false;
                        Ventana.liberar(btnEnviar, R.string.boton_enviar_propuesta);
                    }
                });
    }
}
