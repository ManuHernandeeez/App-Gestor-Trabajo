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

// Pantalla del cliente: detalle de una de sus solicitudes, con acceso a las propuestas, al seguimiento y Cancelar.
// Recibe en el Intent el extra "solicitudId".
public class DetalleSolicitudActivity extends AppCompatActivity {

    private int solicitudId;
    private SolicitudDetalle detalle;
    private TextView txtCargando;
    private TextView txtTitulo;
    private TextView txtEstado;
    private TextView txtOficio;
    private TextView txtZona;
    private TextView txtTrabajador;
    private TextView txtPresupuesto;
    private TextView txtDescripcion;
    private View vistaDetalle;
    private Button btnPropuestas;
    private Button btnSeguimiento;
    private Button btnCancelar;
    private boolean ocupado = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_detalle_solicitud);
        Ventana.preparar(this, findViewById(R.id.raiz));

        txtCargando = findViewById(R.id.txtCargando);
        txtTitulo = findViewById(R.id.txtTitulo);
        txtEstado = findViewById(R.id.txtEstado);
        txtOficio = findViewById(R.id.txtOficio);
        txtZona = findViewById(R.id.txtZona);
        txtTrabajador = findViewById(R.id.txtTrabajador);
        txtPresupuesto = findViewById(R.id.txtPresupuesto);
        txtDescripcion = findViewById(R.id.txtDescripcion);
        vistaDetalle = findViewById(R.id.vistaDetalle);
        btnPropuestas = findViewById(R.id.btnPropuestas);
        btnSeguimiento = findViewById(R.id.btnSeguimiento);
        btnCancelar = findViewById(R.id.btnCancelar);

        Bundle extras = getIntent().getExtras();
        solicitudId = extras.getInt("solicitudId");
        cargar();
    }

    // Al volver de Propuestas o Seguimiento el estado pudo cambiar
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

    // Botón Ver propuestas
    public void verPropuestas(View vista) {
        Intent intent = new Intent(this, PropuestasActivity.class);
        intent.putExtra("solicitudId", solicitudId);
        intent.putExtra("titulo", detalle.titulo);
        intent.putExtra("zona", detalle.zona);
        intent.putExtra("presupuesto", detalle.presupuesto);
        intent.putExtra("estado", detalle.estado);
        startActivity(intent);
    }

    // Botón Ver seguimiento
    public void verSeguimiento(View vista) {
        Intent intent = new Intent(this, SeguimientoActivity.class);
        intent.putExtra("solicitudId", solicitudId);
        startActivity(intent);
    }

    // Botón Cancelar solicitud
    public void cancelarSolicitud(View vista) {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.cancelar_solicitud_titulo)
                .setMessage(R.string.cancelar_solicitud_mensaje)
                .setPositiveButton(R.string.boton_cancelar_solicitud, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogo, int boton) {
                        cancelar();
                    }
                })
                .setNegativeButton(R.string.boton_quedarme, null)
                .show();
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
        txtTitulo.setText(detalle.titulo);
        EstadoSolicitud.pintar(txtEstado, detalle.estado);
        txtOficio.setText(detalle.oficio);
        txtZona.setText(detalle.zona);
        txtPresupuesto.setText(getString(R.string.tu_presupuesto, Formato.dinero(detalle.presupuesto)));
        txtDescripcion.setText(detalle.descripcion);
        mostrarTrabajador();
        mostrarAcciones();

        txtCargando.setVisibility(View.GONE);
        vistaDetalle.setVisibility(View.VISIBLE);
    }

    private void mostrarTrabajador() {
        txtTrabajador.setVisibility(detalle.trabajadorNombre == null ? View.GONE : View.VISIBLE);
        if (detalle.trabajadorNombre != null) {
            txtTrabajador.setText(getString(R.string.trabajador_asignado, detalle.trabajadorNombre));
        }
    }

    // Propuestas mientras está publicada, seguimiento una vez asignada, y Cancelar mientras se pueda
    private void mostrarAcciones() {
        String estado = detalle.estado;
        boolean publicada = estado.equals("publicada");
        boolean conTrabajador = estado.equals("asignada") || estado.equals("en_proceso") || estado.equals("finalizada");

        btnPropuestas.setVisibility(publicada ? View.VISIBLE : View.GONE);
        btnPropuestas.setText(getString(R.string.boton_ver_propuestas, detalle.propuestas));
        btnSeguimiento.setVisibility(conTrabajador ? View.VISIBLE : View.GONE);
        btnCancelar.setVisibility(publicada || estado.equals("asignada") ? View.VISIBLE : View.GONE);
    }

    private void cancelar() {
        if (ocupado) {
            return;
        }
        ocupado = true;
        ClienteApi.pedir(this, "PUT", "api/solicitudes/" + solicitudId + "/cancelar", null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                ocupado = false;
                Toast.makeText(DetalleSolicitudActivity.this, R.string.solicitud_cancelada_ok, Toast.LENGTH_SHORT).show();
                finish();
            }

            @Override
            public void alError(int codigo, String mensaje) {
                ocupado = false;
                cargar();
            }
        });
    }
}
