package com.utec.gestortrabajo;

import android.content.DialogInterface;
import android.os.Bundle;
import android.view.View;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import org.json.JSONArray;
import org.json.JSONException;

import java.util.ArrayList;

// Pantalla del cliente: propuestas de una de sus solicitudes, con Aceptar y Rechazar.
// Recibe en el Intent los extras "solicitudId", "titulo", "zona", "presupuesto" y "estado".
public class PropuestasActivity extends AppCompatActivity {

    private int solicitudId;
    private String estadoSolicitud;
    private TextView txtEstado;
    private TextView txtIndicacion;
    private TextView txtVacio;
    private final ArrayList<Propuesta> propuestas = new ArrayList<Propuesta>();
    private AdaptadorPropuestas adaptador;
    private boolean ocupado = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_propuestas);
        Ventana.preparar(this, findViewById(R.id.raiz));

        Bundle extras = getIntent().getExtras();
        solicitudId = extras.getInt("solicitudId");
        estadoSolicitud = extras.getString("estado");
        ((TextView) findViewById(R.id.txtTitulo)).setText(extras.getString("titulo"));
        ((TextView) findViewById(R.id.txtZona)).setText(extras.getString("zona"));
        ((TextView) findViewById(R.id.txtPresupuesto)).setText(
                getString(R.string.tu_presupuesto, Formato.dinero(extras.getDouble("presupuesto"))));

        txtEstado = findViewById(R.id.txtEstado);
        txtIndicacion = findViewById(R.id.txtIndicacion);
        txtVacio = findViewById(R.id.txtVacio);

        adaptador = new AdaptadorPropuestas(this, propuestas, new AdaptadorPropuestas.AlElegir() {
            @Override
            public void aceptar(Propuesta propuesta) {
                confirmarAceptar(propuesta);
            }

            @Override
            public void rechazar(Propuesta propuesta) {
                confirmarRechazar(propuesta);
            }
        });
        ListView listaPropuestas = findViewById(R.id.listaPropuestas);
        listaPropuestas.setAdapter(adaptador);

        mostrarEstado();
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

    // Solo se puede elegir mientras la solicitud esté publicada
    private void mostrarEstado() {
        EstadoSolicitud.pintar(txtEstado, estadoSolicitud);
        boolean publicada = estadoSolicitud.equals("publicada");
        adaptador.permitirElegir(publicada);
        if (publicada) {
            txtIndicacion.setText(R.string.indicacion_elegir);
        } else if (estadoSolicitud.equals("cancelada") || estadoSolicitud.equals("vencida")) {
            txtIndicacion.setText(R.string.solicitud_cerrada);
        } else {
            txtIndicacion.setText(R.string.indicacion_asignada);
        }
    }

    private void cargar() {
        txtVacio.setText(R.string.cargando);
        txtVacio.setVisibility(View.VISIBLE);
        ClienteApi.pedir(this, "GET", "api/solicitudes/" + solicitudId + "/propuestas", null, new ClienteApi.Respuesta() {
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
            propuestas.clear();
            for (int i = 0; i < arreglo.length(); i++) {
                propuestas.add(new Propuesta(arreglo.getJSONObject(i)));
            }
        } catch (JSONException e) {
            Toast.makeText(this, R.string.error_inesperado, Toast.LENGTH_LONG).show();
            return;
        }
        adaptador.notifyDataSetChanged();
        txtVacio.setText(R.string.vacio_propuestas);
        txtVacio.setVisibility(propuestas.isEmpty() ? View.VISIBLE : View.GONE);
    }

    private void confirmarAceptar(final Propuesta propuesta) {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.aceptar_titulo)
                .setMessage(getString(R.string.aceptar_mensaje, propuesta.trabajadorNombre, Formato.dinero(propuesta.precio)))
                .setPositiveButton(R.string.boton_aceptar, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogo, int boton) {
                        decidir(propuesta, "aceptar");
                    }
                })
                .setNegativeButton(R.string.cancelar, null)
                .show();
    }

    private void confirmarRechazar(final Propuesta propuesta) {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.rechazar_titulo)
                .setMessage(getString(R.string.rechazar_mensaje, propuesta.trabajadorNombre, Formato.dinero(propuesta.precio)))
                .setPositiveButton(R.string.boton_rechazar, new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialogo, int boton) {
                        decidir(propuesta, "rechazar");
                    }
                })
                .setNegativeButton(R.string.cancelar, null)
                .show();
    }

    // accion: "aceptar" o "rechazar". Después se recarga la lista, salga bien o no, porque pudo cambiar.
    private void decidir(Propuesta propuesta, final String accion) {
        if (ocupado) {
            return;
        }
        ocupado = true;
        ClienteApi.pedir(this, "POST", "api/propuestas/" + propuesta.id + "/" + accion, null, new ClienteApi.Respuesta() {
            @Override
            public void alExito(String cuerpo) {
                ocupado = false;
                if (accion.equals("aceptar")) {
                    Toast.makeText(PropuestasActivity.this, R.string.propuesta_aceptada_ok, Toast.LENGTH_LONG).show();
                    estadoSolicitud = "asignada";
                    mostrarEstado();
                } else {
                    Toast.makeText(PropuestasActivity.this, R.string.propuesta_rechazada_ok, Toast.LENGTH_SHORT).show();
                }
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
