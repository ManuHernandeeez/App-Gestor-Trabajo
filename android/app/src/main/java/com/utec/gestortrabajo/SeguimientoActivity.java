package com.utec.gestortrabajo;

import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import org.json.JSONException;
import org.json.JSONObject;

// Pantalla compartida: seguimiento de un trabajo asignado. Muestra el estado y el contacto de la otra parte.
// El trabajador marca en proceso, el cliente confirma que terminó y ambos pueden calificar al final.
// Recibe en el Intent el extra "solicitudId".
public class SeguimientoActivity extends AppCompatActivity {

    private int solicitudId;
    private boolean esCliente;
    private SolicitudDetalle detalle;
    private String nombreOtraParte;
    private TextView txtCargando;
    private TextView txtTitulo;
    private TextView txtEstado;
    private TextView txtZona;
    private TextView txtOtraParte;
    private TextView txtIndicacion;
    private TextView txtContactoTitulo;
    private TextView txtContactoNombre;
    private TextView txtContactoTelefono;
    private TextView txtContactoDireccion;
    private View vistaDetalle;
    private View vistaContacto;
    private Button btnMensajes;
    private Button btnEnProceso;
    private Button btnFinalizar;
    private Button btnCalificar;
    private boolean ocupado = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_seguimiento);
        Ventana.preparar(this, findViewById(R.id.raiz));

        txtCargando = findViewById(R.id.txtCargando);
        txtTitulo = findViewById(R.id.txtTitulo);
        txtEstado = findViewById(R.id.txtEstado);
        txtZona = findViewById(R.id.txtZona);
        txtOtraParte = findViewById(R.id.txtOtraParte);
        txtIndicacion = findViewById(R.id.txtIndicacion);
        txtContactoTitulo = findViewById(R.id.txtContactoTitulo);
        txtContactoNombre = findViewById(R.id.txtContactoNombre);
        txtContactoTelefono = findViewById(R.id.txtContactoTelefono);
        txtContactoDireccion = findViewById(R.id.txtContactoDireccion);
        vistaDetalle = findViewById(R.id.vistaDetalle);
        vistaContacto = findViewById(R.id.vistaContacto);
        btnMensajes = findViewById(R.id.btnMensajes);
        btnEnProceso = findViewById(R.id.btnEnProceso);
        btnFinalizar = findViewById(R.id.btnFinalizar);
        btnCalificar = findViewById(R.id.btnCalificar);

        esCliente = new Sesion(this).obtenerRol().equals("cliente");
        Bundle extras = getIntent().getExtras();
        solicitudId = extras.getInt("solicitudId");
        cargar();
    }

    // Al volver de Calificar se recarga, por si cambió algo
    @Override
    protected void onRestart() {
        super.onRestart();
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

    // Botón Mensajes
    public void abrirMensajes(View vista) {
        // el botón solo sale con el trabajo asignado, en proceso o finalizado: el chat admite mensajes
        Chat.abrir(this, solicitudId, 0, nombreOtraParte, detalle.titulo, true);
    }

    // Botón Marcar en proceso (trabajador)
    public void marcarEnProceso(View vista) {
        cambiarEstado("api/trabajos/" + solicitudId + "/en-proceso", R.string.en_proceso_ok);
    }

    // Botón Confirmar trabajo terminado (cliente)
    public void confirmarTerminado(View vista) {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.terminado_titulo)
                .setMessage(R.string.terminado_mensaje)
                .setPositiveButton(R.string.boton_confirmar, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogo, int boton) {
                        cambiarEstado("api/solicitudes/" + solicitudId + "/finalizar", R.string.terminado_ok);
                    }
                })
                .setNegativeButton(R.string.cancelar, null)
                .show();
    }

    // Botón Calificar
    public void calificar(View vista) {
        Intent intent = new Intent(this, CalificarActivity.class);
        intent.putExtra("solicitudId", solicitudId);
        intent.putExtra("titulo", detalle.titulo);
        intent.putExtra("nombre", nombreOtraParte);
        startActivity(intent);
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
        try {
            detalle = new SolicitudDetalle(new JSONObject(cuerpo));
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        nombreOtraParte = esCliente ? detalle.trabajadorNombre : detalle.clienteNombre;
        txtTitulo.setText(detalle.titulo);
        EstadoSolicitud.pintar(txtEstado, detalle.estado);
        txtZona.setText(detalle.zona);
        mostrarOtraParte();
        txtIndicacion.setText(indicacion());
        mostrarAcciones();

        txtCargando.setVisibility(View.GONE);
        vistaDetalle.setVisibility(View.VISIBLE);
        if (hayContacto()) {
            cargarContacto();
        } else {
            vistaContacto.setVisibility(View.GONE);
        }
    }

    private void mostrarOtraParte() {
        txtOtraParte.setVisibility(nombreOtraParte == null ? View.GONE : View.VISIBLE);
        if (nombreOtraParte != null) {
            int texto = esCliente ? R.string.trabajador_asignado : R.string.cliente_nombre;
            txtOtraParte.setText(getString(texto, nombreOtraParte));
        }
    }

    // El contacto se entrega solo con el trabajo asignado, en proceso o finalizado
    private boolean hayContacto() {
        String estado = detalle.estado;
        return estado.equals("asignada") || estado.equals("en_proceso") || estado.equals("finalizada");
    }

    // Qué sigue, según el estado y el rol
    private String indicacion() {
        switch (detalle.estado) {
            case "asignada":
                return getString(esCliente ? R.string.indicacion_asignada_cliente : R.string.indicacion_asignada_trabajador);
            case "en_proceso":
                return getString(esCliente ? R.string.indicacion_proceso_cliente : R.string.indicacion_proceso_trabajador);
            case "finalizada":
                return getString(detalle.yaCalifique ? R.string.indicacion_calificada : R.string.indicacion_finalizada,
                        nombreOtraParte);
            case "cancelada":
                return getString(R.string.indicacion_cancelada);
            case "vencida":
                return getString(R.string.indicacion_vencida);
            default:
                return getString(R.string.indicacion_publicada);
        }
    }

    private void mostrarAcciones() {
        String estado = detalle.estado;
        btnMensajes.setVisibility(hayContacto() ? View.VISIBLE : View.GONE);
        btnEnProceso.setVisibility(!esCliente && estado.equals("asignada") ? View.VISIBLE : View.GONE);
        btnFinalizar.setVisibility(esCliente && estado.equals("en_proceso") ? View.VISIBLE : View.GONE);
        btnCalificar.setVisibility(estado.equals("finalizada") && !detalle.yaCalifique ? View.VISIBLE : View.GONE);
        btnCalificar.setText(getString(R.string.boton_calificar, nombreOtraParte));
    }

    private void cargarContacto() {
        ClienteApi.pedir(this, "GET", "api/solicitudes/" + solicitudId + "/contacto", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                mostrarContacto(cuerpo);
            }

            @Override
            public void alError(int codigo, String mensaje) {
                vistaContacto.setVisibility(View.GONE);
            }
        });
    }

    private void mostrarContacto(String cuerpo) {
        try {
            JSONObject contacto = new JSONObject(cuerpo);
            int titulo = contacto.getString("rol").equals("cliente") ? R.string.contacto_cliente : R.string.contacto_trabajador;
            txtContactoTitulo.setText(titulo);
            txtContactoNombre.setText(contacto.getString("nombre"));
            txtContactoTelefono.setText(getString(R.string.contacto_telefono,
                    contacto.isNull("telefono") ? getString(R.string.sin_dato) : contacto.getString("telefono")));
            txtContactoDireccion.setText(getString(R.string.contacto_direccion,
                    contacto.isNull("direccionExacta") ? getString(R.string.sin_dato) : contacto.getString("direccionExacta")));
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        vistaContacto.setVisibility(View.VISIBLE);
    }

    // Después se recarga, salga bien o no, porque el estado pudo cambiar
    private void cambiarEstado(String ruta, final int mensajeListo) {
        if (ocupado) {
            return;
        }
        ocupado = true;
        ClienteApi.pedir(this, "PUT", ruta, null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                ocupado = false;
                Toast.makeText(SeguimientoActivity.this, mensajeListo, Toast.LENGTH_SHORT).show();
                cargar();
            }

            @Override
            public void alError(int codigo, String mensaje) {
                ocupado = false;
                cargar();
            }
        });
    }
}
